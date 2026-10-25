const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
function snapshot(s){return {bag:s.bag,quality:s.quality,kitchen:s.kitchen,skills:s.skills,flags:s.flags,journal:s.journal,eventLog:s.eventLog,minutes:s.minutes,stamina:s.stamina,money:s.money,knownRecipes:s.knownRecipes,stats:s.stats};}
const variants=['ready','manual-low','manual-min','manual-max','manual-high','quality','stale','dirty','level2','mastery','cap','threshold','above-threshold','batch','energy','locked','empty','unknown','no-device','season','fractional','substitute','invalid-negative','invalid-high','zero-heat','max-heat'];
for(const r of D.recipes.filter(r=>!['腌菜坛','晾晒架'].includes(r.station)))for(const variant of variants){
 const s=C.initial();s.day=10;s.minutes=600.125;s.stamina=100;s.money=1000;
 for(const id of Object.keys(D.upgrades))s.upgrades[id]=true;
 for(const id of Object.keys(D.items))s.bag[id]=100;
 s.knownRecipes=D.recipes.map(r=>r.id);K.ensure(s);
 let n=1,heat=null,sub=false;const station=K.stationFor(r.station);
 if(variant==='invalid-negative')heat=-0.1;if(variant==='invalid-high')heat=100.001;if(variant==='zero-heat')heat=0;if(variant==='max-heat')heat=100;
 if(variant==='manual-low')heat=34.999;if(variant==='manual-min')heat=35;if(variant==='manual-max')heat=75;if(variant==='manual-high')heat=75.001;
 if(variant==='quality')for(const id of Object.keys(r.ingredients))s.quality[id]=[0,0,100];
 if(variant==='stale')for(const id of Object.keys(r.ingredients))if(K.food(id))s.kitchen.lots.bag[id]=[{qty:100,age:K.shelf(id)}];
 if(variant==='dirty')s.kitchen.equipment[station].clean=29;
 if(variant==='level2')s.kitchen.equipment[station].level=2;
 if(variant==='mastery')s.kitchen.mastery[r.id]=9998;
 if(variant==='cap')s.skills.cooking.xp=99998;
 if(variant==='threshold'||variant==='above-threshold'){s.stats.cooked=variant==='threshold'?4:30;s.knownRecipes=[r.id];}
 if(variant==='batch')n=20;
 if(variant==='energy')s.stamina=0;
 if(variant==='locked')s.economy.locked=Object.keys(r.ingredients);
 if(variant==='empty'){s.bag={};K.ensure(s);}
 if(variant==='unknown')s.knownRecipes=[];
 if(variant==='no-device')s.upgrades={};
 if(variant==='season')s.day=38;
 if(variant==='fractional')n=1.5;
 if(variant==='substitute'){sub=true;for(const id of ['cabbage','egg','fish','mushroom','rice','bean'])s.bag[id]=0;K.ensure(s);}
 const before=copy(s),result=K.make(s,r.id,n,sub,heat);
 rows.push({op:'cook',id:r.id,n,heat,sub,variant,before,result,expected:snapshot(s)});
}
for(const r of [...K.processing,...D.recipes.filter(r=>['腌菜坛','晾晒架'].includes(r.station))])for(const variant of ['ready','early','missing','threshold','already-known']){
 const s=C.initial();s.day=10;s.minutes=600.125;s.stamina=100;
 for(const id of Object.keys(D.items))s.bag[id]=10;K.ensure(s);
 s.stats.cooked=4;s.knownRecipes=variant==='already-known'?D.recipes.map(x=>x.id):[];
 const cooking=!r.stationId;
 s.kitchen.jobs=[{key:3,recipe:r.id,id:r.out||r.id,qty:2,station:r.stationId||K.stationFor(r.station),start:K.now(s)-10,ready:K.now(s)+(variant==='early'?0.001:0),grade:2,cooking,weatherDelay:0}];
 const before=copy(s),key=variant==='missing'?99:3,result=K.collect(s,key);
 rows.push({op:'collect',id:r.id,key,variant,before,result,expected:snapshot(s)});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Cooking source cases: '+rows.length);
