const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
for(const op of ['repair','project'])for(const variant of ['ready','no-intro','wood7','bamboo5','lock-wood','lock-bamboo','locked-no-intro','locked-done','done','photo-present','cap','cooperate','full','town']){
 const s=C.initial();s.day=10;s.minutes=600;s.flags.firstDish=true;C.add(s,'wood',8);C.add(s,'bamboo',6);K.ensure(s);
 if(variant==='no-intro'||variant==='locked-no-intro')s.flags.firstDish=false;
 if(variant==='wood7')s.bag.wood=7;if(variant==='bamboo5')s.bag.bamboo=5;
 if(variant==='lock-wood'||variant.startsWith('locked-'))s.economy.locked=['wood'];
 if(variant==='lock-bamboo')s.economy.locked=['bamboo'];
 if(variant==='done'||variant==='locked-done'){s.flags.bridge=true;s.projects.bridge=true;}
 if(variant==='photo-present')s.archives.push('photo');
 if(variant==='cap'){s.relations.chen.points=99;s.skills.craft.xp=99998;}
 if(variant==='cooperate')s.skills.craft.choice='cooperate';
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 if(variant==='town'){s.scene='town';s.player.y=500;}
 const before=copy(s),result=op==='repair'?C.repair(s):C.project(s,'bridge');
 rows.push({op,variant,before,result,expected:{bag:s.bag,quality:s.quality,flags:s.flags,projects:s.projects,archives:s.archives,relations:s.relations,skills:s.skills,recipes:s.knownRecipes,journal:s.journal,eventLog:s.eventLog,discovered:s.discovered},loadedArchives:C.load(before).archives});
}
const s=C.initial();s.day=10;s.flags.bridge=true;s.projects.bridge=true;
fs.writeFileSync(process.argv[2],JSON.stringify({rows,snapshot:copy(s),loadedArchives:C.load(copy(s)).archives}));console.log('Bridge source cases: '+rows.length);
