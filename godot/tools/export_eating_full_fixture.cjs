const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),path=process.argv[2];fs.writeFileSync(path,'');let count=0;
const variants=['fresh','aged','stale','quality1','quality2','quality3','mixed','home','full','missing','locked','locked-full','locked-missing','cap','oldest','buff-before','buff-exact','buff-after','fractional'];
for(const id of [...Object.keys(D.items),'missing'])for(const variant of [...variants,...(D.items[id]?.energy>0?['aged-q1','aged-q2','aged-q3','stale-q1','stale-q2','stale-q3','oldest-q1','oldest-q2','oldest-q3']:[])]){
 const s=C.initial();s.day=10;s.minutes=650.125;s.stamina=20;if(D.items[id])C.add(s,id,3);K.ensure(s);
 if(variant==='aged'||variant==='home'||variant.startsWith('aged-'))for(const lot of s.kitchen.lots.bag[id]||[])lot.age=K.shelf(id)*.6;
 if(variant==='stale'||variant.startsWith('stale-'))for(const lot of s.kitchen.lots.bag[id]||[])lot.age=K.shelf(id);
 if(variant.startsWith('quality'))s.quality[id]=[0,0,0].map((v,i)=>i===Number(variant.slice(-1))-1?(s.bag[id]||0):0);
 if(variant.includes('-q'))s.quality[id]=[0,0,0].map((v,i)=>i===Number(variant.slice(-1))-1?(s.bag[id]||0):0);
 if(variant==='mixed'&&(s.bag[id]||0)>=3)s.quality[id]=[1,1,1];
 if(variant==='home')s.skills.cooking.choice='home';
 if(variant==='full'||variant==='locked-full')s.stamina=100;
 if(variant==='cap')s.stamina=99;
 if(variant==='missing'||variant==='locked-missing'){if(s.bag[id])C.consume(s,{[id]:s.bag[id]});}
 if(variant.startsWith('locked')&&D.items[id])s.economy.locked=[id];
 if(variant.startsWith('oldest')&&K.food(id)){const n=s.bag[id];s.kitchen.lots.bag[id]=[{qty:1,age:K.shelf(id)},{qty:n-1,age:0}];}
 s.buffs.laborDay=10;s.kitchen.buff={kind:'暖胃',until:K.now(s)+180};
 if(variant==='buff-before')s.kitchen.buff.until=K.now(s)-.001;if(variant==='buff-exact')s.kitchen.buff.until=K.now(s);if(variant==='buff-after')s.kitchen.buff.until=K.now(s)+.001;
 if(variant==='fractional')s.minutes=1319.999;
 // Unknown item has no invalid quality field in a source save.
 if(!D.items[id])delete s.quality[id];
 const before=copy(s),result=C.eat(s,id);
 const row={id,variant,before,result,expected:{bag:s.bag,quality:s.quality,kitchen:s.kitchen,skills:s.skills,flags:s.flags,journal:s.journal,eventLog:s.eventLog,minutes:s.minutes,stamina:s.stamina,money:s.money,knownRecipes:s.knownRecipes,stats:s.stats,upgrades:s.upgrades,discovered:s.discovered,buffs:s.buffs,activeBuff:K.activeBuff(s)}};
 fs.appendFileSync(path,JSON.stringify(row)+'\n');count++;
}
console.log('Full eating source cases: '+count);
