const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,E=ZRZEconomy,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
function sample(id,to,grade,variant='normal'){
 const s=C.initial();s.upgrades.storage=variant!=='noCabinet';C.add(s,id,9);s.bag[id]=to?9:2;s.storage[id]=to?2:9;s.quality[id]=to?[2,2,2]:[0,1,0];s.storageQuality[id]=to?[0,1,0]:[2,2,2];
 if(variant==='missing'){s[to?'bag':'storage'][id]=1;s[to?'quality':'storageQuality'][id]=[0,0,0];}
 if(variant==='full')s[to?'storage':'bag'][id]=999999;
 if(variant==='locked')s.economy.locked=[id];
 K.ensure(s);if(K.food(id))for(const side of ['bag','storage']){const n=s[side][id];s.kitchen.lots[side][id]=[{qty:n-1,age:4},{qty:1,age:1}];}
 const amount=variant==='zero'?0:variant==='invalidQty'?1000000:grade<0?5:2,before=copy(s),result=E.transfer(s,id,amount,to,grade);
 rows.push({op:'transfer',id,to,grade,amount,variant,before,result,expected:{bag:s.bag,storage:s.storage,quality:s.quality,storageQuality:s.storageQuality,lots:s.kitchen.lots,economy:s.economy}});
}
for(const id of Object.keys(D.items))for(const to of [false,true])for(const grade of [-1,0,1,2,3])sample(id,to,grade);
for(const to of [false,true])for(const variant of ['noCabinet','missing','full','locked','zero','invalidQty'])sample('rice',to,-1,variant);
for(const to of [false,true])for(const category of E.categories)for(const variant of ['normal','noCabinet','nothing']){
 const s=C.initial();s.upgrades.storage=variant!=='noCabinet';s.bag={};s.storage={};s.quality={};s.storageQuality={};
 for(const id of Object.keys(D.items)){s.bag[id]=to?9:2;s.storage[id]=to?2:9;s.quality[id]=to?[2,2,2]:[0,1,0];s.storageQuality[id]=to?[0,1,0]:[2,2,2];if(variant==='nothing'){s.bag[id]=5;s.storage[id]=0;s.quality[id]=[0,0,0];s.storageQuality[id]=[0,0,0];}}
 K.ensure(s);const before=copy(s),result=E.tidy(s,category,to);
 rows.push({op:'tidy',category,to,variant,before,result,expected:{bag:s.bag,storage:s.storage,quality:s.quality,storageQuality:s.storageQuality,lots:s.kitchen.lots,economy:s.economy}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Inventory storage source rows: '+rows.length);
