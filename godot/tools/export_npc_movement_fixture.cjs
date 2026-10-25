const fs=require('node:fs');global.window=globalThis;
require('./source_navigation_runtime.cjs');
const C=ZRZCore,V=ZRZVillage,N=ZRZNpc,D=ZRZData;
const fd=fs.openSync(process.argv[2],'w'),copy=x=>structuredClone(x);let cases=0,frames=0;
function exact(row){
 const entries=[];
 function visit(v,path=[]){
  if(typeof v==='number'&&Number.isFinite(v)&&!Number.isInteger(v)){const b=Buffer.alloc(8);b.writeDoubleLE(v);entries.push({path,bytes:b.toString('base64')});}
  else if(Array.isArray(v))v.forEach((q,i)=>visit(q,[...path,i]));
  else if(v&&typeof v==='object')for(const[k,q]of Object.entries(v))visit(q,[...path,k]);
 }
 visit(row);if(entries.length)row._float64_roundtrip={version:1,entries};return JSON.stringify(row);
}
for(const[index,n]of D.npcs.entries())for(const scenario of ['depart','enter','wander','near-inside','near-outside','focused','weather']){
 const s=C.initial(),home=V.homeOf(n.id);s.day=scenario==='weather'?Array.from({length:112},(_,d)=>d).find(d=>ZRZEnvironment.profile(d).shelter):1;s.minutes=scenario==='enter'?1200:scenario==='near-inside'?450:600;N.ensure(s);
 for(const p of Object.values(s.neighbors.people))p.event=null;
 s.player={x:24,y:38,direction:'down'};
 const p=s.village.npc[n.id];Object.assign(p,home.door,{room:['enter','wander','near-outside'].includes(scenario)?null:home.id,direction:'down'});
 if(scenario==='enter')Object.assign(p,V.safePosition({...s,village:{interior:null}},{x:home.door.x+45,y:home.door.y+55}),{room:null});
 if(scenario==='near-inside'){s.village.interior=home.id;s.player={x:500,y:560,direction:'left'};}
 if(scenario==='near-outside')s.player={x:p.x+20,y:p.y+12,direction:'left'};
 const rt=V.stateRuntime(s),a=rt.actors[n.id]={wait:2+index*.31,path:[],phase:'',walking:false};
 if(scenario==='focused'){a.inside={x:480,y:560,direction:'up'};rt.sequence={npcId:n.id};}
 const before=copy(s),samples=[];
 for(let frame=0;frame<40;frame++){
  const dt=frame%7===0?.125:.5;rt.clock+=dt;N.updateNPC(s,n,index,a,dt);
  samples.push({dt,p:copy(p),a:copy(a),clock:rt.clock,point:copy(V.npcPoint(s,n))});frames++;
 }
 fs.writeSync(fd,exact({id:n.id,index,scenario,before,samples})+'\n');cases++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases,frames}));console.log(JSON.stringify({cases,frames}));
