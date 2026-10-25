const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,V=ZRZVillage,copy=x=>JSON.parse(JSON.stringify(x)),rows=[],days=[0,27,28,55,56,83,84,111,112,140,223,224];
function make(day,variant){const s=C.initial();s.day=day;if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day,text:'记录'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day,text:'事件'+i}));}return s;}
function run(s,kind,id,choice,variant){const before=copy(s),result=kind==='chapter'?C.chapter(s,id,choice):kind==='gathering'?C.smallEvent(s,id):C.yearPlan(s,choice);rows.push({kind,id,choice,variant,before,result,expected:{chapters:s.chapters,yearPlans:s.yearPlans,seasonEvents:s.seasonEvents,relations:s.relations,skills:s.skills,journal:s.journal,eventLog:s.eventLog,bag:s.bag,money:s.money,minutes:s.minutes}});}
for(const day of days)for(const season of [-1,0,1,2,3,4])for(const choice of [-1,0,1,2])for(const variant of ['fresh','recorded','full']){
 const s=make(day,variant);if(variant==='recorded'&&D.seasonChapters[season])s.chapters[(Math.floor(day/112)+1)+'-'+season]=0;run(s,'chapter',season,choice,variant);
}
for(const day of [6,7,111,112])for(const kind of ['tea','repair','stage','lost','missing'])for(const variant of ['fresh','recorded','full','blocked','together','cap','xp-cap']){
 const s=make(day,variant);s.projects.stage=variant!=='blocked';if(variant==='recorded')s.seasonEvents[kind+'-'+Math.floor(day/7)]=true;
 if(variant==='together')s.skills.social.choice='together';
 if(variant==='cap')for(const n of Object.values(s.relations))n.points=98;
 if(variant==='xp-cap')s.skills.social.xp=99998;run(s,'gathering',kind,0,variant);
}
for(const day of days)for(const choice of [-1,0,1,2,3])for(const variant of ['fresh','recorded','full']){
 const s=make(day,variant);if(variant==='recorded')s.yearPlans[Math.floor(day/112)]=1;run(s,'year',choice,choice,variant);
}
const destinations=Object.fromEntries(['mountain','town','river'].map(id=>[id,V.destination(C.initial(),'region',id)]));
fs.writeFileSync(process.argv[2],JSON.stringify({rows,destinations}));console.log('Life choices source cases: '+rows.length);
