const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','actions'])require('../../src/'+name+'.js');
const rows=[];
function add(op,id,value,setup){
 const s=ZRZCore.initial();setup?.(s);const before=structuredClone(s);
 const result=op==='configure'?ZRZBuild.configure(s,id,value):op==='mode'?ZRZBuild.mode(s,id,value):ZRZCore.storageMove(s,id,value,true);
 rows.push({op,id,value,before,result,expected:{building:s.building,bag:s.bag,storage:s.storage,quality:s.quality,storageQuality:s.storageQuality,lots:s.kitchen.lots,economy:s.economy}});
}
for(const house of [0,2,3])for(const value of ['wood','blue','plum','invalid'])add('configure','style',value,s=>{s.building.house=house;});
for(const house of [0,2,3])for(const value of ['display','workshop','nursery','storage','invalid'])add('configure','roomUse',value,s=>{s.building.house=house;});
for(const value of [null,'cabbage','unknown'])for(const discovered of [false,true])add('configure','showcase',value,s=>{s.discovered=discovered?['cabbage']:[];});
for(const id of [...Object.keys(ZRZBuild.modes),'unknown'])for(const level of [0,1,2])for(const value of ['invalid',...(ZRZBuild.modes[id]||[]).map(r=>r[0])])add('mode',id,value,s=>{s.building.levels[id]=level;});
for(const upgraded of [false,true])for(const locked of [false,true])for(const quantity of [0,1,4,5,999999,1000000])add('storage','cabbage',quantity,s=>{s.upgrades.storage=upgraded;ZRZCore.add(s,'cabbage',4);s.quality.cabbage=[1,1,0];s.economy.locked=locked?['cabbage']:[];});
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual building configuration and public storage '+rows.length);
