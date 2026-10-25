const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools'])require('../../src/'+name+'.js');
const C=ZRZCore,F=ZRZFarming,T=ZRZTools,D=ZRZData,s=C.initial();
F.ensure(s);
s.plots.forEach((p,i)=>{
 p.tilled=i%5!==0;p.crop=i%3===0?'cabbage':i%3===1?'radish':null;p.growth=p.crop?(i%2===0?D.crops[p.crop].days:0):0;
 const b=s.farm.beds[i];b.moisture=i%4===0?0:i%4===1?100:45;b.fertility=(i%4)*25;b.compacted=i%2*30;b.removed=i%11===0;b.fertilized=i%7===0?s.day:-1;b.health=i%13===0?20:100;b.pests=i%9===0?20:0;b.disease=i%10===0?20:0;
});
const ranges=[];
for(const tool of ['hoe','water','sickle'])for(const config of [{level:0,shape:'row',branch:'broad'},{level:1,shape:'row',branch:'broad'},{level:2,shape:'cross',branch:'broad'},{level:2,shape:'cross',branch:'care'}])for(const index of [0,5,6,23,24,35,36,71]){
 Object.assign(s.toolkit.tools[tool],config);
 ranges.push({tool,config,index,tasks:T.plan(s,index,tool)});
}
const filters=[];
for(const filter of ['all','ready','dry','risk','empty'])for(const region of ['all','home','slope'])for(const crop of ['all','cabbage','radish']){
 const indices=F.list(s,filter,region,crop);
 filters.push({filter,region,crop,indices,plans:Object.fromEntries(['water','fertilize','sow','harvest'].map(action=>[action,F.plan(s,indices,action)]))});
}
// Export valid toolkit state through the original save entry; range cases supply their own configuration.
for(const tool of ['hoe','water','sickle'])Object.assign(s.toolkit.tools[tool],{level:2,shape:'row',branch:'care'});
const source=JSON.parse(JSON.stringify(s));
const transactions=['restore','sow','water','fertilize','harvest','deep'].map(action=>{
 const x=C.initial();F.ensure(x);
 const p=x.plots[0],bed=x.farm.beds[0];
 p.crop=['water','fertilize','harvest'].includes(action)?'cabbage':null;p.tilled=action!=='restore';p.growth=action==='harvest'?D.crops.cabbage.days:0;
 Object.assign(bed,{fertility:50,moisture:10,compacted:30,removed:false,fallow:false,health:100,condition:75,kind:'normal',density:'balanced',companion:null});
 x.bag.compost=4;x.bag.cabbageSeed=4;
 if(action==='deep')Object.assign(x.toolkit.tools.hoe,{level:2,branch:'care',shape:'row'});
 const before=JSON.parse(JSON.stringify(x));
 const task={index:0,action};
 const result=F.perform(x,0,action);
 return {before,task,result,stamina:x.stamina,minutes:x.minutes,tilled:p.tilled,crop:p.crop,growth:p.growth,bed:{fertility:bed.fertility,moisture:bed.moisture,compacted:bed.compacted},bag:{cabbage:x.bag.cabbage||0,cabbageSeed:x.bag.cabbageSeed||0,compost:x.bag.compost||0},quality:x.quality.cabbage||[0,0,0]};
});

const specialTransactions=[];
const snapshot=x=>{
 const p=x.plots[0],b=x.farm.beds[0];
 return {stamina:x.stamina,minutes:x.minutes,money:x.money,harvested:x.stats.harvested,
  plot:{crop:p.crop||'',growth:p.growth,tilled:p.tilled,repeats:p.repeats,last_group:p.lastGroup||'',
   soil_type:b.type,fertility:b.fertility,moisture:b.moisture,health:b.health,pests:b.pests,disease:b.disease,weeds:b.weeds,compacted:b.compacted,fallow:b.fallow,removed:b.removed,slow:b.slow,fertilized:b.fertilized,treated:b.treated,penalty:b.penalty,seed_kind:b.kind,density:b.density,ripe_days:b.ripeDays,ticks:b.ticks,
   companion:b.companion||{}},
  bag:Object.fromEntries(['compost','slowFertilizer','beanSeed','bioCare','plantCare','cabbageSeed','radishSeed','cabbage','radish'].map(id=>[id,x.bag[id]||0])),
  quality:Object.fromEntries(['cabbage','radish'].map(id=>[id,x.quality[id]||[0,0,0]]))};
};
for(const action of ['drain','slow','green','weed','manual','bio','agent','deep','fallow','remove','soil','companion','companionHarvest','seedSave']){
 for(const variant of ['valid','untilled','no-energy','occupied']){
  const x=C.initial();F.ensure(x);
  const p=x.plots[0],b=x.farm.beds[0];
  p.tilled=true;p.crop=['drain','manual','bio','agent','seedSave','companion','companionHarvest'].includes(action)?'cabbage':null;
  p.growth=p.crop?D.crops.cabbage.days:0;
  Object.assign(b,{type:'humus',fertility:50,moisture:90,health:80,pests:50,disease:50,weeds:40,compacted:30,fallow:true,removed:false,slow:0,fertilized:-1,treated:-1,condition:90,penalty:0,kind:'normal',density:'balanced',ripeDays:5,ticks:3,companion:action==='companionHarvest'?{crop:'radish',growth:D.crops.radish.days,kind:'heirloom'}:null});
  x.seed='radish';x.farm.seedKind='normal';x.farm.density='balanced';
  for(const id of ['compost','slowFertilizer','beanSeed','bioCare','plantCare','radishSeed'])x.bag[id]=5;
  if(variant==='untilled')p.tilled=false;
  if(variant==='no-energy')x.stamina=0;
  if(variant==='occupied')p.crop='cabbage';
  const arg=action==='soil'?'sand':action==='companion'?{crop:'radish',kind:'normal',density:'balanced'}:undefined;
  const before=JSON.parse(JSON.stringify(x));
  const result=F.perform(x,0,action,arg);
  specialTransactions.push({before,task:{index:0,action,arg:arg===undefined?{}:arg},result,expected:snapshot(x)});
 }
}
fs.writeFileSync(process.argv[2],JSON.stringify({source,ranges,filters,transactions,specialTransactions},null,2));
console.log('Exported '+ranges.length+' tool plans, '+filters.length+' filters and '+filters.length*4+' batches from '+s.plots.length+' plots');
