const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const adults=D.npcs.filter(n=>n.tier==='romance'&&n.age>=18);
function ready(s,id){s.partners[id]='dating';s.stories[id]={step:4,choices:[0,0,0,0],lastDay:5};s.relations[id].points=70;}
function base(){const s=C.initial();s.day=10;s.minutes=600;s.upgrades.room=true;return s;}
function run(s,op,id,variant){const before=copy(s),result=op==='marry'?C.marry(s,id):C.separate(s);rows.push({op,id,variant,before,result,expected:{marriage:s.marriage,partners:s.partners,journal:s.journal,eventLog:s.eventLog,relations:s.relations,stories:s.stories}});}
for(const n of [...D.npcs,{id:'missing'}])for(const variant of ['ready','no-dating','three-chapters','no-room','trust69','trust100','already','other-spouse','full','room-and-trust-missing']){
 const s=base();if(adults.some(a=>a.id===n.id))ready(s,n.id);
 if(variant==='no-dating')s.partners[n.id]='friend';
 if(variant==='three-chapters'&&s.stories[n.id])s.stories[n.id]={step:3,choices:[0,0,0],lastDay:5};
 if(variant==='no-room'||variant==='room-and-trust-missing')s.upgrades.room=false;
 if((variant==='trust69'||variant==='room-and-trust-missing')&&s.relations[n.id])s.relations[n.id].points=69;
 if(variant==='trust100'&&s.relations[n.id])s.relations[n.id].points=100;
 if(variant==='already'||variant==='other-spouse'){const who=variant==='already'&&adults.some(a=>a.id===n.id)?n.id:adults.find(a=>a.id!==n.id).id;ready(s,who);s.marriage={spouse:who,day:5,weekly:{'1-visit':true},memories:[{day:5,activity:'visit'}]};}
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 // Only legal source partners are serializable; non-candidates do not own partner status.
 if(!adults.some(a=>a.id===n.id))delete s.partners[n.id];
 run(s,'marry',n.id,variant);
}
for(const n of adults)for(const variant of ['ready','none','memories','full']){
 const s=base();ready(s,n.id);s.marriage={spouse:variant==='none'?null:n.id,day:5,weekly:{'1-visit':true},memories:[{day:5,activity:'visit'}]};
 if(variant==='memories')s.marriage.memories=Array.from({length:80},()=>({day:5,activity:'plan'}));
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 run(s,'separate',n.id,variant);
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Marriage/separation source cases: '+rows.length);
