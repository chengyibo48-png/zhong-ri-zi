const fs=require('node:fs');global.window=globalThis;
require('./source_navigation_runtime.cjs');
const C=ZRZCore,V=ZRZVillage,copy=x=>structuredClone(x),fd=fs.openSync(process.argv[2],'w');let cases=0,frames=0;
function emit(row){const entries=[];function visit(v,path=[]){if(typeof v==='number'&&Number.isFinite(v)&&!Number.isInteger(v)){const b=Buffer.alloc(8);b.writeDoubleLE(v);entries.push({path,bytes:b.toString('base64')});}else if(Array.isArray(v))v.forEach((q,i)=>visit(q,[...path,i]));else if(v&&typeof v==='object')for(const[k,q]of Object.entries(v))visit(q,[...path,k]);}visit(row);if(entries.length)row._float64_roundtrip={version:1,entries};fs.writeSync(fd,JSON.stringify(row)+'\n');}
for(const scenario of ['ordinary','housework','festival','museum','return-home']){
 const s=C.initial();s.day={ordinary:1,housework:2,festival:13,museum:0,'return-home':1}[scenario];s.minutes=scenario==='festival'?700:scenario==='museum'?930:scenario==='return-home'?1200:600;
 s.player={x:24,y:38,direction:'down'};ZRZMuseum.ensure(s).level=scenario==='museum'?2:0;
 if(scenario==='return-home')for(const n of ZRZData.npcs){const p=s.village.npc[n.id],h=V.homeOf(n.id);Object.assign(p,V.safePosition({...s,village:{interior:null}},{x:h.door.x+45,y:h.door.y+55}),{room:null,direction:'down'});}
 const before=copy(s),samples=[];
 for(let i=0;i<80;i++){const dt=i%9===0?.125:.5;V.update(s,dt);const rt=V.stateRuntime(s);samples.push({dt,npc:copy(s.village.npc),actors:copy(rt.actors),clock:rt.clock});frames++;}
 emit({scenario,before,samples});cases++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases,frames}));console.log(JSON.stringify({cases,frames}));
