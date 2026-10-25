const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback'])require('../../src/'+name+'.js');
const rows=[],finishes=[];
const catalog={items:ZRZData.items,npc_names:Object.fromEntries(ZRZData.npcs.map(n=>[n.id,n.name])),fishing:{species:ZRZFishing.species},kitchen:{stations:ZRZKitchen.stations},building:{projects:ZRZBuild.projects},tools:{defs:ZRZTools.defs}};
for(let mask=0;mask<256;mask++){
 const s=ZRZCore.initial();ZRZNpc.ensure(s);s.minutes=600.75;
 const point={kind:mask%2?'farm-task':'animal',index:0,animalId:s.animals[0].id,x:mask%3?123:0,y:456};
 const spec={kind:'care',label:mask%5?'照料完成':''};
 s.feedback.days=Array.from({length:7},(_,i)=>({day:i,actions:2,income:5,spent:3,items:{}}));s.day=7;
 s.feedback.prefs.floating=['normal','compact','off'][mask%3];
 if(mask&32 && mask&2){const id=Object.keys(ZRZFishing.species)[0];s.fishing.records[id]={count:1,best:mask&4?20:12};s.fishing.last={fish:id,length:12,grade:0,released:false};}
 const before=ZRZFeedback.snapshot(s,point),initial=structuredClone(s);
 if(mask&1){s.bag.cabbage=(s.bag.cabbage||0)+2;s.money+=9;}
 if(mask&2){s.farm.beds[0].moisture+=2;s.stamina-=.35;}
 if(mask&4){s.relations[ZRZData.npcs[0].id].points=10;s.neighbors.people[ZRZData.npcs[0].id].event={status:'accepted',day:7};}
 if(mask&8){s.kitchen.jobs.push({key:'k',id:'pickles',station:'pickle',qty:2,grade:0,ready:10800});s.economy.jobs.push({key:'t',id:'cabbage',qty:3,price:27,channel:mask%2?'coop':'stall',ready:11000});}
 if(mask&16){s.economy.claimed.push('spring-1');s.building.jobs.push({id:'house',level:1,readyDay:8});s.toolkit.tools.hoe.level+=1;}
 if(mask&32){const id=Object.keys(ZRZFishing.species)[0];s.fishing.records[id]={count:(s.fishing.records[id]?.count||0)+1,best:Math.max(s.fishing.records[id]?.best||0,14)};s.fishing.last={fish:id,length:14,grade:1,released:!!(mask&1)};}
 if(mask&128){s.bag.cabbage=(s.bag.cabbage||0)+1;s.quality.cabbage||=[0,0,0];s.quality.cabbage[2]+=1;}
 if(mask&64){s.fishing.waters.test={day:7,casts:1};if(!(mask&32))s.fishing.last={fish:null,reason:'线断了'};}
 const runtime=ZRZFeedback.runtime(s);runtime.clock=1.25;
 runtime.floats=[{key:'cabbage:0',item:'cabbage',grade:0,qty:5,at:mask%2?0:-4,x:22,y:33},{key:'result',text:'旧结果',at:0,x:22,y:33}];
 const state=structuredClone(s),oldRuntime=structuredClone(runtime);
 const result=ZRZFeedback.finish(s,before,point,spec);
 finishes.push({mask,before,point,spec,state,oldRuntime,result,feedback:structuredClone(s.feedback),runtime:structuredClone(runtime)});
}

for(let mask=0;mask<64;mask++){
 const s=ZRZCore.initial();ZRZNpc.ensure(s);
 s.bag={cabbage:5,egg:3};s.storage={cabbage:4};s.quality={cabbage:[1,1,1]};s.storageQuality={cabbage:[0,2,0]};
 s.minutes=600.75;s.stamina=73.75;
 const point=[{}, {kind:'plot',index:0},{kind:'farm-task',index:0},{kind:'animal',id:s.animals[0].id},{kind:'ranch',animalId:s.animals[0].id},{kind:'plot',index:0,animalId:s.animals[0].id},{kind:'plot',index:-1},{kind:'plot',index:0.5}][mask%8];
 s.farm.beds[0].moisture=24.5;s.animals[0].hunger=31.5;
 const original=structuredClone(s),before=ZRZFeedback.snapshot(s,point);
 if(mask&1){s.bag.cabbage+=2;s.quality.cabbage[2]+=1;s.bag.egg-=1;s.bag.radish=2;}
 if(mask&2){s.bag.cabbage-=1;s.storage.cabbage+=1;}
 if(mask&4){s.money-=9;s.stamina-=.35;s.relations[ZRZData.npcs[0].id].points+=4;}
 if(mask&8){s.farm.beds[0].moisture+=3.1;s.farm.beds[1].health-=7;s.animals[0].hunger+=2.1;s.animals[1].mood+=4;}
 if(mask&16){s.fishing.waters.test={day:s.day,casts:3};s.fishing.waters.old={day:s.day-1,casts:7};s.neighbors.people[ZRZData.npcs[0].id].event={status:'accepted',day:s.day};}
 if(mask&32){s.stamina+=.1;s.farm.beds[0].fertility-=.5;}
 const after=ZRZFeedback.snapshot(s,point),delta=ZRZFeedback.difference(before,after);
 rows.push({mask,point,original,state:structuredClone(s),before,after,delta,description:ZRZFeedback.describeDelta(delta)});
}
require('../../src/feedback-view.js');
const clocks=[];
for(const room of [undefined,'','home-granny'])for(const next of ['','home-granny'])for(const dt of [-1,0,.04,.1,10]){
 const s=ZRZCore.initial();s.village.interior=next;s.feedback.prefs.floating='off';
 const r=ZRZFeedback.runtime(s);r.clock=4.4;r.floats=[{key:'a',text:'test',at:0,x:10,y:20},{key:'b',text:'test',at:4,x:10,y:20}];if(room!==undefined)r.room=room;
 const initial=structuredClone(r);ZRZFeedback.draw({save(){},translate(){},restore(){}},s,dt,null,'hand',{x:0,y:0,viewWidth:960});
 clocks.push({initial,room:next,dt,expected:structuredClone(r)});
}
const edges=[-.05,-.15,.05,.15,-.25,0.25,-.04,.04];
for(const stamina of edges){const delta={items:[],money:0,relations:[],fields:[],stamina};rows.push({rounding:true,delta,description:ZRZFeedback.describeDelta(delta)});}
fs.writeFileSync(process.argv[2],JSON.stringify({rows,finishes,clocks,catalog,names:Object.fromEntries(ZRZData.npcs.map(n=>[n.id,n.name])),items:ZRZData.items}));
console.log('Actual source feedback snapshots and deltas '+rows.length);
