const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,E=ZRZEconomy,D=ZRZData,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
for(const op of ['lock','pin'])for(const id of [...Object.keys(D.items),'missing-id'])for(const variant of ['empty','existing','full']){
 const s=C.initial();s.economy.locked=variant==='existing'?[id].filter(x=>D.items[x]):variant==='full'?Object.keys(D.items):[];s.economy.pinned=variant==='existing'?[id].filter(x=>D.items[x]):variant==='full'?Object.keys(D.items).filter(x=>x!==id).slice(0,6):[];
 const before=copy(s),result=E[op](s,id);
 rows.push({op,id,variant,before,result,expected:{economy:s.economy,bag:s.bag}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Inventory mark source rows: '+rows.length);
