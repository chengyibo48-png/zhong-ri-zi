const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,F=ZRZFishing,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
function snapshot(){const g=F.current();return g?copy(Object.fromEntries(['p','plan','time','tension','progress','holding','hooked','missed','caught','safe','total'].map(k=>[k,g[k]]))):{};}
function run(spot,day,rod,branch,mode,release,bait='plain',count=0,policy='safe',mutate=''){
 const s=C.initial();s.day=day;s.minutes=450;s.stamina=80;s.fishing.mode=mode;s.fishing.bait=bait;s.fishing.release=release;s.fishing.waters[spot.water]={day,casts:count};
 s.toolkit.tools.rod={level:rod,xp:7,branch,shape:'single'};s.toolUpgrades.rod=rod>0;
 for(const id of ['rice','wildHerb','shrimp'])C.add(s,id,4);
 s.player.x=spot.x;s.player.y=spot.y;s.village.interior=null;
 const before=copy(s),begun=F.begin(s,spot),trace=[];
 if(!begun.ok)throw Error(begun.msg);
 while(F.current().time<begun.spec.duration){
  const g=F.current(),toggle=mode==='standard'&&policy!=='miss'&&(!g.hooked&&F.phase(g)==='咬钩'||g.hooked&&!g.caught&&!g.missed&&(policy==='surge'?!g.holding:g.holding&&g.tension>65||!g.holding&&g.tension<30));
  if(toggle)F.toggle();
  const paused=trace.length===3||trace.length===20;
  const dt=trace.length===7?-0.05:trace.length===9?0.5:0.1;
  F.tick(s,dt,paused);trace.push({dt,paused,toggle,game:snapshot(),phase:F.phase(F.current())});
 }
 if(mutate==='bait'){const id=bait==='grain'?'rice':bait==='herb'?'wildHerb':'shrimp';C.consume(s,{[id]:s.bag[id]});}
 if(mutate==='tired')s.stamina=0;
 if(mutate==='rod')s.toolkit.tools.rod.level=0;
 if(mutate==='pressure')s.fishing.waters[spot.water].casts=19;
 const finishBefore=copy(s),result=F.finish(s);
 rows.push({label:[spot.id,day,rod,branch,mode,release,bait,count,policy,mutate].join('/'),spot,before,begun,trace,finishBefore,result,expected:{fishing:s.fishing,bag:s.bag,quality:s.quality,minutes:s.minutes,stamina:s.stamina,tool:s.toolkit.tools.rod,fish:s.stats.fish,lots:s.kitchen.lots,discovered:s.discovered}});
}
for(const spot of F.spots)for(const day of [0,28,56,84])for(const rod of [0,1,2])for(const mode of ['relaxed','standard'])for(const release of [false,true])run(spot,day,rod,'broad',mode,release);
for(const bait of Object.keys(F.baits))for(const count of [0,7,8,200])for(const policy of ['safe','miss','surge'])run(F.spots[0],7,2,'care','standard',false,bait,count,policy);
for(const mutate of ['bait','tired','rod','pressure'])run(F.spots[0],7,2,'broad','relaxed',true,'grain',0,'safe',mutate);
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));
console.log('Exported '+rows.length+' full fishing sessions, '+rows.reduce((n,r)=>n+r.trace.length,0)+' source frame samples');
