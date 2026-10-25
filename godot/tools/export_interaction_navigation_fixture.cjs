const fs=require('node:fs');global.window=globalThis;
require('./source_navigation_runtime.cjs');
const C=ZRZCore,V=ZRZVillage,A=ZRZActions,exact=require('./export_world_precision.cjs'),fd=fs.openSync(process.argv[2],'w');
const seed=C.load(JSON.stringify(C.initial())),states=[];
for(const room of [null,...V.houses.filter(h=>['home','home-granny',ZRZMuseum.house.id].includes(h.id)||h.name==='禾溪小灶'||h.name==='禾溪村史馆'||h.region==='pasture').map(h=>h.id)]){
 const s=structuredClone(seed);s.village.interior=room;s.player=room?{x:480,y:560,direction:'down'}:{x:2831.125,y:1652.75,direction:'down'};ZRZMuseum.ensure(s);states.push(s);if(room===ZRZMuseum.house.id)for(const level of [1,3]){const extra=structuredClone(s);ZRZMuseum.ensure(extra).level=level;states.push(extra);}
}
const geometry=states.map((s,index)=>{
 const room=s.village.interior,rects=room===ZRZMuseum.house.id?ZRZMuseumView.obstacles(s):room&&ZRZInteriors.layouts[room]?ZRZInteriors.layouts[room].rows.map(p=>({x:p.x-p.w/2,y:p.y-p.h,w:p.w,h:p.h+18})):[];
 const probes=[];
 for(const r of rects){
  const midx=r.x+r.w/2,midy=r.y+r.h/2;
  for(const delta of [-1e-8,0,1e-8])for(const [x,y]of [[r.x+delta,midy],[r.x+r.w+delta,midy],[midx,r.y+delta],[midx,r.y+r.h+delta]])probes.push({x,y,blocked:V.blocked(s,x,y)});
 }
 return {index,probes};
});
fs.writeSync(fd,JSON.stringify(exact({states,geometry}))+'\n');let cases=0;const kinds={};
for(let index=0;index<states.length;index++){
 const s=states[index],points=V.points(s,true).filter((p,i)=>i%4===0);
 points.push({kind:'walk',x:s.player.x+.499999999,y:s.player.y+.499999999},{kind:'npc',x:s.player.x+60,y:s.player.y-10},{kind:'ranch-task',x:s.player.x+50,y:s.player.y-5},{kind:'farm-task',x:s.player.x-40,y:s.player.y+10},{kind:'museum-task',x:s.player.x+30,y:s.player.y+20},{kind:'exit',x:480,y:590},{kind:'build-task',x:s.player.x-55,y:s.player.y-15},{kind:'kitchen-task',x:s.player.x+35,y:s.player.y-35});
 for(const target of points){
  const stand=A.approach(s,target),path=V.route(s,stand.x,stand.y);
  fs.writeSync(fd,JSON.stringify(exact({index,target,stand,path}))+'\n');cases++;kinds[target.kind]=(kinds[target.kind]||0)+1;
 }
}
fs.closeSync(fd);console.log(JSON.stringify({states:states.length,cases,kinds,boundaries:geometry.reduce((n,g)=>n+g.probes.length,0)}));
