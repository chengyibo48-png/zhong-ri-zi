const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,N=ZRZNpc,copy=x=>JSON.parse(JSON.stringify(x)),counts={case:0,sequence:0};
const output=fs.openSync(process.argv[2],'w');
function emit(type,row){counts[type]++;fs.writeSync(output,JSON.stringify({type,...row})+'\n');}
function fresh(id,day=8){const s=C.initial();s.day=day;s.minutes=600;N.ensure(s);s.village.interior=null;s.village.npc[id]={x:2831,y:1652,room:null};s.player.x=2831;s.player.y=1652;return s;}
for(const n of ZRZData.npcs)for(const variant of ['base','birthday','festival13','festival14','festival15','joined15','summer','autumn','winter','accepted','postponed','done','trust','familiar','story','listener','bridge','house','fish','forage','night','visit','museum','fullRecent','fishInteger','giftRecent','giftExpired','giftBoundary','spouse','returnGift','listenerReward','alreadyTalked',...Array.from({length:112},(_,i)=>'yearDay'+i),...ZRZData.arcs[n.id].flatMap((a,i)=>a.choices.map((c,j)=>'memoryStory'+i+'-'+j))]){
 const day=variant==='birthday'?n.birthday-1:variant.startsWith('festival')?Number(variant.slice(8))-1:variant==='joined15'?14:variant.startsWith('yearDay')?Number(variant.slice(7)):['summer','autumn','winter'].includes(variant)?28*(1+['summer','autumn','winter'].indexOf(variant)):8;
 const s=fresh(n.id,day);
 if(variant==='birthday')s.day=n.birthday-1;
 if(variant.startsWith('festival'))s.day=Number(variant.slice(8))-1;
 if(variant==='joined15'){s.day=14;s.festivals.push('1-0');}
 if(['summer','autumn','winter'].includes(variant))s.day=28*(1+['summer','autumn','winter'].indexOf(variant));
 if(['accepted','postponed','done'].includes(variant))s.neighbors.people[n.id].event={day:8,status:variant,method:variant==='done'?'supply':null,completed:variant==='done'?8:null};
 if(variant==='trust')s.relations[n.id].points=60;
 if(variant==='familiar')s.relations[n.id].points=25;
 if(variant==='story'){s.relations[n.id].points=100;for(const item of Object.keys(ZRZData.items))C.add(s,item,5);}
 if(variant==='listener'){s.relations[n.id].points=7;s.skills.social.choice='listener';}
 if(variant==='bridge'){s.projects.bridge=true;s.flags.bridge=true;}
 if(variant==='house')s.building.house=2;
 if(variant==='fish')s.fishing.last={fish:'fish',day:8,length:22.5,released:true};
 if(variant==='forage')s.forage.finds=[{item:'tea',day:8}];
 if(variant==='night')s.minutes=1200;
 if(variant==='visit')s.minutes=1000;
 if(variant==='museum'){s.collection.level=2;s.minutes=1000;}
 if(variant==='fishInteger')s.fishing.last={fish:'fish',day:8,length:22,released:false};
 if(variant==='giftRecent')s.relations[n.id].gifted=8;
 if(variant==='giftExpired')s.relations[n.id].gifted=0;
 if(variant==='giftBoundary')s.relations[n.id].gifted=1;
 if(variant==='returnGift'){s.relations[n.id].points=24;s.relations[n.id].returnGift=true;}
 if(variant==='listenerReward'){s.relations[n.id].points=23;s.skills.social.choice='listener';}
 if(variant==='alreadyTalked'){s.relations[n.id].points=24;s.relations[n.id].talked=s.day;}
 if(variant==='spouse'&&n.tier==='romance'){s.stories[n.id]={step:4,choices:[0,0,0,0],lastDay:7};s.partners[n.id]='dating';s.marriage.spouse=n.id;s.marriage.day=7;}
 if(variant.startsWith('yearDay')){s.day=Number(variant.slice(7));s.minutes=[400,600,760,1000,1180][s.day%5];}
 if(variant.startsWith('memoryStory')){const [i,j]=variant.slice(11).split('-').map(Number);s.stories[n.id]={step:i+1,choices:[...Array(i).fill(0),j],lastDay:7};}
 N.ensure(s);
 for(const topic of ['auto','daily','advice','memory']){
  const v=copy(s);
  const list=N.candidates(v,n.id,topic);
  if(variant==='fullRecent')v.neighbors.people[n.id].recent=list.map(x=>x.key).reverse().slice(-12);
  const before=copy(v),result=N.converse(v,n.id,topic);
  emit('case',{id:n.id,variant,topic,before,candidates:list,result,expected:{bag:v.bag,relations:v.relations,knownRecipes:v.knownRecipes,skills:v.skills,people:v.neighbors.people[n.id],history:v.neighbors.history,eventLog:v.eventLog}});
 }
}
for(const n of ZRZData.npcs)for(const topic of ['auto','daily','memory','advice']){
 const s=fresh(n.id);s.relations[n.id].points=20;
 const before=copy(s),turns=[];
 for(let i=0;i<18;i++){const result=N.converse(s,n.id,topic);turns.push({result,people:copy(s.neighbors.people[n.id]),relations:copy(s.relations),bag:copy(s.bag),knownRecipes:copy(s.knownRecipes),skills:copy(s.skills),history:copy(s.neighbors.history),eventLog:copy(s.eventLog)});}
 emit('sequence',{id:n.id,topic,before,turns});
}
fs.closeSync(output);
console.log('Exported '+counts.case+' dialogue cases and '+counts.sequence+' eighteen-conversation sequences');
