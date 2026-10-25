const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>({day:s.day,minutes:s.minutes,stamina:s.stamina,money:s.money,pet:s.pet,bag:s.bag,quality:s.quality,kitchen:s.kitchen,processing:s.processing,stats:s.stats,journal:s.journal,eventLog:s.eventLog,discovered:s.discovered,flags:s.flags,letters:s.letters,building:s.building,farm:s.farm,plots:s.plots,ranch:s.ranch,animals:s.animals,upgrades:s.upgrades});
const dates=[0,13,17,19,27,51,99,111,...[...new Set(Array.from({length:112},(_,i)=>C.weather(i)))].map(w=>Array.from({length:112},(_,i)=>i).find(i=>C.weather(i)===w))];
let seq=0;
function run(t,breed,trait,scenario,forcedDay){
 const day=forcedDay??dates[(seq++)%dates.length];let s=C.initial();s.day=day;s.money=100000;s.animals=[];
 for(const p of s.plots){p.crop=null;p.growth=0;}
 for(const b of Object.values(s.ranch.barns)){b.built=true;b.comfort=1;b.protection=1;}
 const purchased=R.buyAnimal(s,t,'female',breed,false);if(!purchased.ok)throw Error(purchased.msg);
 const a=s.animals[0],b=s.ranch.barns[R.species[t].home];a.trait=trait;a.personality=R.traits[trait];a.care.feed=-1;
 if(scenario==='fraction'){Object.assign(a,{hunger:44.25,health:59.75,mood:68.5,clean:31.25,stress:19.5,illness:29.75,warning:1,feedQuality:4.5,progress:0.875});b.clean=34.5;b.durability=89.25;s.ranch.grass=[10.75,45.5];s.ranch.pet.hunger=47.25;s.ranch.pet.energy=68.5;s.ranch.pet.training=20.25;}
 if(scenario==='illness'){Object.assign(a,{hunger:20,health:65,clean:20,illness:59.75,warning:2});b.clean=32;b.comfort=0;b.protection=0;}
 if(scenario==='rest'){Object.assign(a,{rest:true,hunger:85,health:50,illness:55.5,warning:1});}
 if(scenario==='feed-health'||scenario==='feed-empty'){a.hunger=22;a.illness=35;a.health=55;b.autoFeed=b.autoFeedBuilt=true;s.ranch.feed='healthFeed';s.ranch.stores.healthFeed=scenario==='feed-health'?10:0;}
 if(scenario==='clean'){b.autoClean=b.autoCleanBuilt=true;b.clean=25;b.waste=8;s.ranch.stores.bedding=10;a.clean=31.5;}
 if(scenario==='collect'||scenario==='feathers'){b.autoCollect=b.autoCollectBuilt=true;a.qualityStock=scenario==='feathers'?[0,0,0,0]:[1,1,1,1];a.ready=scenario==='feathers'?0:4;a.feathers=2;a.hunger=0;}
 if(scenario==='young'){a.age=0;a.progress=0.75;}
 if(scenario==='elder'){a.age=R.species[t].elder-1;a.progress=0.9;a.hunger=85;}
 if(scenario==='full'){a.qualityStock=[7,7,7,7];a.ready=28;a.progress=0.9;}
 if(scenario==='retired')a.retired=true;
 if(scenario==='lost')a.lost=true;
 if(scenario==='male')a.sex='male';
 if(scenario==='unsafe'||scenario==='dog'){s.ranch.policy='day';b.protection=0;b.comfort=0;a.hunger=36;a.clean=10;a.warning=1;if(scenario==='dog'){s.pet.type='dog';s.ranch.pet.mode='patrol';s.ranch.pet.training=20;s.ranch.pet.hunger=35;}}
 if(scenario==='cat'){s.pet.type='cat';s.ranch.pet.training=20;s.ranch.pet.hunger=35;s.ranch.stores.grainFeed=20;}
 if(scenario==='auto-all'){a.hunger=25;b.clean=28;b.autoFeed=b.autoFeedBuilt=b.autoClean=b.autoCleanBuilt=b.autoCollect=b.autoCollectBuilt=true;s.ranch.stores.feed=30;s.ranch.stores.bedding=10;s.ranch.stores.grainFeed=20;s.ranch.feed='grainFeed';}
 if(scenario==='birth'){s.ranch.births=[{id:'birth-2',type:t,mother:a.id,father:null,breed,remaining:1,total:R.species[t].gestation}];s.ranch.nextId=3;a.hunger=90;a.health=90;a.care.breed=day;a.generation=2;}
 if(scenario==='crowd'){b.space=3;for(let i=0;i<6;i++){const q=R.buyAnimal(s,t,'female',breed,false);if(!q.ok)throw Error(q.msg);}b.space=0;b.clean=29;for(const animal of s.animals){animal.hunger=24.5;animal.warning=1;animal.illness=2.75;}}
 if(scenario==='unbuilt')b.built=false;
 if(scenario==='broken'){b.durability=0;b.autoFeed=b.autoFeedBuilt=b.autoClean=b.autoCleanBuilt=b.autoCollect=b.autoCollectBuilt=true;b.clean=20;a.hunger=10;s.ranch.stores.feed=30;s.ranch.stores.bedding=10;}
 if(scenario==='incubate'){if(!['hen','duck'].includes(t))return;C.add(s,t==='hen'?'fertileHenEgg':'fertileDuckEgg',1);const out=R.incubate(s,t);if(!out.ok)throw Error(out.msg);s.ranch.births[0].remaining=1;}
 if(scenario==='breed'){b.space=1;R.buyAnimal(s,t,'male',breed,false);C.add(s,'grainFeed',2);const out=R.breed(s,a.id,s.animals[1].id);if(!out.ok)throw Error(out.msg);s.ranch.births[0].remaining=1;}
 if(scenario==='birth-pause'){s.ranch.births=[{id:'birth-2',type:t,mother:a.id,father:null,breed,remaining:1,total:R.species[t].gestation}];s.ranch.nextId=3;a.hunger=15;b.clean=25;b.comfort=0;}
 if(scenario==='pet-fraction'){s.pet.type='dog';s.ranch.pet.mode='patrol';s.ranch.pet.training=19.75;s.ranch.pet.hunger=35.25;s.ranch.pet.energy=68.5;s.ranch.policy='day';b.protection=0;}
 if(scenario==='spread'){b.clean=35;b.comfort=0;R.buyAnimal(s,t,'male',breed,false);a.illness=59;a.warning=2;a.hunger=20;const other=s.animals[1];other.illness=0;other.hunger=85;other.clean=90;}
 K.ensure(s);s.minutes=1319.875;s.stamina=10;
 s=C.load(copy(s));
 const before=copy(s),steps=[];
 for(let i=0;i<2;i++){const result=C.nextDay(s);steps.push({result,expected:copy(snapshot(s))});}
 rows.push({day,variant:[t,breed,trait,scenario].join('/'),before,steps});
}
for(const t of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const trait of Object.keys(R.traits))run(t,breed,trait,'fraction');
for(const t of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const scenario of ['healthy','illness','rest','feed-health','feed-empty','clean','collect','feathers','young','elder','full','retired','lost','male','unsafe','dog','cat','auto-all','birth','spread','crowd','unbuilt','broken','incubate','breed','birth-pause','pet-fraction'])run(t,breed,'friendly',scenario);
if(process.argv.includes('--year'))for(let day=0;day<112;day++)for(const scenario of ['auto-all','unsafe','dog','cat'])run('pig','productive','hungry',scenario,day);
// Keep the original JS binary64 values in the oracle; Godot's decimal JSON
// parser can otherwise introduce a one-unit rounding error before comparison.
function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(exact(r))).join('\n')+'\n');console.log('Ranch overnight cases: '+rows.length);
