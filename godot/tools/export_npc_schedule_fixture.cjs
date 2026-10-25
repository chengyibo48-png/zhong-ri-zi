const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,V=ZRZVillage,N=ZRZNpc,D=ZRZData,M=ZRZMuseum;
const homes=Object.fromEntries(D.npcs.map(n=>[n.id,V.homeOf(n.id)]));
const school=V.houses.find(h=>h.name==='禾溪小学'),market=V.houses.find(h=>h.name==='许婶杂货');
const workState=C.initial();workState.day=1;workState.minutes=600;
const work=Object.fromEntries(D.npcs.map(n=>{
 let plan=N.activity(workState,n.id);
 if(plan.key!=='work'){workState.minutes=930;plan=N.activity(workState,n.id);workState.minutes=600;}
 if(plan.key!=='work')throw Error('Unable to extract original work plan for '+n.id);
 return [n.id,plan.target];
}));
const visitorsOnly=process.argv.includes('--visitors');
// Actor updates mutate only NPC/runtime fields; reset those for every row and reuse unchanged geometry.
const visitorState=visitorsOnly?C.initial():null;
const fd=fs.openSync(process.argv[2],'w'),counts={},scenarios={};let count=0;
function exact(row){
 const metadata=[];
 function visit(value,path=[]){
  if(typeof value==='number'&&Number.isFinite(value)&&!Number.isInteger(value)){
   const b=Buffer.alloc(8);b.writeDoubleLE(value);metadata.push({path,bytes:b.toString("base64")});
  }else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));
  else if(value&&typeof value==='object')for(const [k,v] of Object.entries(value))visit(v,[...path,k]);
 }
 visit(row);if(metadata.length)row._float64_roundtrip={version:1,entries:metadata};return JSON.stringify(row);
}
for(let day=0;day<112;day++)for(let index=0;index<D.npcs.length;index++){
 if(visitorsOnly&&D.npcs[index].id!==['he','yan','yu','granny'][day%4])continue;
 const n=D.npcs[index],late=n.id==='mei'?390:420+index%4*12,night=1140+index%4*12,morning=510+index%3*20,lunch=720+index%3*20;
 const times=new Set([0,390,450,570,600,660,700,900,930,959.75,960,1000,1079.75,1080,1080.25,1200]);
 for(const t of [late,night,morning,lunch,lunch+65])for(const offset of [-.25,0,.25])times.add(t+offset);
 if(visitorsOnly){times.clear();for(const t of [929.75,930,959.75,960,1000,1079.75,1080,1080.25])times.add(t);}
 for(const scenario of ['ordinary','active-collection','completed-housework'])for(const minute of times){
  const s=visitorState||C.initial();s.day=day;s.minutes=minute;N.ensure(s);
  for(const resident of Object.values(s.neighbors.people))resident.event=null;
  if(scenario!=='ordinary')s.neighbors.people[n.id].event={day,status:scenario==='completed-housework'?'done':'accepted',completed:scenario==='completed-housework'?day:null,method:null};
  s.projects.bridge=scenario!=='ordinary';
  M.ensure(s).level=scenario==='ordinary'?0:2;
  const link=D.links.find(([from])=>from===n.id),friend=link&&homes[link[1]];
  const input={person:n,index,day,minutes:minute,shelter:ZRZEnvironment.profile(day).shelter,home:homes[n.id].door,work:work[n.id],school:school.door,market:market.door,friend_home:friend?.door||homes[n.id].door,friend_name:friend?D.npcs.find(n=>n.id===link[1]).name:'',bridge:s.projects.bridge,festival:D.festivals[C.calendar(s).season],housework:scenario!=='ordinary'&&scenario!=='completed-housework',museum_level:M.ensure(s).level,museum_door:M.house.door};
  const expected=N.activity(s,n.id);
  let actualPosition=null,startingPosition=null,actor=null;
  if(visitorsOnly){
   const p=s.village.npc[n.id],indoors=!!expected.room;
   Object.assign(p,homes[n.id].door,{room:indoors?homes[n.id].id:null,direction:'down'});
   if(expected.key==='museum')Object.assign(p,{x:M.house.door.x,y:M.house.door.y+10,room:null,direction:'up'});
   startingPosition=structuredClone(p);
   s.player={x:24,y:38,direction:'down'};s.village.interior=null;
   V.resetRuntime(s);const rt=V.stateRuntime(s);rt.clock=.25;
   actor=rt.actors[n.id]={wait:2+index*.31,path:[],phase:'',walking:false};
   N.updateNPC(s,n,index,actor,.25);actualPosition=structuredClone(p);actor=structuredClone(actor);
  }
  fs.writeSync(fd,exact({scenario,input,expected,startingPosition,actualPosition,actor})+'\n');count++;
  counts[expected.key]=(counts[expected.key]||0)+1;scenarios[scenario]=(scenarios[scenario]||0)+1;
 }
}
fs.closeSync(fd);
fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({rows:count,keys:counts,scenarios}));
console.log(JSON.stringify({rows:count,keys:counts,scenarios}));
