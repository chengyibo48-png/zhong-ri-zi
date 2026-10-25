const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const D=ZRZData,E=ZRZEconomy,ordered=Object.keys(D.items).sort((a,b)=>D.items[a].name.localeCompare(D.items[b].name,'zh-Hans'));
const data={};ordered.forEach((id,rank)=>data[id]={rank,...E.details(id)});
fs.writeFileSync(process.argv[2],JSON.stringify(data,null,2));console.log('Inventory metadata: '+ordered.length);
