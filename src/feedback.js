(function(root){
'use strict';
const C=root.ZRZCore,D=root.ZRZData,V=root.ZRZVillage,F=root.ZRZFarming,K=root.ZRZKitchen,E=root.ZRZEconomy;
const grades=['普通','优质','上品','珍品'],types=['收支','照料','社交','提醒','未完成'],links=['feedback','bag','farmcare','ranch','processing','build','weather','neighbors','economy','fishing','tools'];
const defaults={pace:'normal',motion:'full',floating:'normal',seconds:5,quiet:false};
const rt=new WeakMap();
function runtime(s){if(!rt.has(s))rt.set(s,{floats:[],clock:0,serial:0});return rt.get(s);}
function ensure(s){return s.feedback||={version:1,next:1,rows:[],days:[],seen:[],prefs:{...defaults}};}
function note(s,{key,title,text='',type='提醒',priority=0,link='feedback',merge=false}){
 const f=ensure(s);key=String(key).slice(0,140);title=String(title).slice(0,120);text=String(text).slice(0,1800);
 const prior=f.rows.find(r=>r.key===key&&r.day===s.day);
 if(prior){if(merge){prior.count=Math.min(999999,prior.count+1);prior.minute=Math.floor(s.minutes);}if(prior.text!==text){prior.text=text;prior.read=false;}return prior;}
 const row={id:f.next++,key,title,text,type,priority,link,day:s.day,minute:Math.floor(s.minutes),count:1,read:priority===0};
 f.rows.push(row);if(f.rows.length>80){const i=f.rows.findIndex(r=>r.read&&r.priority===0);f.rows.splice(i<0?0:i,1);}return row;
}
function mark(s,id){const f=ensure(s);for(const row of f.rows)if(id==='all'||row.id===Number(id))row.read=true;}
function counts(s,id){return [0,1,2,3].map(g=>['bag','storage'].reduce((n,side)=>{const q=(side==='bag'?s.quality:s.storageQuality)?.[id]||[0,0,0];return n+(g?q[g-1]||0:Math.max(0,(s[side]?.[id]||0)-q.reduce((a,b)=>a+b,0)));},0));}
function snapshot(s,p={}){
 const all=new Set([...Object.keys(s.bag),...Object.keys(s.storage||{})]);
 const fields={};if(Number.isInteger(p.index)&&s.farm?.beds[p.index]){const b=s.farm.beds[p.index];Object.assign(fields,{水分:Math.round(b.moisture),肥力:Math.round(b.fertility),健康:Math.round(b.health)});}
 const animal=s.animals.find(a=>a.id===(p.animalId||p.kind==='animal'&&p.id));if(animal)Object.assign(fields,{饱食:Math.round(animal.hunger),心情:Math.round(animal.mood),清洁:Math.round(animal.clean)});
 return {day:s.day,minute:s.minutes,money:s.money,stamina:s.stamina,items:Object.fromEntries([...all].map(id=>[id,counts(s,id)])),relations:Object.fromEntries(Object.entries(s.relations).map(([id,r])=>[id,r.points])),fields,world:{
 fish:structuredClone(s.fishing.records),fishCasts:Object.values(s.fishing.waters).reduce((n,w)=>n+(w.day===s.day?w.casts:0),0),lastFish:s.fishing.last?{...s.fishing.last}:null,
 kitchen:s.kitchen.jobs.map(j=>({...j})),trade:s.economy.jobs.map(j=>({...j})),orders:[...s.economy.claimed],
 building:s.building.jobs.map(j=>({...j})),tools:Object.fromEntries(Object.entries(s.toolkit.tools).map(([id,t])=>[id,t.level])),
 neighbors:Object.fromEntries(Object.entries(s.neighbors.people).map(([id,n])=>[id,n.event?{...n.event}:null]))
 }};
}
function worldChanges(before,after){
 const a=before.world,b=after.world,out=[];if(!a||!b)return out;
 const add=(text,link,priority=0,type='提醒')=>out.push({text,link,priority,type});
 for(const [id,rec] of Object.entries(b.fish))if(rec.count>(a.fish[id]?.count||0)){
  const last=b.lastFish,fresh=!a.fish[id],best=!!a.fish[id]&&rec.best>a.fish[id].best;
  add((fresh?'图鉴新发现 · ':best?'体长新纪录 · ':'鱼获记录 · ')+root.ZRZFishing.species[id].name+' '+last.length+' 厘米 · '+grades[last.grade]+(last.released?' · 已轻放回水中':' · 已收进鱼篓'),'fishing',fresh||best?1:0);
 }
 if(b.lastFish?.fish===null&&b.fishCasts>a.fishCasts)add('这竿没有鱼获：'+b.lastFish.reason+'；可以改用轻松观漂模式','fishing',1,'未完成');
 for(const [id,points] of Object.entries(after.relations))if(C.stage(points)!==C.stage(before.relations[id]||0))add(D.npcs.find(n=>n.id===id).name+'：'+C.stage(before.relations[id]||0)+' → '+C.stage(points),'neighbors',1,'社交');
 for(const j of b.kitchen)if(!a.kitchen.some(v=>v.key===j.key))add(K.stations[j.station].name+'已开始加工 '+D.items[j.id].name+' ×'+j.qty+'；约 '+Math.ceil(j.ready-(after.day*1440+after.minute))+' 游戏分钟后手动收取','processing');
 for(const j of b.trade)if(!a.trade.some(v=>v.key===j.key))add((j.channel==='coop'?'合作社代销':'乡间摆摊')+'已接收 '+D.items[j.id].name+' ×'+j.qty+'；待结算 '+j.price+' 元（尚未到账）','economy');
 for(const id of b.orders)if(!a.orders.includes(id))add('供货单 '+id+' 已交付，货款已计入本次收支','economy',1);
 for(const j of b.building)if(!a.building.some(v=>v.id===j.id&&v.level===j.level))add(root.ZRZBuild.projects[j.id].name+'第 '+j.level+' 阶已开工；第 '+(j.readyDay+1)+' 天竣工','build',1);
 for(const [id,level] of Object.entries(b.tools))if(level>a.tools[id])add(root.ZRZTools.defs[id].name+'升至第 '+level+' 阶；可在工具手记选择用法','tools',1);
 for(const [id,event] of Object.entries(b.neighbors))if(event&&event.status!==a.neighbors[id]?.status)add(D.npcs.find(n=>n.id===id).name+'的邻里小事：'+({offered:'想找你搭把手',done:'已经办妥',accepted:'已答应帮忙',postponed:'留待下次'}[event.status]||'已有新进展'),'neighbors',1,'社交');
 return out;
}
function difference(before,after){
 const items=[];for(const id of new Set([...Object.keys(before.items),...Object.keys(after.items)]))for(let grade=0;grade<4;grade++){const qty=(after.items[id]?.[grade]||0)-(before.items[id]?.[grade]||0);if(qty)items.push({id,grade,qty});}
 const relations=Object.keys(after.relations).flatMap(id=>{const amount=after.relations[id]-(before.relations[id]||0);return amount?[{id,amount}]:[];});
 const fields=Object.keys(after.fields).flatMap(name=>after.fields[name]!==before.fields[name]?[{name,from:before.fields[name],to:after.fields[name]}]:[]);
 return {items,relations,fields,money:after.money-before.money,stamina:after.stamina-before.stamina};
}
const signed=n=>(n>0?'+':'')+n;
function describeDelta(d){return [...d.items.map(i=>signed(i.qty)+' '+grades[i.grade]+D.items[i.id].name),...(d.money?[signed(d.money)+' 元']:[]),...d.relations.map(r=>D.npcs.find(n=>n.id===r.id).name+'关系 '+signed(r.amount)),...d.fields.map(f=>f.name+' '+f.from+' → '+f.to),...(d.stamina?['体力 '+signed(Math.round(d.stamina*10)/10)]:[])];}
function finish(s,before,p,spec){
 const after=snapshot(s,p),d=difference(before,after),events=worldChanges(before,after);if(!d.items.length&&!d.money&&!d.relations.length&&!d.fields.length&&!d.stamina&&!events.length)return null;
 const f=ensure(s),type=d.money||d.items.length?'收支':d.relations.length?'社交':'照料';
 let day=f.days.find(d=>d.day===s.day);if(!day){day={day:s.day,actions:0,income:0,spent:0,items:{}};f.days.push(day);f.days=f.days.slice(-7);}day.actions++;day.income+=Math.max(0,d.money);day.spent+=Math.max(0,-d.money);
 for(const i of d.items)if(i.qty>0){const key=i.id+':'+i.grade;day.items[key]=(day.items[key]||0)+i.qty;}
 const key='action/'+spec.kind+'/'+(p.kind==='farm-task'?'farm':p.kind||'menu');
 const detail=[...events.map(e=>e.text),...describeDelta(d)],important=events.find(e=>e.priority),row=note(s,{key:key+'/'+f.next,title:spec.label||'手边的事完成了',text:detail.join('；'),type:events.find(e=>e.type==='未完成')?'未完成':events.find(e=>e.type==='社交')?'社交':type,priority:important||d.items.some(i=>i.qty>0&&i.grade===3)?1:0,link:important?.link||events[0]?.link||(type==='社交'?'neighbors':d.items.length?'bag':'feedback')});
 const r=runtime(s);if(f.prefs.floating!=='off'){
  const gains=d.items.filter(i=>i.qty>0);for(const i of gains){const k=i.id+':'+i.grade,old=r.floats.find(q=>q.key===k&&r.clock-q.at<4.5);if(old){old.qty+=i.qty;old.at=r.clock;old.x=p.x??s.player.x;old.y=p.y??s.player.y;}else r.floats.push({key:k,item:i.id,grade:i.grade,qty:i.qty,at:r.clock,x:p.x??s.player.x,y:p.y??s.player.y});}
  if(important||!gains.length&&(d.fields.length||d.money||d.relations.length||events.length))r.floats.push({key:'result',text:important?.text||detail.filter(t=>!t.startsWith('体力')).slice(0,2).join(' · '),at:r.clock,x:p.x??s.player.x,y:p.y??s.player.y});
  r.floats=r.floats.slice(-4);
 }
 return {row,delta:d};
}
function duration(s,spec){return spec.kind==='fish'||spec.kind==='sleep'?spec.duration:ensure(s).prefs.pace==='brisk'?Math.max(.45,spec.duration*.65):spec.duration;}
function poll(s){
 const f=ensure(s),out=[],emit=(key,title,text,link,priority=1)=>{const token=s.day+'/'+key.slice(0,110)+'/'+[...key].reduce((n,c)=>(Math.imul(n,31)+c.charCodeAt(0))>>>0,0);if(f.seen.includes(token))return;f.seen.push(token);out.push(note(s,{key,title,text,link,priority}));};
 const ready=s.kitchen.jobs.filter(j=>j.ready<=K.now(s));if(ready.length)emit('kitchen/'+ready.map(j=>j.key).join(','),'小灶有成品可收',ready.length+' 批加工完成，走到工位收好，保鲜从收取日开始。','processing');
 const trade=s.economy.jobs.filter(j=>j.ready<=K.now(s));if(trade.length)emit('trade/'+trade.map(j=>j.key).join(','),'有货款可以领取',trade.length+' 张货单可以结算，打开物产经营查看。','economy');
 const hungry=s.animals.filter(a=>a.hunger<40||a.illness>=20);if(hungry.length)emit('animals/'+hungry.map(a=>a.id).join(','),'伙伴需要照料',hungry.map(a=>a.name+'：'+(a.illness>=20?'身体不适':'饲料不足')).join('；'),'ranch',2);
 const low=s.farm.beds.filter((b,i)=>s.plots[i].crop&&(b.health<35||b.moisture<15)).length;if(low)emit('fields','田间照料提醒',low+' 块地需要补水或护苗；打开四时农事查看具体原因。','farmcare',2);
 if(root.ZRZEnvironment.profile(s.day+1).extreme)emit('weather','明日天气预警',root.ZRZEnvironment.warning(s.day),'weather',2);
 const promises=Object.entries(s.neighbors.people).filter(([,p])=>p.event?.day===s.day&&p.event.status==='offered');if(promises.length)emit('neighbors','邻居有件小事想找你',promises.map(([id])=>D.npcs.find(n=>n.id===id).name).join('、')+' 想找人搭把手，不限日期，顺路再去也可以。','neighbors');
 f.seen=f.seen.slice(-80);return out;
}
function laborCost(s,base,kit=null,labor=null){const probe={...s,stamina:100,_kitAction:kit,_laborTool:labor};C.labor(probe,base,0);return Math.round((100-probe.stamina)*10)/10;}
function describe(s,p,tool='hand'){
 if(p.scenery&&root.ZRZTiles)return root.ZRZTiles.describe(s,p);
 let name=p.name||'手边物件',verb='查看',state='走近后互动',reason='',detail='',energy=0;
 if(p.kind==='plot'){
  const a=s.plots[p.index],b=s.farm.beds[p.index],ripe=a.crop&&a.growth>=D.crops[a.crop].days;name=(p.index+1)+' 号田 · '+(a.crop?D.crops[a.crop].name:'菜地');state=F.stage(s,p.index);detail='水分 '+Math.round(b.moisture)+' · 肥力 '+Math.round(b.fertility);
  if(tool==='seed'){verb='播种';energy=laborCost(s,2);const id=F.seedId(s.seed,s.farm.seedKind),need=s.farm.density==='dense'?2:1;reason=a.crop?'已有作物，先收获':!a.tilled||b.removed?'先用锄头松土':(s.bag[id]||0)<need?'缺少'+D.items[id].name+' ×'+need:!D.crops[s.seed].seasons.includes(C.calendar(s).season)&&!F.coverage(s,p.index).some(f=>f.type==='greenhouse'&&s.farm.seedKind!=='seasonal')?'非适种季节，换当季种子或查看暖棚':'';detail+=' · '+D.items[id].name+' ×'+need;}
  else if(tool==='hoe'){const task=root.ZRZTools.plan(s,p.index,tool).find(t=>t.index===p.index);verb=task?.action==='deep'?'深耕养土':'松土';reason=task?'':a.crop?'先收获现有作物':'已经松好土，切换种子播种';energy=laborCost(s,task?.action==='deep'?4:3,'hoe','hoe');}
  else if(tool==='water'){verb='浇水';energy=laborCost(s,2,'water','water');reason=!root.ZRZTools.plan(s,p.index,tool).length?'范围内暂无缺水田，暂缓再浇':'';}
  else if(['hand','sickle'].includes(tool)){verb='收获';energy=laborCost(s,2,'sickle');reason=!ripe?(a.crop?'尚未成熟，还需约 '+Math.ceil(D.crops[a.crop].days-a.growth)+' 天':'这里没有成熟作物，选择种子播种'):'';if(ripe){const q=F.preview(s,p.index);detail+=' · 预计 '+grades[q.grade]+' ×'+q.qty;}}
  else{verb='照料';reason='换锄头、种子、水壶或双手';}
  if(['hoe','water','sickle'].includes(tool)){const tasks=root.ZRZTools.plan(s,p.index,tool);if(tasks.length>1)detail+=' · 沿路逐格 '+tasks.length+' 块';}
 }else if(p.kind==='animal'){
  const a=s.animals.find(a=>a.id===p.id);if(a){name=a.name+' · '+a.species;state=root.ZRZRanch.status(s,a)[0];verb=a.ready||a.feathers?'收取产物':a.hunger<90&&a.care.feed!==s.day?'喂食':'抚摸';if(verb==='抚摸'&&a.care.pet===s.day)reason='今天已经陪过它，先让它歇一会儿';if(verb==='喂食'){const spec=root.ZRZRanch.species[a.type],n=Math.ceil(spec.feed*root.ZRZRanch.breeds[a.breed].feed),id=s.ranch.feed;detail=D.items[id].name+' ×'+n;if((s.bag[id]||0)<n)reason='饲料不足，先补充'+D.items[id].name;if(id==='hay'&&!['cow','sheep','pig'].includes(a.type))reason='鸡鸭不吃干草，换基础饲料或谷物精料';}detail+=' · 饱食 '+Math.round(a.hunger);energy=laborCost(s,verb==='抚摸'?1:verb==='收取产物'&&s.ranch.barns[root.ZRZRanch.species[a.type].home].efficiency?1:2,verb==='收取产物'?'care':null);}
 }else if(p.kind==='gather'){verb='采集';energy=laborCost(s,(s.forage.mode==='full'?4:3)-(s.forage.xp>=20?1:0),null,'gather');state=root.ZRZForage.describe(s,p);const q=root.ZRZForage.status(s,p);reason=q.ready?'':q.wait?'还需休养 '+q.wait+' 天':!q.inSeason?'尚未到采集季节':'等待适合的天气';detail=q.ready?'预计 ×'+q.qty+' · '+(s.forage.mode==='gentle'?'留根采集':'多取一份，休养更久'):'';}
 else if(p.kind==='fish'){verb='抛竿';energy=Math.max(2,6-root.ZRZTools.tool(s,'rod').level);const f=s.fishing,b=root.ZRZFishing.baits[f.bait];state=(f.mode==='relaxed'?'轻松观漂':'手动收放线')+' · '+b.name;reason=C.has(s,b.needs)?'':'鱼饵不足，可换免费素饵';detail=f.release?'这一竿放流并记录':'这一竿收进鱼篓';}
 else if(p.kind==='npc'){verb='聊聊';state=root.ZRZNpc.location(s,p.id).activity;detail='停步面对面 · 对话时暂停时间';}
 else if(p.kind==='enter'||p.kind==='exit'){verb=p.kind==='enter'?'推门进入':'推门出屋';state='从这扇门步行通过';}
 else if(p.kind==='kitchen-station'){verb='查看工位';const jobs=s.kitchen.jobs.filter(j=>j.station===p.station),ready=jobs.filter(j=>j.ready<=K.now(s)).length;state=ready?ready+' 批可收取':jobs.length?jobs.length+' 批加工中':'工位空闲';detail=jobs.length&&!ready?'最快还需 '+Math.ceil(Math.min(...jobs.map(j=>j.ready-K.now(s))))+' 游戏分钟':'';}

 else if(p.kind==='economy'){verb='查看货签';const jobs=s.economy.jobs.filter(j=>j.ready<=K.now(s));state=jobs.length?jobs.length+' 张货单可结算 · '+jobs.reduce((n,j)=>n+j.price,0)+' 元待领':'可摆摊、代销与查看订单';detail='收入以手动领取后的实际到账为准';}
 else if(p.kind==='build'){verb='翻开营造簿';const jobs=s.building.jobs;state=jobs.length?jobs.length+' 处正在修缮':'可查看修缮、改良与布局';const q=root.ZRZBuild.quote(s,'house');if(q&&!jobs.some(j=>j.id==='house')){const missing=Object.entries(q.needs).filter(([id,n])=>(s.bag[id]||0)<n).map(([id,n])=>D.items[id].name+' ×'+(n-(s.bag[id]||0)));if(s.money<q.money)missing.unshift((q.money-s.money)+' 元');detail='老屋下一阶：'+(missing.length?'还缺 '+missing.join('、'):'材料与零钱已备齐')+' · 次日竣工';}}
 else if(p.kind==='tools'){verb='查看工具';state='改良、专长与范围设置';detail='范围作业沿路逐格完成，可随时停下';}
 else if(p.kind==='storage'){verb='整理储物';state=Object.values(s.storage).reduce((a,b)=>a+b,0)+' 件物品存放中';detail='存取物品不会重复计为新获得';}
 else if(p.kind==='build-piece'){verb=p.service==='rest'?'坐一会儿':p.service==='water'?'补充储水':p.service?'使用':'看看陈设';state=p.service==='water'?'储水 '+s.farm.water+' / 120':'亲手安置的小院物件';if(p.service==='water'){energy=laborCost(s,3);detail='补满需 6 元';reason=s.farm.water>=120?'水箱已经装满':s.money<6?'还缺 '+(6-s.money)+' 元':'';}}
 else if(p.kind==='rest'||p.kind==='tea'||p.kind==='bed-visit'){verb='坐一会儿';state='歇脚、恢复体力';}
 else if(p.kind==='egg'){verb='看看旧物';state='靠近翻看，发现屋主的生活细节';}
 else if(p.kind==='chore'){verb='搭把手';state='照料身边的物件';}
 if(!reason&&energy&&s.stamina<energy)reason='还需 '+energy+' 体力，先吃点东西或歇脚';if(energy&&!reason)detail+=(detail?' · ':'')+'体力 '+energy;
 return {name,verb,state,reason,detail,ready:!reason};
}
const targetKey=p=>p?p.kind+'/'+(p.id??p.index??[p.x,p.y].join(',')):'';
class Selection{
 constructor(){this.key='';this.manual='';this.room=null;this.options=[];}
 choose(s,points,hover,tool='hand'){
  if(this.room!==s.village.interior){this.key='';this.manual='';this.room=s.village.interior;}
  const [ux,uy]=({up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]})[s.player.direction]||[0,1],unique=new Map();
  for(const p of points){const dx=p.x-s.player.x,dy=p.y-s.player.y,d=Math.hypot(dx,dy);if(d>=53)continue;const key=targetKey(p),fit=p.kind==='plot'&&['hoe','seed','water','sickle'].includes(tool)?8:0;const available=describe(s,p,tool).ready?3:0;unique.set(key,{...p,score:d-(d?(dx*ux+dy*uy)/d:1)*15-fit-available});}
  this.options=[...unique.values()].sort((a,b)=>a.score-b.score||targetKey(a).localeCompare(targetKey(b)));
  const manual=unique.get(this.manual),pointer=unique.get(targetKey(hover)),last=unique.get(this.key),best=this.options[0];
  const chosen=manual||pointer||(last&&best&&last.score<=best.score+9?last:best);this.key=targetKey(chosen);if(!manual)this.manual='';return chosen||null;
 }
 cycle(direction=1){if(this.options.length<2)return this.options[0]||null;const i=this.options.findIndex(p=>targetKey(p)===this.key),p=this.options[(i+direction+this.options.length)%this.options.length];this.key=this.manual=targetKey(p);return p;}
 clear(){this.key='';this.manual='';}
}
const old={initial:C.initial,load:C.load,nextDay:C.nextDay};C.initial=(...args)=>{const s=old.initial(...args);ensure(s);return s;};
C.nextDay=s=>{const before=s.building.jobs.map(j=>({...j})),r=old.nextDay(s);for(const j of before)if(!s.building.jobs.some(a=>a.id===j.id))note(s,{key:'building/'+j.id+'/'+j.level,title:'修缮工程竣工',text:root.ZRZBuild.projects[j.id].name+'第 '+j.level+' 阶已完成。',priority:1,link:'build'});poll(s);return r;};
C.load=raw=>{
 const v=typeof raw==='string'?JSON.parse(raw):structuredClone(raw),s=old.load(v),f=v.feedback,bad=()=>{throw Error('交互回顾存档无效，请读取备份。');},int=(n,max=1e9)=>Number.isInteger(n)&&n>=0&&n<=max,str=(v,n)=>typeof v==='string'&&v.length<=n;
 if(f!==undefined){
  if(!f||f.version!==1||!int(f.next)||f.next<1||!Array.isArray(f.rows)||f.rows.length>80||!Array.isArray(f.days)||f.days.length>7||!Array.isArray(f.seen)||f.seen.length>80||f.seen.some(v=>!str(v,140))||!f.prefs)bad();
  const p=f.prefs;if(!['normal','brisk'].includes(p.pace)||!['full','reduced'].includes(p.motion)||!['normal','compact','off'].includes(p.floating)||![5,8,12].includes(p.seconds)||typeof p.quiet!=='boolean')bad();
  const seen=new Set();for(const r of f.rows){if(!r||!int(r.id,f.next-1)||seen.has(r.id)||!int(r.day,s.day)||!int(r.minute,1320)||!str(r.key,140)||!str(r.title,120)||!str(r.text,1800)||!types.includes(r.type)||!int(r.priority,2)||!links.includes(r.link)||typeof r.read!=='boolean'||!int(r.count,999999)||r.count<1)bad();seen.add(r.id);}
  const days=new Set();for(const d of f.days){if(!d||!int(d.day,s.day)||days.has(d.day)||!int(d.actions)||!int(d.income,1e12)||!int(d.spent,1e12)||!d.items||Array.isArray(d.items)||Object.entries(d.items).some(([key,n])=>{const [id,g]=key.split(':');return !D.items[id]||!['0','1','2','3'].includes(g)||!int(n,1e12);}))bad();days.add(d.day);}
  s.feedback=structuredClone(f);
 }ensure(s);return s;
};
root.ZRZFeedback={ensure,runtime,note,mark,snapshot,difference,finish,describeDelta,duration,poll,describe,Selection,targetKey,grades,types,links,defaults};
})(typeof window!=='undefined'?window:globalThis);
