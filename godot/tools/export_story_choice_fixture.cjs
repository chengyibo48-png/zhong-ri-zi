const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,N=ZRZNpc,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x));
const out=fs.openSync(process.argv[2],'w');let count=0;
function emit(s,id,choice,variant){const before=copy(s),ready=C.storyReady(s,id),result=C.storyChoice(s,id,choice);fs.writeSync(out,JSON.stringify({id,choice,variant,before,ready,result,loadedArchives:variant==='completed'?C.load(before).archives:null,expected:{bag:s.bag,quality:s.quality,lots:s.kitchen.lots,stories:s.stories,partners:s.partners,relations:s.relations,skills:s.skills,recipes:s.knownRecipes,archives:s.archives,discovered:s.discovered,journal:s.journal,eventLog:s.eventLog,people:s.neighbors.people[id],history:s.neighbors.history}})+'\n');count++;}
for(const n of D.npcs)for(let step=0;step<D.arcs[n.id].length;step++)for(const choice of [0,1])for(const variant of ['ready','locked','empty','low','repeat','far','full','known']){
 const s=C.initial();s.day=10;s.minutes=600;s.scene='farm';s.player.x=2831;s.player.y=1652;s.village.interior=null;s.village.npc[n.id]={x:2831,y:1652,room:null,direction:'down'};N.ensure(s);
 s.stories[n.id]={step,choices:Array(step).fill(0),lastDay:5};s.relations[n.id].points=100;
 const e=D.arcs[n.id][step];if(e.kind==='married'){s.partners[n.id]='dating';s.marriage={spouse:n.id,day:5,weekly:{},memories:[]};}
 for(const [id,qty] of Object.entries(e.needs||{})){C.add(s,id,qty+2);s.quality[id]=[1,1,0];if(D.items[id].fresh){K.ensure(s);s.kitchen.lots.bag[id]=[{qty:s.bag[id],age:2}];}}
 if(variant==='locked')s.economy.locked=Object.keys(e.needs||{});
 if(variant==='empty')for(const id of Object.keys(e.needs||{}))C.consume(s,{[id]:s.bag[id]});
 if(variant==='low')s.relations[n.id].points=Math.max(0,e.points-1);
 if(variant==='repeat')s.stories[n.id].lastDay=10;
 if(variant==='far')s.player.x-=200;
 if(variant==='known'){for(const r of D.recipes)if(r.source===n.id&&!s.knownRecipes.includes(r.id))s.knownRecipes.push(r.id);}
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));s.skills.social.xp=99998;s.neighbors.history=Array.from({length:160},(_,i)=>({id:n.id,key:'old-'+i,day:5,minute:600,text:'旧事'+i,category:'日常',emotion:'calm',choice:''}));s.neighbors.people[n.id].recent=Array.from({length:12},(_,i)=>'old-'+i);}
 K.ensure(s);emit(s,n.id,choice,variant);
}
for(const n of D.npcs){
 const s=C.initial();s.day=10;s.minutes=600;s.player.x=2831;s.player.y=1652;s.village.interior=null;s.village.npc[n.id]={x:2831,y:1652,room:null,direction:'down'};N.ensure(s);s.relations[n.id].points=100;K.ensure(s);emit(s,n.id,2,'invalid');
}
for(const n of D.npcs)for(const variant of ['completed',...(D.arcs[n.id].some(e=>e.kind==='married')?['unmarried']:[])]){
 const s=C.initial();s.day=10;s.minutes=600;s.player.x=2831;s.player.y=1652;s.village.interior=null;s.village.npc[n.id]={x:2831,y:1652,room:null,direction:'down'};N.ensure(s);K.ensure(s);s.relations[n.id].points=100;
 const step=variant==='completed'?D.arcs[n.id].length:D.arcs[n.id].findIndex(e=>e.kind==='married');
 s.stories[n.id]={step,choices:Array(step).fill(0),lastDay:5};emit(s,n.id,0,variant);
}
fs.closeSync(out);console.log('Story source cases: '+count);
