const fs=require('node:fs');global.window=globalThis;
for(const n of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','environment','forage'])require('../../src/'+n+'.js');
const rows=ZRZForage.rawPoints(ZRZCore.initial()).map(({id,item})=>({id,item}));
if(new Set(rows.map(p=>p.id)).size!==rows.length)throw Error('Duplicate source resource identity');
fs.writeFileSync(process.argv[2],JSON.stringify(rows));console.log('Source resource identities: '+rows.length);
