const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[];
for(let day=0;day<112;day++){
 const s=ZRZCore.initial();s.day=day;s.minutes=450;
 const samples=ZRZTiles.points(s).map(p=>({p,expected:ZRZFeedback.describe(s,p)}));
 rows.push({kind:'scenery',day,samples});
}
for(const day of [0,1,2,13,28,41,56,69,84,97,111])for(const minutes of [390,600,930,1200])for(const walking of [false,true]){
 const s=ZRZCore.initial();s.day=day;s.minutes=minutes;ZRZNpc.ensure(s);ZRZMuseum.ensure(s).level=2;
 const samples=ZRZData.npcs.map(n=>{
  ZRZVillage.stateRuntime(s).actors[n.id]={walking};
  const p={kind:'npc',id:n.id,name:n.name};
  return {p,expected:ZRZFeedback.describe(s,p)};
 });
 rows.push({kind:'npc',day,minutes,walking,residents:s.village.npc,neighbors:s.neighbors,collection:s.collection,projects:s.projects,samples});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));console.log(JSON.stringify({rows:rows.length,descriptions:rows.reduce((n,r)=>n+r.samples.length,0)}));
