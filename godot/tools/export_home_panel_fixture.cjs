const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','kitchen-view','building','tools','economy','scenes','environment','forage','interiors'])require('../../src/'+name+'.js');
const C=ZRZCore,K=ZRZKitchen,rows=[];
function fresh(){const s=C.initial();s.day=10;s.minutes=600;s.scene='farm';s.upgrades.room=true;s.bag={greens:3,rice:2};s.quality={greens:[1,1,0]};s.partners.qiao='dating';s.stories.qiao={step:4,choices:[0,0,0,0],lastDay:9};s.marriage={spouse:'qiao',day:5,weekly:{},memories:[]};s.relations.qiao.points=70;s.relations.granny.points=30;K.ensure(s);s.kitchen.lots.bag.greens=[{qty:2,age:3},{qty:1,age:0}];return s;}
for(const op of ['host','meal','visit','objects','plan','pet'])for(const variant of ['normal','locked','no-dish','no-room','town','pasture','repeated','full-bond','no-spouse','memories-cap']){
const s=fresh();if(variant==='locked')s.economy.locked=['greens'];if(variant==='no-dish'){s.bag={rice:2};s.quality={};K.ensure(s);}if(variant==='no-room')s.upgrades.room=false;if(variant==='town')s.scene='town';if(variant==='pasture')s.scene='farm';if(variant==='full-bond'){s.relations.qiao.points=100;s.pet.bond=100;s.ranch.pet.energy=100;}if(variant==='no-spouse')s.marriage={spouse:null,day:-1,weekly:{},memories:[]};if(variant==='memories-cap')s.marriage.memories=Array.from({length:80},()=>({day:5,activity:'visit'}));
const run=()=>op==='host'?C.hostMeal(s,'granny','greens'):op==='pet'?C.pet(s):C.sharedLife(s,op,'greens');
if(variant==='repeated')run();const before=JSON.parse(JSON.stringify(s)),result=run();
rows.push({op,variant,before,ok:result.ok,expected:{bag:s.bag,quality:s.quality,lots:s.kitchen.lots,marriage:s.marriage,relations:s.relations,seasonEvents:s.seasonEvents,skills:s.skills,recipes:s.knownRecipes,pet:s.pet,ranchPet:s.ranch.pet}});
}
const names=['春团','  小白  ','   ','abcdefghijklmnop'];
const rename=names.map(name=>({name,type:'dog',expected:(name||'小团').trim().slice(0,12)||'小团'}));
fs.writeFileSync(process.argv[2],JSON.stringify({source:fresh(),rows,rename},null,2));console.log('Exported '+rows.length+' full-module home transactions and '+rename.length+' pet names');
