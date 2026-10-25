const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),path=process.argv[2];fs.writeFileSync(path,'');let count=0;
const snapshot=s=>({day:s.day,minutes:s.minutes,stamina:s.stamina,bag:s.bag,quality:s.quality,kitchen:s.kitchen,processing:s.processing,stats:s.stats,journal:s.journal,eventLog:s.eventLog,discovered:s.discovered,flags:s.flags,letters:s.letters});
for(const day of Array.from({length:224},(_,i)=>i))for(const variant of ['base','cold','cap','legacy','legacy-grade','pending','modern']){
 const s=C.initial();s.day=day;s.minutes=1319.875;s.stamina=10;s.animals=[];
 for(const p of s.plots){p.crop=null;p.growth=0;}
 for(const id of Object.keys(D.items))if(K.food(id)){C.add(s,id,2);s.storage[id]=2;}
 K.ensure(s);s.kitchen.cold=variant==='cold';
 for(const side of ['bag','storage'])for(const lots of Object.values(s.kitchen.lots[side]))for(const l of lots)l.age=variant==='cap'?3649.875:2.375;
 if(['legacy','legacy-grade','pending'].includes(variant))s.processing=[
 {id:'pickles',qty:2,readyDay:day+1,station:'腌菜坛',cooking:true,...(variant==='legacy-grade'?{farmGrade:2}:{})},
 {id:'driedMushroom',qty:3,readyDay:day+(variant==='pending'?3:1),station:'晾晒架',cooking:false,...(variant==='legacy-grade'?{farmGrade:1}:{})},
 {id:'compost',qty:1,readyDay:day+1,station:'堆肥箱',cooking:false}];
 if(variant==='modern'){
  s.upgrades.mill=true;C.add(s,'wheat',3);K.start(s,'flour',1);
  s.kitchen.jobs.push({key:s.kitchen.nextId++,recipe:'driedMushroom',id:'driedMushroom',qty:1,station:'dry',start:K.now(s),ready:K.now(s)+2000,grade:1,cooking:false,weatherDelay:0});
 }
 const before=copy(s),result=C.nextDay(s),expected=copy(snapshot(s));
 const result2=C.nextDay(s),expected2=copy(snapshot(s));
 fs.appendFileSync(path,JSON.stringify({day,variant,before,steps:[{result,expected},{result:result2,expected:expected2}]})+'\n');count++;
}
console.log('Kitchen overnight cases: '+count+', actual day transitions: '+count*2);
