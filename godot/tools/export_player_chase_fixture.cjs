const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
require('./source_navigation_runtime.cjs');
const exact=require('./export_world_precision.cjs'),C=ZRZCore,V=ZRZVillage;
const text=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8'),move=text.slice(text.indexOf('  function move(dt)'),text.indexOf('  function frame(now)'));
const clause=move.slice(move.indexOf("if(['npc','animal'].includes(pending?.kind)"),move.indexOf('const bindings=s.settings.bindings'));
const fd=fs.openSync(process.argv[2],'w');let cases=0,frames=0;
for(const kind of ['npc','animal'])for(const scenario of ['moving','threshold','enter-room']){
 const s=C.initial();s.minutes=600;s.village.interior=null;
 const id=kind==='npc'?ZRZData.npcs[0].id:s.animals[0].id;
 const actor=kind==='npc'?s.village.npc[id]:s.animals[0].position;
 Object.assign(actor,{x:2831,y:1900,room:null,direction:'down'});
 s.player={x:2831.123456789,y:1652.987654321,direction:'left'};
 const initial=V.destination(s,kind,id),initialPath=V.route(s,initial.x,initial.y+5);
 const context={s,V,W:ZRZWorld,pending:structuredClone(initial),path:structuredClone(initialPath),frameTime:0,chaseAt:0};
 vm.createContext(context);vm.runInContext('function chase(){'+clause+'}',context);
 const before=structuredClone(s),samples=[];
 const times=[0,.01,.7,.71,.7100000001,1.4,1.4100000001,1.4100000002,2.2,2.9,3.61,4.32];
 for(const[index,now]of times.entries()){
  if(scenario==='moving')actor.x=2831+index*25.25;
  if(scenario==='threshold')actor.x=2831+[0,30,30,30,30.0000000001,60,60.0000000002,60.0000000002,90,90.0000000003,120,120.0000000004][index];
  if(scenario==='enter-room'&&index>=4)actor.room=kind==='npc'?V.homeOf(id).id:ZRZRanch.houseOf(s.animals[0]).id;
  context.frameTime=now;context.chase();
  samples.push({now,actor:structuredClone(actor),pending:structuredClone(context.pending),path:structuredClone(context.path),chaseAt:context.chaseAt});frames++;
 }
 fs.writeSync(fd,JSON.stringify(exact({kind,scenario,id,before,initial,initialPath,samples}))+'\n');cases++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases,frames}));console.log(JSON.stringify({cases,frames}));
