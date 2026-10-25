const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[],copy=x=>JSON.parse(JSON.stringify(x)),C=ZRZCore;
for(const year of [1,2])for(const season of [0,1,2,3])for(const choice of [0,1])for(const variant of ['base','early','late','already','missing','wrongDish','wrongChoice','cap']){
 const s=C.initial();s.day=(year-1)*112+season*28+(variant==='early'?12:variant==='late'?27:13);s.minutes=600;C.add(s,'eggRice',3);const dish=variant==='wrongDish'?'wood':'eggRice';C.add(s,'wood',3);
 if(variant==='already')s.festivals.push(year+'-'+season);
 if(variant==='missing')C.consume(s,{eggRice:s.bag.eggRice});
 if(variant==='cap')for(const r of Object.values(s.relations))r.points=98;
 const selected=variant==='wrongChoice'?3:choice,before=copy(s),result=C.festival(s,dish,selected,season);
 rows.push({year,season,choice:selected,variant,dish,before,result,expected:{bag:s.bag,relations:s.relations,festivals:s.festivals,seasonEvents:s.seasonEvents,knownRecipes:s.knownRecipes,skills:s.skills,lots:s.kitchen.lots,eventLog:s.eventLog}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Festival source rows: '+rows.length);
