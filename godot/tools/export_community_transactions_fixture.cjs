const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const groups=[['project',Object.entries(D.projects).map(([id,p])=>({...p,id}))],['favor',D.favors],['deliver',D.orders]];
for(const [kind,entries] of groups)for(const entry of [...entries,{id:kind==='favor'?999:'missing',needs:{},reward:{},npc:'granny'}])for(const variant of ['base','missing','locked','completed','early','no-intro','cooperate','known','cap','xp-cap','log-cap','wrong-scene','quality']){
 let s=C.initial();s.day=112;s.minutes=1305;s.scene='town';s.player.x=2831;s.player.y=500;if(kind==='project')s.flags.firstDish=true;
 for(const [id,n]of Object.entries(entry.needs||{}))C.add(s,id,n+2);
 for(const id of Object.keys(entry.reward||{}))delete s.bag[id];
 K.ensure(s);
 for(const lots of Object.values(s.kitchen.lots.bag))for(const lot of lots)lot.age=3;
 if(variant==='missing'){const id=Object.keys(entry.needs||{})[0];if(id)C.consume(s,{[id]:s.bag[id]});}
 if(variant==='locked')s.economy.locked=Object.keys(entry.needs||{});
 if(variant==='completed'&&entries.some(e=>e.id===entry.id)){if(kind==='project')s.projects[entry.id]=true;else if(kind==='favor')s.seasonEvents['favor-'+entry.id]=true;else s.flags[entry.id]=true;}
 if(variant==='early')s.day=Math.max(0,(entry.season||0)*28-1);
 if(variant==='no-intro')delete s.flags.firstDish;
 if(variant==='cooperate')s.skills.craft.choice='cooperate';
 if(variant==='known'&&entry.recipe&&!s.knownRecipes.includes(entry.recipe))s.knownRecipes.push(entry.recipe);
 if(variant==='cap')s.relations[entry.npc||'chen'].points=98;
 if(variant==='xp-cap'){s.skills.craft.xp=99998;s.skills.social.xp=99998;}
 if(variant==='log-cap'){s.journal=Array.from({length:60},(_,i)=>({day:s.day,text:'已有记录'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:s.day,text:'已有记录'+i}));}
 if(variant==='wrong-scene'){s.scene='farm';s.player.x=2831;s.player.y=1652;}
 if(variant==='quality')for(const id of Object.keys(entry.needs||{})){s.quality[id]=[1,1,Math.max(0,(s.bag[id]||0)-2)];}
 s=C.load(copy(s));
 const before=copy(s), result=kind==='project'?C.project(s,entry.id):kind==='favor'?C.favor(s,entry.id):C.deliver(s,entry.id);
 rows.push({kind,id:entry.id,variant,before,result,expected:{bag:s.bag,quality:s.quality,lots:s.kitchen.lots,discovered:s.discovered,flags:s.flags,projects:s.projects,relations:s.relations,skills:s.skills,seasonEvents:s.seasonEvents,archives:s.archives,knownRecipes:s.knownRecipes,money:s.money,stats:s.stats,minutes:s.minutes,journal:s.journal,eventLog:s.eventLog}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Community transaction source cases: '+rows.length);
