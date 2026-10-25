const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum'])require('../../src/'+name+'.js');
const output={};
for(let season=0;season<4;season++){
 const s=ZRZCore.initial();s.day=season*28;
 output[season]=ZRZVillage.points(s,true).filter(p=>p.kind==='gather'&&/^(mountain|bamboo)-[0-5]$/.test(p.id)).map(p=>({...p,baseName:ZRZData.items[p.item].name}));
 if(output[season].length!==12)throw Error('Missing source legacy gather points');
}
fs.writeFileSync(process.argv[2],JSON.stringify(output,null,2));
console.log('Exported 48 original seasonal legacy gather points');
