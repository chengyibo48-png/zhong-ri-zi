const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','actions'])require('../../src/'+name+'.js');
const C=ZRZCore, rows=[];
for(const id of ['ranchMilk','ranchWool','ranchYogurt'])for(const variant of ['ready','missing','done','flag','locked','duplicate','null']){
 const s=C.initial();s.money=1000;const order=ZRZData.orders.find(o=>o.id===id);
 for(const [item,n] of Object.entries(order.needs))C.add(s,item,variant==='missing'?0:n);
 if(variant==='done')s.ranch.delivered=[id];if(variant==='duplicate')s.ranch.delivered=[id,id];if(variant==='null')s.ranch.delivered=null;
 if(variant==='flag')s.flags[id]=true;if(variant==='locked')s.economy.locked=Object.keys(order.needs);
 const before=structuredClone(s),loaded=C.load(s),loadedDone=structuredClone(loaded.ranch.delivered),loadedFlags=structuredClone(loaded.flags);
 const result=C.deliver(loaded,id),second=C.deliver(loaded,id);
 rows.push({id,variant,before,loadedDone,loadedFlags,result,second,expected:{ranch:loaded.ranch,flags:loaded.flags,bag:loaded.bag,money:loaded.money,relations:loaded.relations}});
}
const invalid=[{},['unknown'],['ranchMilk',1],true,'ranchMilk'];
fs.writeFileSync(process.argv[2],JSON.stringify({rows,invalid}));console.log('Ranch orders: '+rows.length);
