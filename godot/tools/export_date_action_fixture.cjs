const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const adults=D.npcs.filter(n=>n.tier==='romance'&&n.age>=18);
function ready(s,id){s.stories[id]={step:4,choices:[0,0,0,0],lastDay:5};}
for(const n of [...D.npcs,{id:'missing'}])for(const variant of ['initial','ready','friend','dating','full','trust0','other-spouse','same-spouse']){
 const s=C.initial();s.day=10;s.minutes=600;
 if(adults.some(a=>a.id===n.id)){
  if(variant!=='initial')ready(s,n.id);
  if(variant==='friend')s.partners[n.id]='friend';
  if(variant==='dating')s.partners[n.id]='dating';
  if(variant==='trust0')s.relations[n.id].points=0;
 }
 if(variant==='other-spouse'||variant==='same-spouse'){
  const who=variant==='same-spouse'&&adults.some(a=>a.id===n.id)?n.id:adults.find(a=>a.id!==n.id).id;
  ready(s,who);s.partners[who]='dating';s.marriage={spouse:who,day:5,weekly:{'1-visit':true},memories:[{day:5,activity:'visit'}]};
 }
 if(variant==='full'){s.journal=Array.from({length:60},(_,i)=>({day:10,text:'旧日志'+i}));s.eventLog=Array.from({length:200},(_,i)=>({day:10,text:'旧事件'+i}));}
 const before=copy(s),result=C.date(s,n.id);
 rows.push({id:n.id,variant,before,result,expected:{partners:s.partners,journal:s.journal,eventLog:s.eventLog}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Date source cases: '+rows.length);
