const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback']) require('../../src/'+name+'.js');

const C=global.ZRZCore,B=global.ZRZBuild,V=global.ZRZVillage;
const rows=[], furniture=[];
for(let house=0;house<=3;house++)for(const roomUse of ['display','workshop','nursery','storage']){
 const s=C.initial();B.ensure(s);s.building.house=house;s.building.roomUse=roomUse;s.village.interior=B.home().id;
 rows.push({house,roomUse,points:B.roomObjects(B.home(),s)});
}
for(const type of ['bench','pot'])for(let rotation=0;rotation<4;rotation++){
 const s=C.initial();B.ensure(s);s.building.house=3;s.village.interior=B.home().id;
 for(let cell=0;cell<B.zones.home.cols*B.zones.home.rows;cell++){
  const piece={key:1,type,zone:'home',cell,rotation};
  if(!B.placement(s,piece,[]).ok)continue;
  s.building.layout=[piece];const points=B.points(s);if(!points.length)continue;
  furniture.push({piece,point:points[0]});break;
 }
}
if(!process.argv[2])throw Error('Pass a temporary output filename');
fs.writeFileSync(process.argv[2],JSON.stringify({rows,furniture},null,2));
console.log('Exported '+rows.length+' original home layouts and '+furniture.length+' furniture targets');
