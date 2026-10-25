const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
function base(){const s=C.initial();s.day=10;s.minutes=600;s.scene='farm';s.player.x=2831;s.player.y=1652;s.upgrades.room=true;C.add(s,'greens',3);C.add(s,'eggRice',3);K.ensure(s);for(const id of ['greens','eggRice']){s.quality[id]=[1,1,0];s.kitchen.lots.bag[id]=[{qty:2,age:3},{qty:1,age:0}];}return s;}
function run(s,kind,id,dish,variant){const before=copy(s),result=kind==='host'?C.hostMeal(s,id,dish):C.sharedLife(s,id,dish);rows.push({kind,id,dish,variant,before,result,expected:{bag:s.bag,quality:s.quality,lots:s.kitchen.lots,marriage:s.marriage,relations:s.relations,seasonEvents:s.seasonEvents,skills:s.skills,recipes:s.knownRecipes,journal:s.journal,eventLog:s.eventLog,money:s.money,minutes:s.minutes}});}
for(const n of [...D.npcs,{id:'missing'}])for(const dish of ['greens','wood'])for(const variant of ['base','locked','empty','no-room','town','repeat','host','cap','known','full']){
 const s=base();if(variant==='locked')s.economy.locked=[dish];if(variant==='empty')C.consume(s,{greens:s.bag.greens});if(variant==='no-room')s.upgrades.room=false;if(variant==='town'){s.scene='town';s.player.y=500;}
 if(variant==='host')s.skills.cooking.choice='host';if(variant==='cap'&&s.relations[n.id]){s.relations[n.id].points=98;s.skills.social.xp=99998;}
 if(variant==='known')for(const r of D.recipes)if(r.source===n.id&&!s.knownRecipes.includes(r.id))s.knownRecipes.push(r.id);
 if(variant==='repeat')C.hostMeal(s,n.id,dish);
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 run(s,'host',n.id,dish,variant);
}
for(const n of D.npcs.filter(n=>n.tier==='romance'&&n.age>=18))for(const activity of ['meal','visit','objects','plan','missing'])for(const dish of ['greens','wood'])for(const variant of ['base','locked','empty','no-spouse','repeat','cap','memories','full','week']){
 const s=base();s.partners[n.id]="dating";s.stories[n.id]={step:4,choices:[0,0,0,0],lastDay:5};s.relations[n.id].points=70;s.marriage={spouse:n.id,day:5,weekly:{},memories:[]};if(variant==='locked')s.economy.locked=[dish];if(variant==='empty')C.consume(s,{greens:s.bag.greens});if(variant==='no-spouse')s.marriage.spouse=null;
 if(variant==='repeat')C.sharedLife(s,activity,dish);if(variant==='cap')s.relations[n.id].points=98;
 if(variant==='memories')s.marriage.memories=Array.from({length:80},()=>({day:5,activity:'visit'}));
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 if(variant==='week'){s.day=7;s.marriage.weekly['0-'+activity]=true;}
 run(s,'shared',activity,dish,variant);
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Household source cases: '+rows.length);
