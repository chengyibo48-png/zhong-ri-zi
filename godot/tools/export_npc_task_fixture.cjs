const fs=require('node:fs'),path=require('node:path');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const branch=app.slice(app.indexOf("if(p.kind==='npc-task'){"),app.indexOf("if(!performed&&p.kind==='fish'"));
const action=Function('p','s','performed','window','Actions','startAction','interact','toast','C','apply','openPanel','lastDialogue',branch);
const copy=x=>JSON.parse(JSON.stringify(x)),specs=[],rows=[];
function fresh(id){const s=ZRZCore.initial();s.day=2;s.minutes=720;s.stamina=50;s.player.x=2831;s.player.y=1652;s.village.interior=null;s.village.npc[id]={x:2831,y:1652,room:null,direction:'down'};ZRZNpc.ensure(s);return s;}
for(const n of ZRZData.npcs){
 for(const op of ['talk','story','accept','later','supply','join']){
  const s=fresh(n.id);let spec;
  action({kind:'npc-task',id:n.id,npcId:n.id,op},s,false,globalThis,ZRZActions,v=>spec=copy(v),()=>{},()=>{},ZRZCore,()=>{},()=>{},'');
  specs.push({id:n.id,op,spec});
 }
 for(const op of ['accept','later','supply','join'])for(const variant of ['offered','accepted','postponed','done','stale','empty','tired','cap','far']){
  const s=fresh(n.id),profile=ZRZNpc.profiles[n.id];
  s.neighbors.people[n.id].event={day:2,status:['offered','postponed','done'].includes(variant)?variant:'accepted',method:variant==='done'?'join':null,completed:variant==='done'?2:null};
  ZRZCore.add(s,profile.item,5);
  if(variant==='empty')s.bag[profile.item]=0;
  if(variant==='tired')s.stamina=0;
  if(variant==='cap')s.relations[n.id].points=99;
  if(variant==='far')s.player.x-=200;
  const before=copy(s),eventDay=variant==='stale'?1:2,result=ZRZNpc.resolve(s,n.id,op,eventDay);
  rows.push({id:n.id,op,variant,eventDay,before,result,expected:{bag:s.bag,quality:s.quality,relations:s.relations,people:s.neighbors.people[n.id],history:s.neighbors.history,money:s.money,minutes:s.minutes,stamina:s.stamina,journal:s.journal}});
 }
}
fs.writeFileSync(process.argv[2],JSON.stringify({specs,rows}));
console.log('Exported '+specs.length+' special NPC action specs and '+rows.length+' authoritative event transactions');
