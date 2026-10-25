const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[],copy=x=>JSON.parse(JSON.stringify(x)),C=ZRZCore,D=ZRZData,K=ZRZKitchen,B=ZRZBuild;
for(const category of ['food','seed','material','feed'])for(const withdraw of [false,true])for(const variant of ['normal','unbuilt','noCabinet','level1','freshMode','nothing','mixed','aged','locked']){
 const s=C.initial();s.building.levels.granary=variant==='unbuilt'?0:variant==='level1'?1:2;s.building.modes.granary=variant==='freshMode'?'fresh':'supply';s.upgrades.storage=variant!=='noCabinet';s.bag={};s.storage={};s.quality={};s.storageQuality={};
 for(const id of Object.keys(D.items)){s.bag[id]=withdraw?2:9;s.storage[id]=withdraw?9:2;if(variant==='nothing'){s.bag[id]=5;s.storage[id]=0;}if(variant==='mixed'){s.bag[id]=withdraw?1:9;s.storage[id]=withdraw?9:1;s.quality[id]=withdraw?[1,0,0]:[2,2,2];s.storageQuality[id]=withdraw?[2,2,2]:[0,1,0];}}
 K.ensure(s);
 if(variant==='aged')for(const id of Object.keys(D.items))if(K.food(id)){s.kitchen.lots.bag[id]=[{qty:s.bag[id]-1,age:4},{qty:1,age:1}];s.kitchen.lots.storage[id]=[{qty:s.storage[id]-1,age:3},{qty:1,age:0}];}
 if(variant==='locked')s.economy.locked=Object.keys(D.items);
 const before=copy(s),result=B.sortStore(s,category,withdraw);
 rows.push({category,withdraw,variant,before,result,expected:{bag:s.bag,storage:s.storage,quality:s.quality,storageQuality:s.storageQuality,lots:s.kitchen.lots,economy:s.economy}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Building storage source rows: '+rows.length);
