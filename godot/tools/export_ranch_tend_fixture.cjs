const fs=require('node:fs');global.window=globalThis;
// Isolate the actual ranch load wrapper: action fixtures intentionally inject\n// invalid feed identifiers into other modules to exercise failed actions.\nlet ranchLoader;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions']){require('../../src/'+name+'.js');if(name==='ranch')ranchLoader=ZRZCore.load;}
const C=ZRZCore,R=ZRZRanch,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>Object.fromEntries(['day','minutes','stamina','money','kitchen','skills','stats','journal','eventLog','discovered','flags','bag','quality','knownRecipes','ranch','animals','pet','processing','toolkit','storage','storageQuality','upgrades','animalCare','toolUpgrades'].map(k=>[k,s[k]]));


const acts=['feed','pet','clean','treat','vet','rest','rescue','collect'];
function fresh(type,breed='local',trait='friendly'){const s=C.initial();s.day=27;s.money=100000;for(const b of Object.values(s.ranch.barns)){b.built=true;b.space=1;}s.animals=[];R.buyAnimal(s,type,'female',breed,false);const a=s.animals[0];Object.assign(a,{trait,personality:R.traits[trait],hunger:30.25,health:60.25,mood:50.125,clean:42.75,stress:20.75,illness:39.25,bond:20,fed:false,ready:4,qualityStock:[1,1,1,1],feathers:type==='hen'?2:0,lost:true});s.bag.feed=10;s.bag.hay=10;s.bag.grainFeed=10;s.bag.healthFeed=10;s.bag.animalMedicine=3;s.minutes=600.25;s.stamina=100;return s;}
function emit(s,row){K.ensure(s);const before=copy(s);const shell=C.initial();shell.day=before.day;shell.ranch=structuredClone(before.ranch);shell.animals=structuredClone(before.animals);const normalized=ranchLoader(shell);s.ranch=normalized.ranch;s.animals=normalized.animals;const result=R.action(s,row.animal,row.action,row.arg),expected=copy(snapshot(s)),steps=[];if(row.variant==='normal'&&result.ok)for(let i=0;i<2;i++){const result=C.nextDay(s);steps.push({result,expected:copy(snapshot(s))});}rows.push({...row,before,result,expected,steps});}
function variant(s,action,v,arg){const a=s.animals[0],b=s.ranch.barns[R.species[a.type].home];
 if(v==='low')s.stamina=0;if(v==='one')s.stamina=1;if(v==='gentle'){s.stamina=1;s.skills.farming.choice='gentle';}if(v==='labor'){s.stamina=1;s.buffs.laborDay=s.day;}if(v==='buff'){s.stamina=1;s.kitchen.buff={kind:'暖胃',until:s.day*1440+s.minutes+180};}
 if(v==='late')s.minutes=1319.875;if(v==='money')s.money=0;
 if(v==='missing'){delete s.bag[arg||'feed'];delete s.bag.animalMedicine;}
 if(v==='locked')s.economy.locked=[arg||'feed','animalMedicine'];
 if(v==='premium')for(const k of [arg||'feed','animalMedicine'])s.quality[k]=[s.bag[k]||0,0,0];
 if(v==='mixed')for(const k of [arg||'feed','animalMedicine'])s.quality[k]=[0,(s.bag[k]||1)-1,0];
 if(v==='repeat')for(const k of ['feed','pet','clean','treat'])a.care[k]=s.day;
 if(v==='healthy'){a.health=95;a.illness=.75;}if(v==='illness1'){a.health=95;a.illness=1;}if(v==='health94'){a.health=94.75;a.illness=0;}
 if(v==='full'){a.hunger=90;a.clean=95;}if(v==='below'){a.hunger=89.75;a.clean=94.75;}
 if(v==='empty'){a.ready=0;a.qualityStock=[0,0,0,0];a.feathers=0;}
 if(v==='feathers'){a.ready=0;a.qualityStock=[0,0,0,0];a.feathers=3;}
 if(v==='present')a.lost=false;if(v==='resting')a.rest=true;
 if(v==='efficiency')b.efficiency=1;
 if(v==='tool1')s.toolkit.tools.care.level=1;
 if(v==='broad'){s.toolkit.tools.care.level=2;s.toolkit.tools.care.branch='broad';}
 if(v==='care'){s.toolkit.tools.care.level=2;s.toolkit.tools.care.branch='care';}
 if(v==='xpmax')s.toolkit.tools.care.xp=99999;
}
for(const type of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const trait of Object.keys(R.traits))for(const action of acts){const s=fresh(type,breed,trait);emit(s,{op:'tend',id:type,breed,trait,action,arg:'feed',animal:s.animals[0].id,variant:'normal'});}
const variations=['low','one','gentle','labor','buff','late','money','missing','locked','premium','mixed','repeat','healthy','illness1','health94','full','below','empty','feathers','present','resting','efficiency','tool1','broad','care','xpmax'];
for(const type of Object.keys(R.species))for(const action of acts)for(const v of variations){const s=fresh(type);variant(s,action,v,'feed');emit(s,{op:'tend',id:type,action,arg:'feed',animal:s.animals[0].id,variant:v});}
for(const type of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const arg of ['feed','hay','grainFeed','healthFeed','missing',''])for(const v of ['normal-feed','locked','premium','mixed','missing','below']){const s=fresh(type,breed);variant(s,'feed',v,arg);emit(s,{op:'tend',id:type,breed,action:'feed',arg,animal:s.animals[0].id,variant:v});}
for(const type of Object.keys(R.species))for(const action of ['clean','collect'])for(const [level,branch]of [[0,'broad'],[1,'broad'],[2,'broad'],[2,'care']])for(const v of ['tool-normal','low','one','gentle','labor','buff','efficiency','xpmax']){const s=fresh(type);s.toolkit.tools.care.level=level;s.toolkit.tools.care.branch=branch;variant(s,action,v,'feed');emit(s,{op:'tend',id:type,action,arg:'feed',level,branch,animal:s.animals[0].id,variant:v});}
for(const type of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const young of [true,false])for(const retired of [true,false]){const s=fresh(type,breed);s.animals[0].age=young?0:R.species[type].adult;s.animals[0].retired=retired;emit(s,{op:'retire',id:type,breed,young,retired,action:'retire',arg:null,animal:s.animals[0].id,variant:'retire'});}
for(const type of Object.keys(R.species))for(const arg of ['小麦','  糯米  ','','   ','一二三四五六七八九十甲乙丙丁',null,42,true]){const s=fresh(type);emit(s,{op:'name',id:type,action:'name',arg,animal:s.animals[0].id,variant:'name'});}
for(const [animal,action]of [['missing','feed'],['livestock-1','missing']]){const s=fresh('hen');emit(s,{op:'tend',id:'hen',action,arg:'feed',animal,variant:'invalid'});}
// Real UI samples start beside an animal in its valid barn, and run the entire
// original load chain before settlement. Keep all existing direct action cases.
for(const row of [...rows]){
 const selected=row.op==='tend'&&row.variant==='normal'&&row.breed==='local'&&row.trait==='friendly'
  ||row.op==='tend'&&row.variant==='tool-normal'&&row.level===2
  ||row.op==='retire'&&row.breed==='local'&&!row.young&&!row.retired
  ||row.op==='name'&&row.arg==='  糯米  ';
 if(!selected)continue;
 let s=copy(row.before);const house=R.barns[R.species[row.id].home].house;
 s.village.interior=house;s.player={x:480,y:550,direction:'up'};
 s.animals[0].position.room=house;s.animals[0].position.inside={x:480,y:510,direction:'down'};
 K.ensure(s);s=C.load(copy(s));const before=copy(s),result=R.action(s,row.animal,row.action,row.arg);
 rows.push({...row,uiScenario:true,before,result,expected:copy(snapshot(s)),steps:[]});
}

function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(exact(r))).join('\n')+'\n');console.log('Ranch tend cases: '+rows.length);
