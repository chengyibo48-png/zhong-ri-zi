const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>Object.fromEntries(['day','minutes','stamina','money','kitchen','skills','stats','journal','eventLog','discovered','flags','bag','quality','knownRecipes','ranch','animals','pet','processing','toolkit','storage','storageQuality','upgrades'].map(k=>[k,s[k]]));

function fresh(){const s=C.initial();s.day=27;s.minutes=600.25;s.money=100000;for(const b of Object.values(s.ranch.barns)){b.built=true;b.space=1;b.comfort=1;}return s;}
function emit(s,row,operation){K.ensure(s);const input=copy(s);try{s=C.load(copy(s));}catch(error){rows.push({...row,before:input,invalidLoad:true,sourceError:error.message});return;}const before=copy(s),result=operation(s),expected=copy(snapshot(s)),steps=[];if(row.variant==='normal'&&result.ok)for(let i=0;i<2;i++){const result=C.nextDay(s);steps.push({result,expected:copy(snapshot(s))});}rows.push({...row,before,result,expected,steps});}
function labor(s,variant){if(variant==='low')s.stamina=0;if(variant==='gentle'){s.stamina=1;s.skills.farming.choice='gentle';}if(variant==='labor'){s.stamina=1;s.buffs.laborDay=s.day;}if(variant==='buff'){s.stamina=1;s.kitchen.buff={kind:'暖胃',until:s.day*1440+s.minutes+180};}if(variant==='late')s.minutes=1319.875;}
const petVariants=['normal','fraction','hunger94','hunger95','energy14','energy15','training89','capped','fed','trained','patted','missing','locked','premium','mixed','low','gentle','labor','buff','late','noenergy','nofood'];
for(const type of ['cat','dog'])for(const action of ['feed','train','home','follow','patrol','play','pat','missing'])for(const variant of petVariants){
 const s=fresh(),p=s.ranch.pet;s.pet.type=type;s.pet.name=type==='dog'?'阿福':'小团';s.pet.bond=12;s.bag.feed=4;p.hunger=30;p.energy=50;p.training=10;
 if(variant==='fraction'){p.hunger=30.25;p.energy=50.75;p.training=10.125;}
 if(variant==='hunger94')p.hunger=94.75;if(variant==='hunger95')p.hunger=95;if(variant==='energy14')p.energy=14.75;if(variant==='energy15')p.energy=15;
 if(variant==='training89')p.training=89.75;if(variant==='capped'){p.hunger=94.75;p.energy=99.75;p.training=99.75;s.pet.bond=99;}
 if(variant==='fed')p.fed=s.day;if(variant==='trained')p.trained=s.day;if(variant==='patted')s.pet.patted=s.day;
 if(variant==='missing'||variant==='nofood')s.bag.feed=0;if(variant==='locked')s.economy.locked=['feed'];
 if(variant==='premium')s.quality.feed=[4,0,0];if(variant==='mixed')s.quality.feed=[0,3,0];
 if(variant==='noenergy')p.energy=0;labor(s,variant);
 emit(s,{op:'pet',id:type,action,variant},s=>R.petAction(s,action));
}
for(const type of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const sex of ['female','male'])for(const variant of ['normal','unconfirmed','missing','mother','father','ready','feathers','full','lost','retired','rest','lastanimal']){
 const s=fresh();s.animals=[];R.buyAnimal(s,type,sex,breed,false);const a=s.animals[0];a.clean=45.25;a.hunger=67.75;a.mood=51.125;a.position.inside={x:410.25,y:485.75};a.bond=34;let id=a.id,confirm=true;
 if(variant==='unconfirmed')confirm=false;if(variant==='missing')id='missing';
 if(variant==='mother'||variant==='father'){s.ranch.nextId=91;s.ranch.births.push({id:'birth-90',type,mother:variant==='mother'?a.id:null,father:variant==='father'?a.id:null,breed,remaining:2,total:R.species[type].gestation});}
 if(variant==='ready'){a.ready=1;a.qualityStock=[1,0,0,0];}if(variant==='feathers')a.feathers=1;
 if(variant==='full')for(let i=0;i<32;i++)s.ranch.rehomed.push({animal:{...copy(a),id:'record-'+i},fee:1,day:s.day});
 if(variant==='lost')a.lost=true;if(variant==='retired')a.retired=true;if(variant==='rest')a.rest=true;
 if(variant!=='lastanimal')R.buyAnimal(s,type,'female','local',false);
 s.stamina=100;s.minutes=600.25;
 emit(s,{op:'rehome',id:type,animal:id,breed,sex,confirm,variant},s=>R.rehome(s,id,confirm));
}
for(const type of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const sex of ['female','male'])for(const variant of ['normal','missing','unbuilt','full','reserved','money','low','gentle','labor','buff','lost','rest','retired','late']){
 const s=fresh();s.animals=[];R.buyAnimal(s,type,sex,breed,false);const a=s.animals[0];a.clean=45.25;a.hunger=67.75;a.mood=51.125;a.position.inside={x:410.25,y:485.75};a.bond=34;R.rehome(s,a.id,true);const b=s.ranch.barns[R.species[type].home];
 if(variant==='missing')s.ranch.rehomed=[];
 if(variant==='unbuilt')b.built=false;
 if(variant==='full'||variant==='reserved'){b.space=0;const count=R.barns[R.species[type].home].base-(variant==='reserved'?1:0);for(let i=0;i<count;i++)R.buyAnimal(s,type,'female','local',false);if(variant==='reserved'){s.ranch.nextId=91;s.ranch.births.push({id:'birth-90',type,mother:null,father:null,breed,remaining:2,total:R.species[type].gestation});}}
 if(variant==='lost')s.ranch.rehomed[0].animal.lost=true;if(variant==='rest')s.ranch.rehomed[0].animal.rest=true;if(variant==='retired')s.ranch.rehomed[0].animal.retired=true;
 s.stamina=100;s.minutes=600.25;if(variant==='money')s.money=0;labor(s,variant);
 emit(s,{op:'adopt',id:type,animal:a.id,breed,sex,variant},s=>R.adopt(s,a.id));
}
function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(exact(r))).join('\n')+'\n');console.log('Ranch companion cases: '+rows.length);
