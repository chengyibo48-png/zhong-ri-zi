const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const app=fs.readFileSync(require('node:path').join(__dirname,'../../src/app.js'),'utf8');
const marker='if(!currentPanel&&!document.hidden&&!inputLocked){walking=move(dt);';
const start=app.indexOf(marker);if(start<0)throw Error('Original clock frame missing');
let end=start+marker.indexOf('{')+1,depth=1;for(;depth&&end<app.length;end++){if(app[end]==='{')depth++;else if(app[end]==='}')depth--;}
const block=app.slice(start,end);
const clock=new Function('s','rawDelta','paused','locked',"const dt=Math.min(.05,rawDelta),currentPanel=paused,document={hidden:false},inputLocked=locked;let walking=false,tick=0,frameTime=0;const move=()=>false,update=()=>{},openPanel=()=>{},ambient=()=>{};"+block);
for(const speed of ['relaxed','normal'])for(const minutes of [390,600.25,1319.9,1320])for(const delta of [0,.001,1/60,.049,.05,.2,1])for(const pause of ['none','panel','action']){
 const s=C.initial();s.day=10;s.minutes=minutes;s.settings.speed=speed;
 const before=copy(s);clock(s,delta,pause==='panel',pause==='action');
 rows.push({speed,delta,pause,before,expected:s.minutes,loaded:C.load(before).minutes});
}
const labor=[];for(const minutes of [600.001,600.25,1319.9,1320]){const s=C.initial();s.day=10;s.minutes=minutes;const before=copy(s);const ok=C.labor(s,2,15);labor.push({before,ok,minutes:s.minutes,stamina:s.stamina});}
const deadlines=[];
for(const offset of [-.01,0,.01]){
 const s=C.initial();s.day=10;s.minutes=600.25;s.upgrades.mill=true;C.add(s,'wheat',4);
 const started=ZRZKitchen.start(s,'flour',1);if(!started.ok)throw Error(started.msg);
 const job=s.kitchen.jobs[0];s.minutes=job.ready-s.day*1440+offset;
 const before=copy(s),result=ZRZKitchen.collect(s,job.key);
 deadlines.push({before,result,minutes:s.minutes,bag:s.bag,quality:s.quality,jobs:s.kitchen.jobs,loaded:C.load(before).minutes});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows,labor,deadlines,source:block}));console.log('Original clock frames: '+rows.length);
