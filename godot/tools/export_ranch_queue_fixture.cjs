const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','ranch-view'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,s=C.initial();R.ensure(s);
const plans=[];
for(const action of ['feed','collect','clean','treat','pet','rest'])for(const ids of [s.animals.map(a=>a.id),['missing'],[s.animals[0].id,s.animals[0].id]]){
 plans.push({action,ids,tasks:R.plan(s,ids,action)});
}
const transactions=[];
for(const action of ['feed','collect','pet','clean','treat','vet','rest','rescue'])for(const mode of ['normal','care','broad','no-energy','efficient']){
 const x=C.initial();R.ensure(x);const a=x.animals[0];
 Object.assign(a,{hunger:20,health:50,illness:30,clean:20,mood:40,bond:20,stress:30,lost:true});
 Object.assign(a.care,{feed:-1,pet:-1,clean:-1,treat:-1});
 Object.assign(x.toolkit.tools.care,{level:['normal','efficient'].includes(mode)?0:2,branch:mode==='care'?'care':'broad'});
 x.bag.feed=20;x.bag.animalMedicine=2;
 if(mode==='efficient')x.ranch.barns[R.species[a.type].home].efficiency=1;
 if(mode==='no-energy')x.stamina=0;
 const task={animalId:a.id,action,arg:'feed'};
 const before=JSON.parse(JSON.stringify(x)),result=R.perform(x,task);
 transactions.push({before,task,result,expected:{stamina:x.stamina,minutes:x.minutes,money:x.money,animal:Object.fromEntries(['hunger','health','illness','clean','mood','bond','stress','lost','rest','ready','feathers','qualityStock','feedQuality','care'].map(k=>[k,a[k]])),bag:{feed:x.bag.feed,animalMedicine:x.bag.animalMedicine,egg:x.bag.egg,feather:x.bag.feather||0},quality:x.quality.egg||[0,0,0],collection:x.ranch.collection}});
}
const filters=['all','ready','care','hen','duck','cow','sheep','pig'].map(filter=>({filter,ids:s.animals.filter(a=>filter==='all'||a.type===filter||filter==='ready'&&(a.ready||a.feathers)||filter==='care'&&(a.hunger<40||a.illness>=20||a.clean<45||a.lost)).map(a=>a.id)}));
fs.writeFileSync(process.argv[2],JSON.stringify({source:s,plans,transactions,filters},null,2));
console.log('Exported '+plans.length+' ranch plans and '+transactions.length+' original transactions');
