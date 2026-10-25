const fs=require('node:fs'),path=require('node:path');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,M=ZRZMuseum,copy=x=>JSON.parse(JSON.stringify(x));
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const branch=app.slice(app.indexOf("if(p.kind==='museum-task'){"),app.indexOf("if(p.kind==='npc-task'){"));
const action=Function('p','s','performed','window','Actions','startAction','interact','apply','openPanel',branch);
function spec(task){let result;action({...task,kind:'museum-task'},{},false,globalThis,ZRZActions,v=>result=copy(v),()=>{},()=>{},()=>{});return result;}
function fresh(){const s=C.initial();s.village.interior=M.house.id;s.player.x=480;s.player.y=510;return s;}
function ready(s,key,grade=0){const e=M.byKey[key];M.record(s,key,true,false,false,grade);if(e.type==='item'){C.add(s,e.id,3);s.quality[e.id]=[0,0,0];if(grade)s.quality[e.id][grade-1]=3;if(M.donationMap[key].modes.includes('record'))s.fishing.records[e.id]={count:1,best:22,waters:['river'],first:0,grade:0};}if(e.type==='archive'&&!s.archives.includes(e.id))s.archives.push(e.id);if(e.type==='npc'){s.stories[e.id]={step:1,choices:[0],lastDay:0};}if(e.type==='wild')s.collection.observations[e.id]=[0];}
const rows=[];
function add(task,variant,prepare){const s=fresh();prepare(s);if(variant==='far')s.player.x=100;const before=copy(s);
 const result=task.op==='donate'?M.donate(s,task.id,task.mode,task.grade):task.op==='claim'?M.claim(s,task.id):task.op==='upgrade'?M.upgrade(s):M.feature(s,task.id);
 rows.push({task,variant,before,spec:spec(task),result,expected:{collection:s.collection,bag:s.bag,quality:s.quality,furniture:s.furniture,money:s.money,stamina:s.stamina,minutes:s.minutes,rows:s.feedback.rows,lots:s.kitchen.lots}});
}
for(const d of M.donations)for(const mode of d.modes)for(const grade of mode==='sample'?[0,1,2,3]:[0]){
 const task={op:'donate',id:d.key,mode,grade};
 add(task,'ready',s=>ready(s,d.key,grade));
 if(grade===0){add(task,'far',s=>ready(s,d.key,grade));add(task,'repeat',s=>{ready(s,d.key,grade);M.donate(s,d.key,mode,grade);});}
}
for(const variant of ['missing','locked','empty'])add({op:'donate',id:'item:cabbage',mode:'sample',grade:0},variant,s=>{if(variant!=='missing')ready(s,'item:cabbage');if(variant==='locked')s.economy.locked.push('cabbage');if(variant==='empty')s.bag.cabbage=0;});
function complete(s,b){for(const key of b.keys){ready(s,key);const d=M.donationMap[key];s.collection.donated[key]={day:0,mode:d.modes[0],grade:0};}}
for(const b of M.bundles)for(const variant of ['ready','incomplete','repeat','cap','far'])add({op:'claim',id:b.id},variant,s=>{if(variant!=='incomplete')complete(s,b);if(variant==='repeat')M.claim(s,b.id);if(variant==='cap')s.furniture[b.reward]=999;});
for(let level=0;level<M.levels.length;level++)for(const variant of ['ready','empty','far'])add({op:'upgrade',id:''},variant,s=>{s.collection.level=level;if(variant!=='empty')for(const d of M.donations){ready(s,d.key);s.collection.donated[d.key]={day:0,mode:d.modes[0],grade:0};}});
for(const d of M.donations)for(const variant of ['ready','missing','far'])add({op:'feature',id:d.key},variant,s=>{if(variant!=='missing'){ready(s,d.key);s.collection.donated[d.key]={day:0,mode:d.modes[0],grade:0};}});
fs.writeFileSync(process.argv[2],JSON.stringify({rows,house:M.house,registry:M.registry}));
console.log('Exported '+rows.length+' authoritative museum transactions and special action specs');
