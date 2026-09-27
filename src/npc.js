(function(root){
'use strict';
const C=root.ZRZCore,V=root.ZRZVillage,D=root.ZRZData,P=root.ZRZNpcContent;
const ids=D.npcs.map(n=>n.id),historyLimit=160,topics=['auto','daily','advice','memory'];
const ok=msg=>({ok:true,msg}),no=msg=>({ok:false,msg});
const homes=Object.fromEntries(D.npcs.map(n=>[n.id,V.homeOf(n.id)]));
const base=C.initial(),work=Object.fromEntries(D.npcs.map(n=>[n.id,V.workPoint(base,n)]));
const school=V.houses.find(h=>/小学/.test(h.name)),market=V.houses.find(h=>/杂货/.test(h.name));
for(const [id,name]of Object.entries({lin:'禾溪小学',chen:'竹木工坊',xu:'许婶杂货',mei:'方记米糕',ning:'邻里食堂',an:'村卫生室',liang:'村卫生室',tao:'乡村邮政',luSenior:'竹编作坊',luo:'种子互助屋'})){const h=V.houses.find(h=>h.name===name);if(h)work[id]=V.safePosition({village:{}},{x:h.door.x+(ids.indexOf(id)%3-1)*30,y:h.door.y+28});}
work.yu={x:749,y:2790};
const face=(p,q)=>{const dx=q.x-p.x,dy=q.y-p.y;p.direction=Math.abs(dx)>Math.abs(dy)?dx>0?'right':'left':dy>0?'down':'up';};
function ensure(s){
 const f=s.neighbors||={version:1,day:-1,people:Object.fromEntries(ids.map(id=>[id,{introduced:false,recent:[],last:null,event:null}])),history:[]};
 if(f.day!==s.day){f.day=s.day;if(s.day>=2)for(let j=0;j<2;j++){const id=ids[((s.day-2)*2+j)%ids.length],p=f.people[id],e=p.event;if(!e||e.status==='done'&&s.day-e.completed>=28)p.event={day:s.day,status:'offered',method:null,completed:null};}}
 return f;
}
function event(s,id){return ensure(s).people[id]?.event;}
function activity(s,id){
 const n=D.npcs.find(n=>n.id===id),i=ids.indexOf(id),h=homes[id],m=s.minutes,cal=C.calendar(s),e=event(s,id);
 const at=(key,label,target,gesture='read',room=null,reason='按平日作息')=>({key,label,target,gesture,room,reason});
 const home=(key,label,gesture,reason)=>at(key,label,h.door,gesture,h.id,reason);
 if(m<(id==='mei'?390:420+i%4*12)||m>=1140+i%4*12)return home('night','在家歇息','sleep','夜间回屋，明早再忙');
 if(root.ZRZEnvironment?.profile(s.day).shelter)return home('shelter','在家'+P[id].work,P[id].gesture,'风雨或寒冷天气，转为室内活动');
 if(cal.date===14&&m>=660&&m<1080){const center=market?.door||work.xu;return at('festival','准备'+D.festivals[cal.season],{x:center.x+(i%6-2)*30,y:center.y+80+Math.floor(i/6)*32},'fan','',D.festivals[cal.season]+'当天，去老街会合');}
 if(e&&e.status!=='done'&&['granny','zhouSenior','liang','song'].includes(id)&&m>=570&&m<960)return home('housework',P[id].request,P[id].gesture,'家中有件小事，可带材料或一起搭把手');
 if(m<510+i%3*20)return home('morning','准备出门 · '+P[id].work,P[id].gesture,'早起先整理手边东西');
 const lunch=720+i%3*20;if(m>=lunch&&m<lunch+65)return home('lunch','回家吃饭歇脚','tea','午饭和休息有自己的时间');
 if(n.tier==='child'&&s.day%7<5&&m<900&&school)return at('school','上课与自然观察',{x:school.door.x+(i%4-1.5)*28,y:school.door.y+30},'read',null,'平日先上学，放学后做自己的事');
 if(m<960){if(s.day%7===5&&['xu','mei','tao','song','luSenior','luo'].includes(id)){const c=market?.door||work.xu;return at('market','赶集 · '+P[id].work,{x:c.x+(i%5-2)*37,y:c.y+90+Math.floor(i/5)*20},P[id].gesture,null,'每周赶集日到老街照看摊位');}return at('work',P[id].work,work[id],P[id].gesture);}
 if(m<1080){const friend=D.links.find(([from])=>from===id)?.[1],other=homes[friend],center=other?.door||(s.projects.bridge?{x:1165,y:2800}:h.door);return at('visit',other?'在'+D.npcs.find(n=>n.id===friend).name+'门前聊家常':s.projects.bridge?'去修好的河埠歇脚':'在自家门前散步',{x:center.x+(i%3-1)*27,y:center.y+36},'tea',null,other?'忙完工作，沿路看看亲友':'傍晚留一点散步时间');}
 return home('evening','收好工具，准备晚饭','tea','晚间回到自己的小屋');
}
function near(s,id){const n=D.npcs.find(n=>n.id===id),p=n&&V.npcPoint(s,n);return !!p&&Math.hypot(s.player.x-p.x,s.player.y-p.y)<=80;}
function location(s,id){const p=s.village.npc[id],h=p.room&&homes[id],plan=activity(s,id),a=V.stateRuntime(s).actors[id];return {place:h?h.name:V.regionAt(p.x,p.y).name,activity:a?.walking?'沿路前往 · '+plan.label:plan.label,reason:plan.reason,plan};}
function entries(s){return ids.map(id=>({id,...location(s,id),event:event(s,id)}));}
function remember(s,id,key,text,category='日常',emotion='calm',choice=''){
 const f=ensure(s),p=f.people[id],record={id,key,day:s.day,minute:Math.floor(s.minutes),text,category,emotion,choice};
 p.last=record;p.recent=[...p.recent.filter(k=>k!==key),key].slice(-12);
 if(!f.history.some(r=>r.id===id&&r.day===s.day&&r.key===key&&r.choice===choice))f.history.push(record);
 f.history=f.history.slice(-historyLimit);const a=V.stateRuntime(s).actors[id];if(a){a.emotion=emotion;a.emotionUntil=V.stateRuntime(s).clock+7;}
 return record;
}
function candidates(s,id,topic='auto'){
 const n=D.npcs.find(n=>n.id===id),p=ensure(s).people[id],cal=C.calendar(s),plan=activity(s,id),r=s.relations[id],list=[];
 const add=(key,text,category='日常',emotion='calm')=>list.push({key,text,category,emotion});
 if(topic==='advice'){add('advice',P[id].advice,'线索','focus');return list;}
 if(topic==='memory'){
  if(p.event?.status==='done')add('help-memory-'+p.event.day,'上回'+P[id].request+'，你'+(p.event.method==='supply'?'把材料送来了':'留下来一起做完了')+'。那一点照应，我记着呢。','回忆','happy');
  const st=s.stories[id];if(st?.step){const e=D.arcs[id][st.step-1];add('story-memory-'+st.step,e.choices[st.choices.at(-1)].reply,'回忆','happy');}
  if(r.gifted>=0&&r.gifted<=s.day&&s.day-r.gifted<=7)add('gift-memory-'+r.gifted,'前些天你带来的那份心意，我收好了。空手来聊聊天，也一样欢迎。','回忆','happy');
  if(!list.length)add('new-memory','咱们还可以慢慢熟悉。今天遇见，说几句话，就是一件新记忆。','回忆');return list;
 }
 if(topic==='auto'){
  const ready=C.storyReady(s,id);if(ready.ok)add('story-'+s.stories[id].step,'我有件近况想和你商量：“'+D.arcs[id][s.stories[id].step].title+'”。你愿意听时，我们再慢慢聊。','故事','thought');
  if(n.birthday===s.day%112+1)add('birthday-'+s.day,'今天是我的生日。你路过停下来，我就觉得是个好日子，不用特意备贵重东西。','节庆','happy');
  if(cal.date>=13&&cal.date<=15)add('festival-'+cal.date+'-'+cal.season,cal.date===13?'明天是'+D.festivals[cal.season]+'，我想把'+P[id].work+'先安排好，留点时间给饭桌。':cal.date===14?'今天的'+D.festivals[cal.season]+'，来了就坐一会儿。自己的活没忙完，改天补聚也一样。':s.festivals.includes(cal.year+'-'+cal.season)?'昨天饭桌上的热闹还记得。今天把日常的事慢慢接上。':'昨天没聚上也别着急，节令饭桌还等着你。','节庆','happy');
  const e=p.event;if(e&&e.status!=='done')add('event-'+e.day+'-'+e.status,e.status==='accepted'?'你答应帮我'+P[id].request+'。不赶日子，备好材料或者有空一起做都行。':e.status==='postponed'?'上次那件'+P[id].request+'的小事还在，改天再说也行，不用觉得欠着什么。':'最近想'+P[id].request+'。带两份'+D.items[P[id].item].name+'，或者留一会儿一起做，都能帮上忙。','邻里小事','thought');
  if(s.fishing?.last?.fish&&s.day-s.fishing.last.day<=2&&['yu','ning','mei'].includes(id))add('fish-'+s.fishing.last.day,'你记下的'+D.items[s.fishing.last.fish].name+'有 '+s.fishing.last.length+' 厘米。'+(s.fishing.last.released?'放回水里也留下了一次观察。':'鲜鱼及时做菜，吃不完也能晾成鱼干。'),'生活','happy');
  if(s.forage?.finds?.length&&['zhou','luo','granny'].includes(id)){const f=s.forage.finds.at(-1);if(s.day-f.day<=2)add('forage-'+f.day,'最近采回的'+D.items[f.item].name+'正是山野的馈赠。留下根和老叶，下次走过还能看见新芽。','生活','happy');}
  if(s.projects.bridge||s.flags.bridge)add('bridge','新河埠能好好坐下歇脚了。做成一件大家用得上的事，路也走得亲近。','村庄','happy');
  if(s.building?.house>0&&['chen','he'].includes(id))add('house-'+s.building.house,'你家的老屋修得更妥帖了。添进去的每件东西，都能讲讲为什么放在那里。','村庄','happy');
  if(s.marriage?.spouse===id)add('partner',P[id].trust+' 等各自忙完，再把今天讲给彼此听。','关系','happy');else if(r.points>=60)add('trust',P[id].trust,'关系','happy');else if(r.points>=25)add('familiar','现在见到你，我就想起'+P[id].goal+'。不必给我答案，听我说说也好。','关系','calm');
  if(C.weather(s.day)!=='晴')add('weather-'+C.weather(s.day),'今天'+C.weather(s.day)+'，'+(plan.room?'我在屋里'+P[id].work+'。你先站稳，擦擦手再坐。':'沿路慢一点，手边的事不用急着赶完。'),'天气','thought');
  add('season-'+cal.season,['春天东西长得快，做事倒可以慢一点，给嫩芽留点空。','夏日午后先找片阴凉，等暑气过去再做细活。','秋天收好的东西多，记得把能分给邻居的也留一份。','冬天屋里有热水，路过进来暖暖手再走。'][cal.season],'时令');
 }
 if(!p.introduced)add('intro',n.greeting,'初识','happy');
 add('work-'+plan.key,'我这会儿在'+plan.label+'。'+P[id].daily[0],'日常','focus');
 P[id].daily.forEach((text,i)=>add('daily-'+i,text));return list;
}
function converse(s,id,topic='auto'){
 if(!ids.includes(id)||!topics.includes(topic))return no('请选择想聊的话题。');if(!near(s,id))return no('先沿路走到对方面前，再慢慢聊。');
 const p=ensure(s).people[id],list=candidates(s,id,topic),row=list.find(r=>!p.recent.includes(r.key))||list.slice().sort((a,b)=>p.recent.indexOf(a.key)-p.recent.indexOf(b.key))[0];
 const beforeRice=s.bag.rice||0,beforeRecipes=s.knownRecipes.length,result=old.talk(s,id);if(!result.ok)return result;
 let text=row.text;if((s.bag.rice||0)>beforeRice)text+='〔收到对方回赠的稻米 ×'+(s.bag.rice-beforeRice)+'〕';if(s.knownRecipes.length>beforeRecipes)text+='〔学会 '+(s.knownRecipes.length-beforeRecipes)+' 道家常菜，已记入菜谱〕';
 p.introduced=true;remember(s,id,row.key,text,row.category,row.emotion);return {...ok(text),emotion:row.emotion};
}
function resolve(s,id,op,day){
 if(!ids.includes(id)||!near(s,id))return no('请先走到这位邻居身边。');const e=event(s,id);if(!e||e.day!==Number(day)||e.status==='done')return no('这件小事的状态已经变化，重新看看近况吧。');
 const d=P[id];let msg,choice;
 if(op==='accept'){if(e.status==='accepted')return no('已经记下这份约定。');e.status='accepted';choice='答应帮忙，材料或共同劳动均可';msg='好呀，'+d.request+'就等咱们有空来做。没有截止日期。';}
 else if(op==='later'){if(e.status==='postponed')return no('已经约好以后再说。');e.status='postponed';choice='说明改天再来，不扣关系';msg='你先忙自己的，哪天顺路再说。';}
 else if(['join','supply'].includes(op)){
  if(e.status!=='accepted')return no('先把愿意怎么帮忙说清楚，再一起动手。');
  const needs={[d.item]:2};if(op==='supply'&&!C.has(s,needs))return no('还需要 '+D.items[d.item].name+' ×2，也可以选择一起劳动。');
  if(op==='join'&&!C.labor(s,3,20))return no('先歇歇，再来一起做这件小事。');if(op==='supply')C.consume(s,needs);
  e.status='done';e.method=op;e.completed=s.day;s.relations[id].points=Math.min(100,s.relations[id].points+6);choice=op==='join'?'一起动手 · 20 分钟 / 3 体力':'送来 '+D.items[d.item].name+' ×2';
  msg='“'+d.request+'”完成了。'+(op==='join'?'两个人分着做，原来零碎的活也轻快起来。':'材料整齐放好，对方可以接着完成手边的活。')+'〔关系 +6〕';
 }else return no('请选择一种回应。');
 remember(s,id,'event-'+e.day+'-'+op,msg,'邻里小事',op==='later'?'calm':'happy',choice);C.log(s,D.npcs.find(n=>n.id===id).name+'：'+msg);return ok(msg);
}
function updateNPC(s,n,i,a,dt){
 const rt=V.stateRuntime(s),p=s.village.npc[n.id],h=homes[n.id],plan=activity(s,n.id);
 if(rt.sequence?.npcId===n.id){a.walking=false;const here=p.room?a.inside:p;if(here)face(here,s.player);a.emotion='focus';a.emotionUntil=rt.clock+2;return;}
 const key=[s.day,plan.key,plan.room,plan.target.x,plan.target.y].join('/');
 if(a.scheduleKey!==key){a.scheduleKey=key;a.plan=plan;a.phase=plan.key;a.target=null;a.path=[];a.wait=0;a.insideRt={path:[],wait:0};a.goal=V.safePosition({village:{}},plan.target);a.failures=0;}
 a.activity=plan.label;a.gesture=plan.gesture;
 if(p.room){
  a.inside||=V.safePosition({...s,village:{interior:p.room}},{x:480,y:560,direction:'up'});const nav={...s,village:{interior:p.room}},q=a.insideRt||={path:[],wait:0};
  if(p.room!==plan.room){const door=V.roomObjects(h,s).find(p=>p.kind==='exit');a.walking=V.stepActor(s,a.inside,door,dt,48,q,p.room);if(Math.hypot(a.inside.x-door.x,a.inside.y-door.y)<8){p.room=null;Object.assign(p,h.door);a.path=[];a.target=null;a.inside=null;}return;}
  if(s.village.interior===p.room&&Math.hypot(a.inside.x-s.player.x,a.inside.y-s.player.y)<60){a.walking=false;face(a.inside,s.player);return;}
  if(q.wait>0){q.wait-=dt;a.walking=false;return;}
  if(!q.target){const choices=V.roomObjects(h,s).filter(p=>['egg','tea','bed-visit'].includes(p.kind)),t=choices[(Math.floor(rt.clock/18)+i)%Math.max(1,choices.length)]||{x:480,y:450};q.target=V.safePosition(nav,{x:t.x,y:t.y+25});}
  a.walking=V.stepActor(s,a.inside,q.target,dt,34,q,p.room);if(!q.path.length){q.target=null;q.wait=5+i%5;}return;
 }
 if(!s.village.interior&&Math.hypot(p.x-s.player.x,p.y-s.player.y)<60){a.walking=false;face(p,s.player);return;}
 if(plan.room){a.walking=V.stepActor(s,p,h.door,dt,n.age>60?64:96,a);if(Math.hypot(p.x-h.door.x,p.y-h.door.y)<8){p.room=h.id;a.inside=V.safePosition({...s,village:{interior:h.id}},{x:480,y:560,direction:'up'});a.path=[];a.walking=false;}return;}
 if(a.wait>0){a.wait-=dt;a.walking=false;return;}
 if(!a.target){const arrived=Math.hypot(p.x-a.goal.x,p.y-a.goal.y)<90;a.target=arrived?V.safePosition({village:{}},{x:a.goal.x+Math.sin(rt.clock*.12+i)*38,y:a.goal.y+Math.cos(rt.clock*.1+i)*22}):a.goal;}
 a.walking=V.stepActor(s,p,a.target,dt,n.tier==='child'?103:n.age>60?64:92,a);
 if(!a.path.length){if(Math.hypot(p.x-a.target.x,p.y-a.target.y)>15){a.failures=(a.failures||0)+1;a.goal=V.safePosition({village:{}},a.failures>2?h.door:{x:a.goal.x+24,y:a.goal.y+24});a.activity='绕到附近可通行处';}a.target=null;a.wait=4+i%5;a.walking=false;}
}
const old={initial:C.initial,load:C.load,talk:C.talk,storyChoice:C.storyChoice,gift:C.gift};
C.initial=(...args)=>{const s=old.initial(...args);ensure(s);return s;};
C.talk=(s,id)=>converse(s,id);
C.gift=(s,id,item)=>{if(!near(s,id))return no('先走近对方，再把心意交到手中。');const r=old.gift(s,id,item);if(r.ok)remember(s,id,'gift-'+s.day,'你送来了'+D.items[item].name+'。'+r.msg,'回忆','happy','送上 '+D.items[item].name);return r;};
C.storyChoice=(s,id,choice)=>{if(!near(s,id))return no('面对面聊完这一段故事吧，先沿路找到对方。');const e=D.arcs[id]?.[s.stories[id]?.step],r=old.storyChoice(s,id,choice);if(r.ok&&e)remember(s,id,'story-choice-'+s.stories[id].step,e.text+'\n'+r.msg,'故事','happy',e.choices[choice].label);return r;};
C.load=raw=>{
 const v=typeof raw==='string'?JSON.parse(raw):structuredClone(raw),s=old.load(v),f=v.neighbors,bad=()=>{throw Error('邻里手记存档无效，请使用备份。');},int=(n,max=s.day)=>Number.isInteger(n)&&n>=0&&n<=max,str=(v,n)=>typeof v==='string'&&v.length<=n;
 if(f!==undefined){
  if(!f||f.version!==1||!int(f.day)||!f.people||Array.isArray(f.people)||Object.keys(f.people).length!==24||!Array.isArray(f.history)||f.history.length>historyLimit)bad();
  const record=r=>r&&ids.includes(r.id)&&str(r.key,100)&&int(r.day)&&int(r.minute,1320)&&str(r.text,2200)&&str(r.choice,200)&&['日常','线索','回忆','初识','故事','节庆','邻里小事','生活','村庄','关系','天气','时令'].includes(r.category)&&['calm','happy','focus','thought'].includes(r.emotion);
  for(const id of ids){const p=f.people[id];if(!p||typeof p.introduced!=='boolean'||!Array.isArray(p.recent)||p.recent.length>12||p.recent.some(k=>!str(k,100))||p.last&&(!record(p.last)||p.last.id!==id))bad();const e=p.event;if(e&&(!int(e.day)||!['offered','accepted','postponed','done'].includes(e.status)||!['join','supply',null].includes(e.method)||(e.status==='done'?(!int(e.completed)||e.completed<e.day||!e.method):e.completed!==null||e.method!==null)))bad();}
  if(f.history.some(r=>!record(r)))bad();s.neighbors=structuredClone(f);
 }
 ensure(s);return s;
};
root.ZRZNpc={ensure,event,activity,location,entries,near,candidates,converse,resolve,remember,updateNPC,profiles:P,historyLimit};
})(typeof window!=='undefined'?window:globalThis);
