const fs=require('node:fs'),vm=require('node:vm');
require('./source_navigation_runtime.cjs');
const exact=require('./export_world_precision.cjs'),C=ZRZCore,V=ZRZVillage,K=ZRZKitchen,E=ZRZEnvironment;
const text=fs.readFileSync(require('node:path').join(__dirname,'../../src/app.js'),'utf8');
const source=text.slice(text.indexOf('  function move(dt)'),text.indexOf('  function frame(now)'));
const days=Object.fromEntries(['dry','wet','snow'].map(kind=>[kind,Array.from({length:448},(_,i)=>i).find(d=>kind==='snow'?E.ground(d).snow:kind==='wet'?E.ground(d).wet&&!E.ground(d).snow:!E.ground(d).wet&&!E.ground(d).snow)]));
const rooms=[null,...Object.keys(ZRZInteriors.layouts).slice(0,3)];
const fd=fs.openSync(process.argv[2],'w');let cases=0,frames=0;
for(const room of rooms)for(const weather of ['dry','wet','snow'])for(const speed of ['walk','shift','riding','buff','buff-riding'])for(const mode of ['manual','path','frame']){
 const s=C.initial();s.day=days[weather];s.minutes=600;s.village.interior=room;s.village.riding=speed.includes('riding')&&!room;
 s.player=V.safePosition(s,room?{x:480.123456789,y:550.987654321,direction:'left'}:{x:2831.123456789,y:1652.987654321,direction:'left'});
 if(speed.includes('buff'))s.kitchen.buff={kind:'轻快',until:K.now(s)+180};
 const path=mode!=='manual'?V.route(s,room?760:3070,room?540:2730):[];
 const context={s,path,pending:null,buildTask:null,kitchenTask:null,ranchQueue:[],farmQueue:[],queuedDestination:null,frameTime:0,chaseAt:0,keys:new Set(),padX:0,padY:0,K,V,W:ZRZWorld,window:globalThis};
 vm.createContext(context);vm.runInContext(source,context);
 if(mode==='frame'&&speed.includes('buff'))s.kitchen.buff.until=K.now(s)+.02;
 const before=structuredClone(s),initialPath=structuredClone(path),samples=[];
 for(let frame=0;frame<80;frame++){
  const input=mode==='manual'?[[1,0],[0,1],[-1,-1],[1,-1],[.31,-.72],[0,0],[1,1],[-1,0]][Math.floor(frame/10)]:[0,0];
  context.keys=new Set(speed==='shift'?['shift']:[]);context.padX=input[0];context.padY=input[1];
  const rawDt=[.016,.05,.033,0,.125][frame%5],dt=mode==='frame'?Math.min(.05,rawDt):rawDt,rate=(s.village.riding?355:context.keys.has('shift')?265:195)*(K.activeBuff(s)?.kind==='轻快'?1.12:1)*E.speed(s);
  const walking=context.move(dt);
  if(mode==='frame')s.minutes=Math.min(1320,s.minutes+dt*(s.settings.speed==='normal'?1.55:1.04));
  samples.push({dt,input,fast:speed==='shift',rate,walking,minutes:s.minutes,p:structuredClone(s.player),path:structuredClone(context.path)});frames++;
 }
 fs.writeSync(fd,JSON.stringify(exact({room,weather,speed,mode,before,initialPath,samples}))+'\n');cases++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases,frames}));console.log(JSON.stringify({cases,frames}));
