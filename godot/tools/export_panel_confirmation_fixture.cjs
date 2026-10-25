const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','actions'])require('../../src/'+name+'.js');
const claims=[],retire=[];
for(const id of [...Object.keys(ZRZBuild.milestones),'invalid'])for(const ready of [false,true])for(const claimed of [false,true])for(const stock of [0,999,1000]){
 const s=ZRZCore.initial(),b=ZRZBuild.ensure(s);
 if(ready){b.house=3;b.levels.granary=1;b.levels.workshop=1;b.levels.well=1;b.layout=Array.from({length:5},(_,i)=>({key:i+1,type:i===0?'display':'bench',zone:'court',cell:i*3,rotation:0}));b.nextId=6;}
 if(claimed&&id!=='invalid')b.claimed.push(id);
 const reward=ZRZBuild.milestones[id]?.reward;if(reward)s.furniture[reward]=stock;
 const before={building:structuredClone(b),furniture:structuredClone(s.furniture)},result=ZRZBuild.claim(s,id);
 claims.push({id,before,result,after:{building:s.building,furniture:s.furniture}});
}
for(const index of [0,1,2])for(const young of [false,true])for(const retired of [false,true]){
 let s=ZRZCore.initial();ZRZRanch.ensure(s);const a=s.animals[index];
 a.age=young?0:ZRZRanch.species[a.type].adult;a.retired=retired;
 const before=structuredClone(s);s=ZRZCore.load(before);const result=ZRZRanch.action(s,a.id,'retire',s.ranch.feed);
 retire.push({before,id:a.id,task:{animalId:a.id,action:'retire',arg:s.ranch.feed},result,after:s.animals[index]});
}
const missing=[];
const optional=['fishing','economy','forage','environment','kitchen','toolkit','farm','building','ranch','neighbors'];
for(const keys of [...optional.map(k=>[k]),optional]){
 const before=ZRZCore.initial();for(const key of keys)delete before[key];
 const loaded=ZRZCore.load(before),expected={};for(const key of optional)expected[key]=loaded[key];
 missing.push({keys,before,expected});
}
function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],JSON.stringify(exact({claims,retire,missing})));console.log('Building claims '+claims.length+'; ranch retire '+retire.length);
