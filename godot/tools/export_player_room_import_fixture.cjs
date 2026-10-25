const fs=require('node:fs');
require('./source_navigation_runtime.cjs');
const C=ZRZCore,V=ZRZVillage,W=ZRZWorld,exact=require('./export_world_precision.cjs');
const fd=fs.openSync(process.argv[2],'w');let cases=0;
for(const h of V.houses)for(const variant of ['decimal','absent','invalid-back','bare-back','blocked-player']){
 const s=C.initial();s.minutes=600;s.village.interior=h.id;s.village.riding=true;
 s.player=V.safePosition(s,{x:480.123456789,y:550.987654321,direction:'left'});
 s.village.returnPoint=variant==='absent'?null:variant==='invalid-back'?{x:-1,y:500}:variant==='bare-back'?{...h.door}:{x:h.door.x+.123456789,y:h.door.y+12.987654321,direction:'left'};
 if(variant==='blocked-player'){
  const row=ZRZInteriors.layouts[h.id]?.rows?.[0];
  s.player=row?{x:row.x,y:row.y-1,direction:'up'}:{x:245,y:254,direction:'up'};
 }
 const before=structuredClone(s),loaded=C.load(before);W.restorePosition(loaded);
 const expected={player:loaded.player,room:loaded.village.interior,back:loaded.village.returnPoint,riding:loaded.village.riding};
 fs.writeSync(fd,JSON.stringify(exact({label:h.id+'/'+variant,before,expected}))+'\n');cases++;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases}));console.log(JSON.stringify({cases}));
