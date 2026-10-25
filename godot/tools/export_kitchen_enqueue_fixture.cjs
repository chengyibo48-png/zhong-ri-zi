const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const specs=[...K.processing.map(r=>({op:'process',id:r.id})),...D.recipes.filter(r=>['腌菜坛','晾晒架'].includes(r.station)).map(r=>({op:'cook',id:r.id}))];
for(const spec of specs)for(const variant of ['ready','no-device','unknown','empty','locked','energy','gentle','quality','stale','host-stale','level2','full','queued','cap','zero','six','fifteen','sixteen','fractional','half','text','null','boolean']){
 const s=C.initial();s.day=10;s.minutes=600;s.stamina=100;s.money=1000;
 for(const id of Object.keys(D.upgrades))s.upgrades[id]=true;
 for(const id of Object.keys(D.items))s.bag[id]=30;
 s.knownRecipes=D.recipes.map(r=>r.id);K.ensure(s);
 const recipe=spec.op==='process'?K.processing.find(r=>r.id===spec.id):D.recipes.find(r=>r.id===spec.id);
 const station=spec.op==='process'?recipe.stationId:K.stationFor(recipe.station),needs=recipe.needs||recipe.ingredients;
 let n=1;
 if(variant==='no-device')s.upgrades={};
 if(variant==='unknown')s.knownRecipes=[];
 if(variant==='empty'){s.bag={};K.ensure(s);}
 if(variant==='locked')s.economy.locked=Object.keys(needs);
 if(variant==='energy')s.stamina=0;
 if(variant==='gentle'){s.skills.farming.choice='gentle';s.stamina=1;}
 if(variant==='quality')for(const id of Object.keys(needs))s.quality[id]=[0,0,30];
 if(variant==='stale'||variant==='host-stale'){for(const id of Object.keys(needs))if(K.food(id))s.kitchen.lots.bag[id]=[{qty:30,age:K.shelf(id)}];if(variant==='host-stale')s.skills.cooking.choice='host';}
 if(variant==='level2')s.kitchen.equipment[station].level=2;
 if(variant==='full'||variant==='queued'){const count=variant==='full'?2:1;for(let i=0;i<count;i++)s.kitchen.jobs.push({key:s.kitchen.nextId++,recipe:spec.id,id:recipe.out||spec.id,qty:1,station,start:K.now(s),ready:K.now(s)+100+i*100,grade:0,cooking:spec.op==='cook',weatherDelay:0});}
 if(variant==='cap')s.skills[spec.op==='cook'?'cooking':'craft'].xp=99998;
 if(variant==='zero')n=0;if(variant==='six')n=6;if(variant==='fifteen'){n=15;s.kitchen.equipment[station].level=2;}if(variant==='sixteen'){n=16;s.kitchen.equipment[station].level=2;}
 if(variant==='fractional')s.minutes=600.125;
 if(variant==='half')n=1.5;if(variant==='text')n='1';if(variant==='null')n=null;if(variant==='boolean')n=true;
 const before=copy(s),result=spec.op==='process'?K.start(s,spec.id,n):K.make(s,spec.id,n);
 rows.push({spec,n,variant,before,result,expected:{bag:s.bag,quality:s.quality,kitchen:s.kitchen,skills:s.skills,flags:s.flags,journal:s.journal,eventLog:s.eventLog,minutes:s.minutes,stamina:s.stamina,money:s.money}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Enqueue source cases: '+rows.length+', recipes: '+specs.length);
