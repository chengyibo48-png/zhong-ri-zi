const fs=require('node:fs');global.window=globalThis;
require('./source_navigation_runtime.cjs');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,F=ZRZFarming,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>({day:s.day,minutes:s.minutes,stamina:s.stamina,bag:s.bag,quality:s.quality,kitchen:s.kitchen,processing:s.processing,stats:s.stats,journal:s.journal,eventLog:s.eventLog,discovered:s.discovered,flags:s.flags,letters:s.letters,building:s.building,farm:s.farm,plots:s.plots,ranch:s.ranch,animals:s.animals,upgrades:s.upgrades});
for(const day of Array.from({length:112},(_,i)=>i))for(const variant of ['living','construction','water','seed','cold','canal']){
 let s=C.initial();s.day=day;s.money=10000;
 const crop=Object.keys(D.crops).find(id=>D.crops[id].seasons.includes(C.calendar(s).season));
 C.add(s,D.crops[crop].seed,10);
 for(let i=0;i<3;i++){F.perform(s,i,'hoe');F.perform(s,i,'sow',{crop,kind:'normal',density:['sparse','balanced','dense'][i]});s.farm.beds[i].moisture=65;}
 for(const a of s.animals){a.hunger=85;a.care.feed=day;}
 s.processing=[{id:'pickles',qty:2,readyDay:day+1,station:'腌菜坛',cooking:true,farmGrade:2}];
 if(variant==='construction')s.building.jobs=[{id:'well',level:1,readyDay:day+1},{id:'nursery',level:1,readyDay:day+1}];
 if(variant==='water'){s.building.levels.well=2;s.building.modes.well='spring';s.farm.water=0;}
 if(variant==='seed'){s.building.levels.nursery=1;s.building.modes.nursery='seed';}
 if(variant==='cold'){s.building.levels.granary=2;s.kitchen.cold=true;s.storage.milk=3;}
 if(variant==='canal'){s.projects.canal=true;for(const r of Object.values(s.relations))r.points=35;}
 K.ensure(s);s.minutes=1319.875;s.stamina=10;
 const before=copy(s);s=C.load(before);const result=C.nextDay(s),expected=copy(snapshot(s));
 const result2=C.nextDay(s),expected2=copy(snapshot(s));
 rows.push({day,variant,before,steps:[{result,expected},{result:result2,expected:expected2}]});
}
function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(exact(r))).join('\n')+'\n');console.log('Integrated overnight cases: '+rows.length);
