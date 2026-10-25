const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>Object.fromEntries(['day','minutes','stamina','money','kitchen','skills','stats','journal','eventLog','discovered','flags','bag','quality','knownRecipes','ranch','animals','pet','processing','toolkit','storage','storageQuality','upgrades'].map(k=>[k,s[k]]));
function fresh(){const s=C.initial();s.day=27;s.minutes=600.25;s.money=100000;for(const b of Object.values(s.ranch.barns)){b.built=true;b.space=1;b.comfort=1;}return s;}
function emit(s,row,operation){K.ensure(s);const before=copy(s);s=C.load(before);const result=operation(s),expected=copy(snapshot(s)),steps=[];if(row.variant==="normal"&&result.ok)for(let i=0;i<2;i++){const result=C.nextDay(s);steps.push({result,expected:copy(snapshot(s))});}rows.push({...row,before,result,expected,steps});}
for(const t of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const sex of ['female','male'])for(const young of [true,false])for(const variant of ['normal','money','low','gentle','labor','buff','unbuilt','full','reserved']){
 const s=fresh(),b=s.ranch.barns[R.species[t].home];
 if(variant==='money')s.money=0;if(variant==='low')s.stamina=0;
 if(variant==='gentle'){s.stamina=1;s.skills.farming.choice='gentle';}if(variant==='labor'){s.stamina=1;s.buffs.laborDay=s.day;}
 if(variant==='buff'){s.stamina=1;s.kitchen.buff={kind:'暖胃',until:s.day*1440+s.minutes+180};}
 if(variant==='unbuilt')b.built=false;
 if(variant==='full'||variant==='reserved'){s.animals=[];b.space=0;const count=R.barns[R.species[t].home].base-(variant==='reserved'?1:0);for(let i=0;i<count;i++){const out=R.buyAnimal(s,t,'female',breed,false);if(!out.ok)throw Error(out.msg);}if(variant==='reserved'){s.ranch.nextId=91;s.ranch.births.push({id:'birth-90',type:t,mother:null,father:null,breed,remaining:1,total:R.species[t].gestation});}}
 emit(s,{op:'buy',id:t,variant,breed,sex,young},s=>R.buyAnimal(s,t,sex,breed,young));
}
for(const [t,sex,breed]of [['missing','female','local'],['hen','invalid','local'],['hen','female','invalid']])emit(fresh(),{op:'buy',id:t,variant:'invalid',sex,breed,young:true},s=>R.buyAnimal(s,t,sex,breed,true));
const breedVariants=['normal','missing-mother','missing-father','same','sex','young','retired','health','hunger','mood','illness','lost','pending','recent','space','dirty','missing','locked','low','money','premium','mixed','gentle','labor'];
for(const t of Object.keys(R.species))for(const [mb,fb]of [['local','local'],['productive','hardy'],['hardy','productive']])for(const variant of breedVariants){
 const s=fresh();s.animals=[];R.buyAnimal(s,t,'female',mb,false);R.buyAnimal(s,t,'male',fb,false);
 const m=s.animals[0],f=s.animals[1],b=s.ranch.barns[R.species[t].home];let mother=m.id,father=f.id;
 s.bag.grainFeed=2;
 if(variant==='missing-mother')mother='missing';if(variant==='missing-father')father='missing';if(variant==='same')father=mother;if(variant==='sex')f.sex='female';
 if(variant==='young')m.age=0;if(variant==='retired')m.retired=true;
 if(variant==='health')m.health=69.75;if(variant==='hunger')m.hunger=54.75;if(variant==='mood')m.mood=49.75;if(variant==='illness')m.illness=10.5;if(variant==='lost')m.lost=true;
 if(variant==='pending'){s.ranch.nextId=91;s.ranch.births.push({id:'birth-90',type:t,mother:m.id,father:f.id,breed:mb,remaining:1,total:R.species[t].gestation});}
 if(variant==='recent')m.care.breed=s.day-11;
 if(variant==='space'){b.space=0;while(s.animals.length<R.barns[R.species[t].home].base)R.buyAnimal(s,t,'female','local',false);}
 if(variant==='dirty')b.clean=49.75;
 if(variant==='missing')s.bag.grainFeed=1;if(variant==='locked')s.economy.locked=['grainFeed'];if(variant==='low')s.stamina=0;if(variant==='money')s.money=19;
 if(variant==='premium')s.quality.grainFeed=[2,0,0];if(variant==='mixed')s.quality.grainFeed=[0,1,0];
 if(variant==='gentle'){s.stamina=2;s.skills.farming.choice='gentle';}if(variant==='labor'){s.stamina=2;s.buffs.laborDay=s.day;}
 emit(s,{op:'breed',id:t,variant,mb,fb,mother,father},s=>R.breed(s,mother,father));
}
for(const t of ['hen','duck'])for(const variant of ['normal','comfort','unbuilt','space','missing','ordinary','locked','low','gentle','premium','mixed','late']){
 const s=fresh(),b=s.ranch.barns.poultry,id=t==='hen'?'fertileHenEgg':'fertileDuckEgg';s.bag[id]=1;
 if(variant==='comfort')b.comfort=0;if(variant==='unbuilt')b.built=false;
 if(variant==='space'){b.space=0;while(R.residents(s,'poultry').length<R.barns.poultry.base)R.buyAnimal(s,'hen','female','local',false);}
 if(variant==='missing'||variant==='ordinary')delete s.bag[id];if(variant==='ordinary')s.bag.egg=10;
 if(variant==='locked')s.economy.locked=[id];if(variant==='low')s.stamina=0;if(variant==='gentle'){s.stamina=1;s.skills.farming.choice='gentle';}
 if(variant==='premium')s.quality[id]=[1,0,0];if(variant==='mixed'){s.bag[id]=2;s.quality[id]=[0,1,0];}if(variant==='late')s.minutes=1319.875;
 emit(s,{op:'incubate',id:t,variant},s=>R.incubate(s,t));
}
for(const t of ['cow','sheep','missing'])emit(fresh(),{op:'incubate',id:t,variant:'invalid'},s=>R.incubate(s,t));
for(const row of rows){
 if(row.variant!=='normal')continue;
 const chosen=row.op==='buy'&&row.breed==='local'&&row.sex==='female'&&row.young||row.op==='breed'&&row.id==='cow'&&row.mb==='productive'&&row.fb==='hardy'||row.op==='incubate';
 if(!chosen)continue;
 const probe=copy(row.before),barn=row.op==='incubate'?'poultry':R.species[row.id].home;
 probe.village.interior=R.barns[barn].house;probe.player={x:480,y:510,direction:'down'};
 const stand=ZRZActions.approach(probe,{kind:'ranch-task',x:480,y:490});
 row.insideRoute={stand,reachable:ZRZVillage.route(probe,stand.x,stand.y).length>0};
}
function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(exact(r))).join('\n')+'\n');console.log('Ranch family cases: '+rows.length);
