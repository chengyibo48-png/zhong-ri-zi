const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,V=ZRZVillage,N=ZRZNpc,D=ZRZData,S=ZRZScenes,M=ZRZMuseum,copy=x=>structuredClone(x);
const fd=fs.openSync(process.argv[2],'w');let queries=0,regions=0;
function emit(row){const entries=[];function visit(v,path=[]){if(typeof v==='number'&&Number.isFinite(v)&&!Number.isInteger(v)){const b=Buffer.alloc(8);b.writeDoubleLE(v);entries.push({path,bytes:b.toString('base64')});}else if(Array.isArray(v))v.forEach((q,i)=>visit(q,[...path,i]));else if(v&&typeof v==='object')for(const[k,q]of Object.entries(v))visit(q,[...path,k]);}visit(row);if(entries.length)row._float64_roundtrip={version:1,entries};fs.writeSync(fd,JSON.stringify(row)+'\n');}
const s=C.initial();emit({kind:'seed',before:copy(s)});
const coordinates=[['mountain',500,600],['town',2800,600],['bamboo',500,1800],['farm',2831.25,1652.5],['river',500,2800],['pasture',2800,2800],['south-river',500,3700.125],['south-pasture',2800,3700.125],['edge',1920,3456],['fallback',4000,4000]];
for(const [index,n]of D.npcs.entries()){
 const home=V.homeOf(n.id),foreign=V.homeOf(D.npcs[(index+1)%D.npcs.length].id);
 const placements=[['home',home.door.x,home.door.y,home.id],['museum',M.house.door.x,M.house.door.y,M.house.id],['foreign',foreign.door.x,foreign.door.y,foreign.id],...coordinates.map(([key,x,y])=>[key,x,y,null])];
 for(const [scenario,x,y,room]of placements)for(const walking of [false,true]){
  s.day=index%4===0?13:index%4===1?2:index%4===2?1:0;s.minutes=index%3===0?700:index%3===1?930:1200;M.ensure(s).level=2;
  s.village.npc[n.id]={x,y,room,direction:index%2?'left':'down'};V.stateRuntime(s).actors[n.id]={walking};
  const location=N.location(s,n.id),destination=copy(V.destination(s,'npc',n.id));delete destination.npc;
  emit({kind:'query',id:n.id,scenario,day:s.day,minutes:s.minutes,level:2,resident:copy(s.village.npc[n.id]),walking,expected:{location,scene:C.npcScene(s,n),destination,atlas:copy(S.targets(s).find(p=>p.id==='neighbor-'+n.id))}});queries++;
 }
 s.village.npc[n.id]={...home.door,room:home.id,direction:'down'};
}
for(const r of V.regions)emit({kind:'bounds',id:r.id,x:r.x,y:r.y,width:1920,height:r.y===2304?1536:1152});
for(const x of [-1,0,1919.999,1920,3839.999,3840])for(const y of [-1,0,1151.999,1152,2303.999,2304,3455.999,3456,3839.999,3840]){
 emit({kind:'region',x,y,expected:V.regionAt(x,y).id});regions++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({queries,regions}));console.log(JSON.stringify({queries,regions}));
