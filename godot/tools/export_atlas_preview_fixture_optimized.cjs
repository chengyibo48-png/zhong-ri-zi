const fs=require('node:fs');global.window=globalThis;
require('./source_navigation_runtime.cjs');
const C=ZRZCore,V=ZRZVillage,S=ZRZScenes,exact=require('./export_world_precision.cjs');
const seed=C.load(JSON.stringify(C.initial())),fd=fs.openSync(process.argv[2],'w');
let count=0;const originalBuilding=JSON.stringify(seed.building);
for(const room of [null,...V.houses.map(h=>h.id)]){
 if(room&&!V.houses.some(h=>h.id===room))continue;
 for(const riding of [false,true]){
  // Identical read-only layout keeps the real source navigation cache warm.
  const s=structuredClone(seed);s.building=seed.building;s.village.interior=room;s.village.riding=riding;
  s.player=room?{x:480,y:560,direction:'down'}:{x:2831.125,y:1652.75,direction:'down'};
  const probes=[null,{id:'missing'}, {x:2831,y:1652},{x:24,y:3816},{x:2831.499999999,y:1652.499999999},
   ...S.targets(s).filter(t=>['homes','services'].includes(t.type)).filter((t,i)=>i%5===0).map(t=>({id:t.id}))];
  if(room)probes.push({id:room});
  for(const target of probes){
   const expected=S.preview(s,target);
   if(JSON.stringify(seed.building)!==originalBuilding)throw Error('Preview mutated shared read-only building layout');
   fs.writeSync(fd,JSON.stringify(exact({state:s,target,expected}))+'\n');count++;
  }
 }
}
fs.closeSync(fd);console.log(JSON.stringify({cases:count}));
