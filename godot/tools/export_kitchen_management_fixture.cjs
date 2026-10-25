const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x));
const path=process.argv[2];fs.writeFileSync(path,'');let count=0;const ui=[];
const foods=Object.keys(D.items).filter(id=>K.food(id)&&D.items[id].kind!=='料理');
function base(){const s=C.initial();s.day=10;s.minutes=600.125;s.stamina=100;s.money=1000;for(const id of Object.keys(D.items))s.bag[id]=20;for(const id of Object.keys(D.upgrades))s.upgrades[id]=true;s.knownRecipes=[];K.ensure(s);return s;}
function emit(s,op,id,second,variant){const before=copy(s),result=op==='experiment'?K.experiment(s,id,second):op==='cold'?K.cold(s):K.equipment(s,id,op);
const row={op,id,second,variant,before,result,expected:{bag:s.bag,quality:s.quality,kitchen:s.kitchen,skills:s.skills,flags:s.flags,journal:s.journal,eventLog:s.eventLog,minutes:s.minutes,stamina:s.stamina,money:s.money,knownRecipes:s.knownRecipes,stats:s.stats,upgrades:s.upgrades,discovered:s.discovered}};fs.appendFileSync(path,JSON.stringify(row)+'\n');if(op==='experiment'&&variant==='pair'&&[['wildHerb','shoot'],['wheat','tea']].some(p=>p.includes(id)&&p.includes(second)&&id!==second))ui.push(row);count++;}
for(let i=0;i<foods.length;i++)for(let j=i;j<foods.length;j++)emit(base(),'experiment',foods[i],foods[j],'pair');
const pairs=[['wildHerb','shoot'],['milk','egg'],['wheat','tea'],['milk','milk'],['cabbage','cabbage'],['berry','fish'],['missing','tea'],['greens','tea'],['wood','rice']];
for(const [first,second] of pairs)for(const variant of ['reverse','known','locked-first','locked-second','one','empty','energy','gentle','quality','stale','dirty','mastery-cap','threshold','repeat','full']){
 const s=base();if(variant==='known')s.knownRecipes=D.recipes.map(r=>r.id);
 if(variant==='locked-first')s.economy.locked=[first];if(variant==='locked-second')s.economy.locked=[second];
 if(variant==='one')s.bag[first]=1;if(variant==='empty'){s.bag={};K.ensure(s);}
 if(variant==='energy')s.stamina=0;if(variant==='gentle'){s.stamina=1;s.skills.farming.choice='gentle';}
 if(variant==='quality')for(const id of [first,second])if(D.items[id])s.quality[id]=[0,0,20];
 if(variant==='stale')for(const id of [first,second])if(K.food(id))s.kitchen.lots.bag[id]=[{qty:20,age:K.shelf(id)}];
 if(variant==='dirty')s.kitchen.equipment.stove.clean=29;
 if(variant==='mastery-cap')s.kitchen.mastery.gardenSoup=9999;
 if(variant==='threshold')s.stats.cooked=4;
 if(variant==='repeat'||variant==='full'){const signatures=[];for(let i=0;i<foods.length;i++)for(let j=i;j<foods.length;j++)signatures.push([foods[i],foods[j]].sort().join('+'));s.kitchen.experiments=variant==='full'?signatures.slice(0,40):[[first,second].sort().join('+')];if(!K.food(first)||!K.food(second))s.kitchen.experiments=[];}
 emit(s,'experiment',variant==='reverse'?second:first,variant==='reverse'?first:second,variant);
}
for(const id of [...Object.keys(K.stations),'missing'])for(const op of ['clean','upgrade'])for(const variant of ['ready','level1','level2','no-device','money','empty','locked-wood','locked-bamboo','quality','energy','gentle','fractional']){
 const s=base();if(K.stations[id]){s.kitchen.equipment[id].clean=variant==='ready'?100:40;if(variant==='level1')s.kitchen.equipment[id].level=1;if(variant==='level2')s.kitchen.equipment[id].level=2;}
 if(variant==='no-device')s.upgrades={};if(variant==='money')s.money=0;if(variant==='empty')s.bag={};
 if(variant==='locked-wood')s.economy.locked=['wood'];if(variant==='locked-bamboo')s.economy.locked=['bamboo'];
 if(variant==='quality'){s.quality.wood=[0,0,20];s.quality.bamboo=[0,0,20];}
 if(variant==='energy')s.stamina=0;if(variant==='gentle'){s.stamina=1;s.skills.farming.choice='gentle';}
 if(variant==='fractional')s.minutes=1319.9;K.ensure(s);emit(s,op,id,'',variant);
}
for(const variant of ['ready','already','money','empty','locked','quality','aged','storage-off']){
 const s=base();if(variant==='already')s.kitchen.cold=true;if(variant==='money')s.money=149;if(variant==='empty')s.bag.bamboo=5;if(variant==='locked')s.economy.locked=['bamboo'];if(variant==='quality')s.quality.bamboo=[0,0,20];
 if(variant==='aged'){s.storage.milk=3;K.ensure(s);s.kitchen.lots.storage.milk=[{qty:3,age:2.5}];}
 if(variant==='storage-off')s.upgrades.storage=false;emit(s,'cold','','',variant);
}
console.log('Kitchen management source cases: '+count+', foods: '+foods.length);

fs.writeFileSync(path+'.ui.json',JSON.stringify({rows:ui,house:K.house()}));
