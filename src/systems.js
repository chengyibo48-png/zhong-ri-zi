(function(root){
  'use strict';
  const D=root.ZRZData||require('./content.js'), C=root.ZRZCore;
  const yes=msg=>({ok:true,msg}), no=msg=>({ok:false,msg}), copy=x=>JSON.parse(JSON.stringify(x));
  const old={...C};
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
  const dayKey=s=>Math.floor(s.day/7);
  function defaults(s){
    return {version:3,storage:{},quality:{},storageQuality:{},knownRecipes:D.recipes.filter(r=>r.source==='known').map(r=>r.id),stories:Object.fromEntries(D.npcs.map(n=>[n.id,{step:0,choices:[],lastDay:-1}])),partners:{},marriage:{spouse:null,day:-1,weekly:{},memories:[]},projects:{bridge:!!s.flags.bridge},chapters:{},letters:[],mailRead:[],layouts:[],furniture:{},skills:Object.fromEntries(Object.keys(D.skillNames).map(k=>[k,{xp:0,choice:null}])),toolUpgrades:{},archives:['key'],achievements:[],buffs:{laborDay:-1},appearance:{shirt:0,hair:0,skin:0,hat:true},pet:{type:'cat',name:'小团',bond:0,patted:-1},seasonEvents:{},waterReserve:0,greenhouse:false,freeRange:true,animalCare:{},resourcePressure:{},lastGifts:{},marketDays:[],yearPlans:{},eventLog:[],
    };
  }
  function ensure(s){
    const d=defaults(s);for(const[k,v]of Object.entries(d))if(s[k]===undefined)s[k]=v;
    Object.assign(s.settings,{music:s.settings.music??.35,ambient:s.settings.ambient??.3,effects:s.settings.effects??.6,textSpeed:s.settings.textSpeed??'instant',textScale:s.settings.textScale??1,contrast:s.settings.contrast??false,vibration:s.settings.vibration??false,gamepad:s.settings.gamepad??true,fishAssist:s.settings.fishAssist??true});
    for(const p of s.plots){p.care??=0;p.pest??=false;}
    if(!s.letters.length)s.letters.push({id:'welcome',day:s.day,title:'院门口的便条',from:'林阿婆',text:'先收菜，再做一碗饭。屋里的储物柜、院子的改造和邻里故事，都可以从生活簿找到。心愿没有截止日期。',gift:{cabbageSeed:2}});
    return s;
  }
  C.initial=(...args)=>ensure(old.initial(...args));
  C.VERSION=3;
  function xp(s,key,n=1){const v=s.skills[key];v.xp=Math.min(99999,v.xp+n);}
  function track(s,text){s.eventLog.unshift({day:s.day,text});s.eventLog=s.eventLog.slice(0,200);C.log(s,text);}
  function unlock(s,id){if(id&&!s.knownRecipes.includes(id)&&D.recipes.some(r=>r.id===id)){s.knownRecipes.push(id);track(s,'学会了 '+D.items[id].name+'。');return true;}return false;}
  C.unlockRecipe=unlock;
  C.learnFrom=(s,id)=>{let count=0;D.recipes.filter(r=>r.source===id).forEach(r=>{if(unlock(s,r.id))count++;});return count;};
  C.weather=day=>{const d=day%112;if(d===46)return '台风';if(d===51||d===52)return '高温';if(d===99)return '寒潮';if(d===95||d===105)return '小雪';return old.weather(day);};
  C.weatherAdvice=day=>({台风:'明日台风：可先备好蓄水、留在家中加工。作物和动物不会损失。',高温:'高温天多歇歇，补好蓄水；不浇水只会长慢一些。',寒潮:'寒潮期间温棚照常生长，露地暂时减速，作物不会枯死。',小雪:'小雪可以安心拜访、做饭，田里的作物仍会慢慢生长。',雨:'雨水会替你浇地，晒制顺延一天；可以去串门。'}[C.weather(day)]||'适合出门走走，照看小院或赶集。');
  C.market=s=>({open:s.day%7===5,demand:Object.keys(D.crops)[Math.floor(s.day/7)%Object.keys(D.crops).length],bonus:.2});
  C.price=(s,id,qty=1)=>{const base=D.items[id].price,bonus=C.market(s),q=s.quality[id]||[0,0];let left=Math.max(0,qty-Math.max(0,(s.bag[id]||0)-q.reduce((a,b)=>a+b,0))),extra=0;for(let i=0;i<q.length;i++){const used=Math.min(left,q[i]);extra+=used*[.2,.4,.7][i];left-=used;}return Math.floor(base*(qty+extra)*(bonus.open&&bonus.demand===id?1.2:1));};
  C.sell=(s,id,n=1)=>{if(!D.items[id]||!Number.isInteger(n)||n<1||!C.has(s,{[id]:n}))return no('没有这么多可出售的物品。');const money=C.price(s,id,n);C.consume(s,{[id]:n});s.money+=money;s.stats.earned+=money;s.flags.firstSale=true;return yes('售出'+D.items[id].name+' ×'+n+'，收到 '+money+' 元（含品质与赶集加价）。');};
  C.storageMove=(s,id,qty,toStorage)=>{
    if(!s.upgrades.storage)return no('先在修缮小院中添置储物柜。');
    if(!D.items[id]||!Number.isInteger(qty)||qty<1||qty>999999)return no('请输入有效数量。');
    const from=toStorage?s.bag:s.storage,to=toStorage?s.storage:s.bag,qFrom=toStorage?s.quality:s.storageQuality,qTo=toStorage?s.storageQuality:s.quality;
    if((from[id]||0)<qty)return no('没有这么多物品。');
    const q=qFrom[id]||[0,0],normal=from[id]-q.reduce((a,b)=>a+b,0);let left=Math.max(0,qty-normal);qTo[id]??=Array(q.length).fill(0);while(qTo[id].length<q.length)qTo[id].push(0);const moved=q.map((n,i)=>{const used=Math.min(n,left);left-=used;qTo[id][i]+=used;return n-used;});
    from[id]-=qty;if(!from[id])delete from[id];to[id]=(to[id]||0)+qty;qFrom[id]=moved;
    return yes((toStorage?'存好':'取出')+D.items[id].name+' ×'+qty+'，品质也已一同保留。');
  };
  C.fertilize=(s,i)=>{const p=s.plots[i];if(!p||!p.tilled)return no('请选一块已经松土的菜地。');if(p.soil>=2)return no('土壤已经肥沃，暂时不用堆肥。');if(!C.has(s,{compost:1}))return no('需要熟堆肥，可在加工页制作或杂货铺购买。');C.consume(s,{compost:1});p.soil=Math.min(2,p.soil+1);xp(s,'farming');return yes('熟堆肥拌进土里，土壤恢复了一档。');};
  C.clearPest=(s,i)=>{const p=s.plots[i];if(!p?.pest)return no('这里没有需要处理的小虫。');p.pest=false;xp(s,'farming');return yes('轻轻把虫移到野草边，生长恢复正常。没有作物损失。');};
  C.plotAction=(s,i,tool)=>{
    if(['axe','sickle','build'].includes(tool))return no('这件工具用于木料、野菜或布置。农田请用锄头、种子、水壶或双手。');
    const p=s.plots[i],before=p?copy(p):null,wasHarvest=p?.crop&&p.growth>=D.crops[p.crop].days&&tool==='hand';
    s._laborTool=tool;let r;try{r=old.plotAction(s,i,tool);}finally{delete s._laborTool;}if(!r.ok)return r;
    xp(s,'farming',wasHarvest?3:1);
    if(tool==='water'&&p.crop)p.care++;
    if(tool==='seed'){p.care=0;p.pest=false;}
    if(wasHarvest){const count=before.soil===2?2:1;const grade=before.care>=Math.ceil(D.crops[before.crop].days*.7)?2:before.soil>=1.75||s.skills.farming.choice==='care'?1:0;if(grade){s.quality[before.crop]??=[0,0];s.quality[before.crop][grade-1]+=count;}r.msg+=' 品质：'+['普通','好收成','精心照料'][grade]+'。';p.care=0;p.pest=false;}
    return r;
  };
  C.canUseStation=(s,station)=>{const st=D.stations[station];return station==='堆肥箱'||!!st&&(st.base||!!s.upgrades[st.upgrade]);};
  C.recipeNeeds=(s,r,substitute=false)=>{const needs={...r.ingredients};if(!substitute)return needs;const groups={cabbage:['spinach','lettuce','bokchoy','mustard','wildHerb'],egg:['duckEgg'],fish:['perch','loach'],mushroom:['driedMushroom'],rice:['corn'],bean:['pea','broadbean']};for(const[id,count]of Object.entries(needs))if((s.bag[id]||0)<count&&groups[id]){const alt=groups[id].find(k=>(s.bag[k]||0)>=count);if(alt){delete needs[id];needs[alt]=(needs[alt]||0)+count;}}return needs;};
  C.cook=(s,id,qty=1,substitute=false)=>{
    const r=D.recipes.find(v=>v.id===id);if(!r||!s.knownRecipes.includes(id))return no('还没学会这份菜谱。可向对应村民请教、赶集购买或试做发现。');
    if(!Number.isInteger(qty)||qty<1||qty>20)return no('一次制作 1 到 20 份。');
    if(!C.canUseStation(s,r.station)||(r.upgrade&&!s.upgrades[r.upgrade]))return no('还缺少'+r.station+'，可在修缮小院中添置。');
    const needs=C.recipeNeeds(s,r,substitute);if(!C.has(s,needs,qty))return no('食材还没备齐，菜谱旁会显示现有数量。');
    C.consume(s,needs,qty);xp(s,'cooking',qty*3);s.flags.firstCook=true;
    if(r.station==='腌菜坛'||r.station==='晾晒架'){s.processing.push({id,qty,readyDay:s.day+1,station:r.station,cooking:true});return yes('已放入'+r.station+'，明天处理好后会放进背包；雨天晒制会顺延。');}
    C.add(s,id,qty);s.stats.cooked+=qty;if(!substitute){s.quality[id]??=[0,0];s.quality[id][s.skills.cooking.choice==='host'?1:0]+=qty;}track(s,'做了'+D.items[id].name+(substitute?'（家常替代食材版）':'')+'。');return yes(D.items[id].name+'做好了 ×'+qty+(substitute?'。替代食材也能成菜，属于朴素家常品质。':'。'));
  };
  C.trial=(s,first,second)=>{if(!D.items[first]||!D.items[second])return no('先选两样手边的食材。');const supplied={};[first,second].forEach(k=>supplied[k]=(supplied[k]||0)+1);if(!C.has(s,supplied))return no('背包没有选定的食材，重复选择需要两份。');const r=D.recipes.find(r=>Object.keys(r.ingredients).every(k=>k===first||k===second)&&Object.keys(supplied).every(k=>k in r.ingredients));if(!r)return no('这两种食材还没摸索出合适的做法。食材保留，可以换个搭配再试。');if(!C.canUseStation(s,r.station))return no('这份做法需要'+r.station+'。食材保留。');unlock(s,r.id);return yes('试出了“'+D.items[r.id].name+'”的配方！记下用量后，就能按菜谱批量做。食材尚未扣除。');};
  C.process=(s,id,n=1)=>{const r=D.processingRecipes.find(p=>p.id===id);if(!r||!Number.isInteger(n)||n<1||n>20)return no('请选 1 到 20 批。');if(!C.canUseStation(s,r.station))return no('先添置'+r.station+'。');if(!C.has(s,r.needs,n))return no('加工原料不足。');C.consume(s,r.needs,n);xp(s,'craft',n*2);if(r.days)s.processing.push({id,qty:r.qty*n,readyDay:s.day+r.days,station:r.station,cooking:false});else C.add(s,id,r.qty*n);return yes(r.name+'已安排 ×'+n+(r.days?'。次日完成；雨天的晒制会顺延。':'。产物已放进背包。'));};
  C.eat=(s,id)=>{const r=old.eat(s,id);if(r.ok&&D.items[id].kind==='料理'){if(s.skills.cooking.choice==='home')s.stamina=Math.min(100,s.stamina+8);if(D.recipes.find(r=>r.id===id)?.category==='田间便当'){s.buffs.laborDay=s.day;r.msg+=' 今天后续劳动少耗 1 点体力。';}}return r;};
  C.talk=(s,id)=>{const first=s.relations[id]?.talked!==s.day,r=old.talk(s,id);if(!r.ok)return r;const n=D.npcs.find(n=>n.id===id);if(first){xp(s,'social',2);if(s.skills.social.choice==='listener')s.relations[id].points=Math.min(100,s.relations[id].points+2);if(s.relations[id].points>=10){const learned=C.learnFrom(s,id);if(learned)r.msg+='〔对方教了你 '+learned+' 道拿手菜，已写入菜谱〕';}}if(first){r.msg+=' '+D.termTips[Math.floor((s.day%112)*24/112)];const link=D.links.find(([from,to])=>to===id&&s.stories[from].step>=2);if(link)r.msg+=' '+link[2];}if(n.birthday===s.day%112+1)r.msg+=' 今天是我的生日，能聊上几句就很开心。';const ready=C.storyReady(s,id);if(ready.ok)r.msg+='〔有一段新的邻里故事可以聊聊〕';return r;};
  C.gift=(s,npc,id)=>{const prev=s.lastGifts[npc],points=s.relations[npc]?.points,r=old.gift(s,npc,id);if(r.ok){if(prev===id)s.relations[npc].points=points+Math.ceil((s.relations[npc].points-points)/2);s.lastGifts[npc]=id;xp(s,'social',3);if(D.npcs.find(n=>n.id===npc).birthday===s.day%112+1)s.relations[npc].points=Math.min(100,s.relations[npc].points+3);r.msg+=' 换着聊天、合作、送菜，会有更多新的回应。';}return r;};
  C.storyReady=(s,id)=>{const n=D.npcs.find(n=>n.id===id),st=s.stories[id],arc=D.arcs[id];if(!n||!st||!arc)return no('暂无故事。');const e=arc[st.step];if(!e)return no('这段故事已经留下了完整记录。');if(e.kind==='married'&&s.marriage.spouse!==id)return no('这一章是共同生活故事，结婚后再来聊。');if(st.lastDay===s.day)return no('今天聊到这里，明天再来继续。');if(s.relations[id].points<e.points)return no('关系达到 '+e.points+' 后继续；聊聊天、一起做饭或完成委托都可以。');if(e.needs&&!C.has(s,e.needs))return no('这次合作需要 '+Object.entries(e.needs).map(([k,n])=>D.items[k].name+' ×'+n).join('、')+'，随时备好再来。');return yes('此刻在'+D.scenes[C.npcScene(s,n)].name+'，可以继续聊“'+e.title+'”。');};
  C.storyChoice=(s,id,choice)=>{
    const ready=C.storyReady(s,id);if(!ready.ok)return ready;const st=s.stories[id],e=D.arcs[id][st.step],n=D.npcs.find(n=>n.id===id);if(![0,1].includes(choice))return no('请选择一个回应。');
    if(e.needs)C.consume(s,e.needs);if(e.kind==='confirmation'){if(n.tier!=='romance'||n.age<18)return no('只有成年候选人才有关系确认。');s.partners[id]=choice===0?'dating':'friend';}
    st.choices.push(choice);st.step++;if(st.step===2)for(const[from,to]of D.links)if(from===id)s.relations[to].points=Math.min(100,s.relations[to].points+2);st.lastDay=s.day;s.relations[id].points=Math.min(100,s.relations[id].points+10);xp(s,'social',5);C.learnFrom(s,id);track(s,n.name+' · '+e.title+'：'+e.choices[choice].reply);
    if(st.step===D.arcs[id].length){const a={granny:'recipe',chen:'ruler',zhouSenior:'teaBook',he:'album'}[id];if(a&&!s.archives.includes(a))s.archives.push(a);C.add(s,'rice',2);}
    return yes(e.choices[choice].reply);
  };
  C.date=(s,id)=>{const n=D.npcs.find(n=>n.id===id);if(n?.tier!=='romance'||n.age<18||s.stories[id].step<4)return no('先走过对方的关系确认故事。');s.partners[id]='dating';track(s,'与'+n.name+'再次确认了心意。');return yes('把心意说开了。对方愿意和你慢慢走下去。');};
  C.marry=(s,id)=>{const n=D.npcs.find(n=>n.id===id);if(n?.tier!=='romance'||n.age<18||s.partners[id]!=='dating'||s.stories[id].step<4||s.relations[id].points<70)return no('需要双方确认心意、走完前四章，并达到信任。');if(s.marriage.spouse)return no('已有共同生活的伴侣，可先好好商量未来安排。');if(!s.upgrades.room)return no('先整理厢房，让两个人都有自己的空间。');s.marriage={spouse:id,day:s.day,weekly:{},memories:[]};track(s,'在乡亲们的饭桌祝福里，和'+n.name+'结为伴侣。');return yes('院里摆开一张长桌。大家带菜来，祝你们各自有喜欢的事，也有愿意一起回来的家。');};
  C.separate=s=>{if(!s.marriage.spouse)return no('目前没有伴侣。');const n=D.npcs.find(n=>n.id===s.marriage.spouse);s.partners[n.id]='friend';s.marriage={spouse:null,day:-1,weekly:{},memories:[]};track(s,'和'+n.name+'平静地商量，各自生活，仍是邻里。');return yes('各自的工作、友谊和已发生的故事都保留。');};
  C.sharedLife=(s,activity,dish)=>{const id=s.marriage.spouse;if(!id)return no('有共同生活的伴侣后再来安排。');if(!['meal','visit','objects','plan'].includes(activity))return no('请选择一种共同安排。');const key=dayKey(s)+'-'+activity;if(s.marriage.weekly[key])return no('这一周已经安排过了，留点时间做自己的事吧。');if(activity==='meal'){if(D.items[dish]?.kind!=='料理'||!C.has(s,{[dish]:1}))return no('共餐需要一道料理。');C.consume(s,{[dish]:1});}s.marriage.weekly[key]=true;s.marriage.memories.push({day:s.day,activity});s.marriage.memories=s.marriage.memories.slice(-80);s.relations[id].points=Math.min(100,s.relations[id].points+5);const text={meal:'你们坐下来共餐，轮流讲今天的见闻。',visit:'各自安排好工作，和伴侣一起去看望亲友。',objects:'旧柜里的物件被擦拭干净，你们添上一张属于现在的便条。',plan:'你们写下各自来年的愿望，也留下愿意一起做的事。'}[activity];track(s,text);return yes(text);};
  C.hostMeal=(s,id,dish)=>{if(!s.upgrades.room)return no('先整理厢房，摆好共餐桌。');if(s.scene!=='farm')return no('先回到小院，再安排家宴。');const n=D.npcs.find(n=>n.id===id);if(!n)return no('先选一位邻居。');const key='meal-'+dayKey(s)+'-'+id;if(s.seasonEvents[key])return no('这周已经邀请过对方，下周再约。');if(D.items[dish]?.kind!=='料理'||!C.has(s,{[dish]:1}))return no('需要备好一道料理。');C.consume(s,{[dish]:1});s.seasonEvents[key]=true;s.relations[id].points=Math.min(100,s.relations[id].points+10+(s.skills.cooking.choice==='host'?3:0));xp(s,'social',3);C.learnFrom(s,id);track(s,'请'+n.name+'来小院吃'+D.items[dish].name+'，聊了聊'+n.role+'的日常。');return yes('对方说起近来的工作，也认真听你讲菜地里的新变化。下周再约。');};
  C.project=(s,id)=>{const p=D.projects[id];if(!p)return no('没有这个公共项目。');if(s.projects[id]||id==='bridge'&&s.flags.bridge)return no('大家已经完成了这项修缮。');if(s.day<p.season*28)return no(D.seasons[p.season]+'季起大家准备动工，之后随时可以补做。');if(id==='bridge'){const r=old.repair(s);if(!r.ok)return r;}else{if(!C.has(s,p.needs))return no('材料还没齐。你只需备自己的这一份，其他材料和手艺由乡亲们负责。');C.consume(s,p.needs);s.relations[p.npc].points=Math.min(100,s.relations[p.npc].points+20);}
    s.projects[id]=true;if(id==='bridge'&&!s.archives.includes('photo'))s.archives.push('photo');unlock(s,p.recipe);xp(s,'craft',12);if(s.skills.craft.choice==='cooperate')C.add(s,'bamboo',2);track(s,'共同完成'+p.name+'。'+p.change);return yes(p.name+'完成。'+p.people+p.change);};
  C.repair=s=>C.project(s,'bridge');
  C.upgrade=(s,id)=>{if(id==='irrigation'&&!s.projects.canal)return no('先和大家疏通旧水渠，再接院内蓄水。');const r=old.upgrade(s,id);if(r.ok){xp(s,'craft',8);if(id==='yard'){s.furniture.bench=(s.furniture.bench||0)+1;s.furniture.pot=(s.furniture.pot||0)+1;s.furniture.path=(s.furniture.path||0)+1;}if(id==='irrigation')s.waterReserve=3;}return r;};
  C.craft=(s,id)=>{const f=D.furniture[id];if(!f||!s.upgrades.yard)return no('先整理庭院，才能按图纸制作。');if(id==='greenhouse'&&s.day<56)return no('小温棚图纸在秋季开放，已有作物跨季不会枯死。');if(!C.has(s,f.needs))return no('材料不足。');C.consume(s,f.needs);s.furniture[id]=(s.furniture[id]||0)+1;if(s.skills.craft.choice==='reuse'&&f.needs.wood)C.add(s,'wood');xp(s,'craft',3);return yes('做好了'+f.name+'。在院落布置图中选位置放下即可。');};
  // Decorations occupy a fixed lawn grid; beds, buildings and paths to doors stay reachable.
  C.layoutSlots=Array.from({length:24},(_,i)=>({x:[536,644,752,1032,1140,1248][i%6],y:874+Math.floor(i/6)*52}));
  C.place=(s,id,slot)=>{if(!s.upgrades.yard||!D.furniture[id]||!(s.furniture[id]>0))return no('还没有可摆放的这件家具。');if(!Number.isInteger(slot)||!C.layoutSlots[slot])return no('请选一格庭院布置位置。');if(s.layouts.some(v=>v.slot===slot))return no('这一格已有家具，先收回或换个位置。');s.furniture[id]--;s.layouts.push({id,slot});s.greenhouse=s.layouts.some(v=>v.id==='greenhouse');return yes('放好了'+D.furniture[id].name+'。可以随时收回、再放到别处。');};
  C.removeFurniture=(s,slot)=>{const i=s.layouts.findIndex(v=>v.slot===slot);if(i<0)return no('这一格没有家具。');const v=s.layouts.splice(i,1)[0];s.furniture[v.id]=(s.furniture[v.id]||0)+1;s.greenhouse=s.layouts.some(v=>v.id==='greenhouse');return yes('家具已经收好，材料和家具不会损失。');};
  C.toolUpgrade=(s,id)=>{const t=D.toolUpgrades[id];if(!t||s.toolUpgrades[id])return no('这件工具已经顺手了。');if(s.money<t.cost||!C.has(s,t.needs))return no('零钱或材料不足。');s.money-=t.cost;C.consume(s,t.needs);s.toolUpgrades[id]=true;xp(s,'craft',5);return yes(t.name+'完成，以后对应劳动少耗 1 点体力。工具没有耐久损耗。');};
  C.skill=(s,id,choice)=>{if(!D.skillChoices[id]?.some(v=>v[0]===choice)||s.skills[id].xp<25)return no('熟练度达到 25 后可以选一种做事风格。');if(s.skills[id].choice)return no('已经有自己的做事风格啦。');s.skills[id].choice=choice;return yes('记下了你的选择，基础操作始终都能使用。');};
  C.animalAction=(s,id,action)=>{const a=s.animals.find(a=>a.id===id);if(!a)return no('没有这位小伙伴。');if(action==='feed')return C.tend(s,id);const key=id+'-'+action;if(!['clean','pet'].includes(action))return no('请选择照料方式。');if(s.animalCare[key]===s.day)return no('今天已经陪过它了，可以安心去做别的事。');s.animalCare[key]=s.day;a.bond=Math.min(100,a.bond+2);return yes(action==='clean'?'顺手清理了垫草，小棚更干爽了。':'轻轻摸摸'+a.name+'，它认得你的脚步。');};
  C.pet=(s)=>{if(s.pet.patted===s.day)return no(s.pet.name+'正在打盹，今天已经陪它玩过了。');s.pet.patted=s.day;s.pet.bond=Math.min(100,s.pet.bond+3);return yes(s.pet.name+'靠过来蹭了蹭你。窗外的声音慢了下来。');};
  C.fillWater=s=>{if(!s.upgrades.irrigation)return no('先安装蓄水设施。');s.waterReserve=3;return yes('蓄水桶装满，足够应对三天高温或台风。不扣体力。');};
  C.gather=(s,node,id)=>{if(id==='wildHerb'){if(s.collected[node]===s.day)return no('今天已采过，明天再来。');if(!C.labor(s,3,10))return no('先歇一会儿。');s.collected[node]=s.day;C.add(s,id,2);s.stats.gathered+=2;return yes('采到野荠菜 ×2。留一点给明天。');}s._laborTool='gather';let r;try{r=old.gather(s,node,id);}finally{delete s._laborTool;}if(r.ok){xp(s,'craft');const area=s.scene;s.resourcePressure[area]??={day:s.day,count:0};if(s.resourcePressure[area].day!==s.day)s.resourcePressure[area]={day:s.day,count:0};s.resourcePressure[area].count++;if(!['wood','bamboo'].includes(id)&&s.resourcePressure[area].count>3){C.consume(s,{[id]:1});s.stats.gathered--;r.msg='这一片今天采得多了，采到'+D.items[id].name+' ×1。明天会恢复，也可以去另一处走走。';}}return r;};
  C.fish=s=>{const cost=Math.max(2,6-(s.toolUpgrades.rod?1:0));if(!C.labor(s,cost,25))return no('先歇歇或吃点东西。');const list=D.fishBySeason[C.calendar(s).season].slice();if(['雨','台风'].includes(C.weather(s.day)))list.push('shrimp');const id=list[(s.stats.fish+s.day)%list.length];C.add(s,id);s.stats.fish++;return yes('收竿！钓到了'+D.items[id].name+'。鱼种会随时令和天气变化。');};
  C.festival=(s,dish,choice=0,season=C.calendar(s).season)=>{const c=C.calendar(s),year=c.year,key=year+'-'+season;if(![0,1,2,3].includes(season)||!Number.isInteger(season))return no('请选择季节。');if(s.festivals.includes(key))return no('这一季的故事已经记下了，来年还能参加。');if((year-1)*112+season*28+13>s.day)return no('该季第 14 天起可以开席。');if(D.items[dish]?.kind!=='料理'||!C.has(s,{[dish]:1}))return no('带一道料理来吧。');if(![0,1].includes(choice))return no('选一种参与方式。');C.consume(s,{[dish]:1});s.festivals.push(key);s.seasonEvents['festival-'+key]=choice;Object.values(s.relations).forEach(r=>r.points=Math.min(100,r.points+10));C.add(s,'rice',3);C.learnFrom(s,'festival'+season);xp(s,'social',8);const f=D.festivalDetails[season];track(s,'参加'+f.name+'：'+f.choices[choice]+'。'+f.after);return yes(f.after+'〔节令配方已记入菜谱，收到稻米 ×3〕');};
  C.chapter=(s,season,choice)=>{if(!D.seasonChapters[season]||![0,1].includes(choice))return no('请选择一个回应。');const key=C.calendar(s).year+'-'+season;if(s.chapters[key]!==undefined)return no('这一页已经写好，可以在旧事回看中再次阅读。');if(s.day%112<season*28)return no('等这一季来到，故事自然会发生。');s.chapters[key]=choice;const c=D.seasonChapters[season];track(s,c.title+'：'+c.choices[choice]);return yes('记下了你的选择。日子没有唯一的标准答案，生活目标都可以延后完成。');};
  C.smallEvent=(s,kind,choice=0)=>{const key=kind+'-'+dayKey(s);if(s.seasonEvents[key])return no('这周已经留下了这段小聚，下周再来。');if(!['tea','repair','stage','lost'].includes(kind))return no('暂时没有这场小聚。');if(kind==='stage'&&!s.projects.stage)return no('先把旧戏台整理好。');s.seasonEvents[key]=true;const n={tea:'zhou',repair:'song',stage:'jiang',lost:'lan'}[kind];s.relations[n].points=Math.min(100,s.relations[n].points+5+(s.skills.social.choice==='together'?3:0));xp(s,'social',3);const text={tea:'围坐喝了一壶茶，聊到今天山路上的风。',repair:'和宋伯整理了修理摊，也学会了更顺手地握工具。',stage:'江桂珍唱起小调，你为身边的人轻轻打拍子。',lost:'小岚在长椅边找到了画本，认真向帮忙的人道谢。'}[kind];track(s,text);return yes(text);};
  C.buyRecipe=(s,id)=>{const r=D.recipes.find(r=>r.id===id);if(!r||s.knownRecipes.includes(id))return no('这份菜谱已经会了。');if(!C.market(s).open&&r.source!=='market')return no('每周第 6 天的赶集摊位会带来这份配方，也能找对应村民请教。');if(s.money<35)return no('手写配方需要 35 元，也可以通过试做或邻里学习。');s.money-=35;unlock(s,id);return yes('配方已经放进生活簿，随时能翻看。');};
  C.mail=(s,id)=>{const m=s.letters.find(m=>m.id===id);if(!m)return no('没有这封信。');if(s.mailRead.includes(id))return no('这封信已经好好收好了。');s.mailRead.push(id);if(m.gift)for(const[k,v]of Object.entries(m.gift))C.add(s,k,v);return yes('收好了'+m.from+'的信'+(m.gift?'和随信的小礼物。':'。'));};
  C.claimAchievement=(s,id)=>{const a=D.achievements.find(a=>a.id===id);if(!a||s.achievements.includes(id)||(s.stats[a.stat]||0)<a.target)return no('这页记录还没有完成，或纪念物已经领过。');s.achievements.push(id);s.furniture[a.reward]=(s.furniture[a.reward]||0)+1;return yes('纪念物：'+D.furniture[a.reward].name+'。无需全收集，也能迎接年度结尾。');};
  C.favor=(s,id)=>{const f=D.favors.find(v=>v.id===id);if(!f||s.seasonEvents['favor-'+id])return no('这份帮助已经记下了。');if(id===2&&s.scene!=='town')return no('先到集镇，再替许婶照看摊位。');if(!C.has(s,f.needs))return no('还缺一点材料，可以备好后再来。');C.consume(s,f.needs);for(const[k,n]of Object.entries(f.reward))C.add(s,k,n);s.money+=f.money;s.stats.earned+=f.money;s.seasonEvents['favor-'+id]=true;s.relations[f.npc].points=Math.min(100,s.relations[f.npc].points+8);if(id===2)s.minutes=Math.min(1320,s.minutes+30);xp(s,'social',4);track(s,'帮邻居完成：'+f.title+'。');return yes('这点帮助派上用场了，收下回礼和 '+f.money+' 元。');};
  C.npcScene=(s,n)=>{const cal=C.calendar(s);if(s.marriage.spouse===n.id&&(s.minutes<480||s.minutes>=1200))return 'farm';if(s.minutes>=1080)return n.home;if(n.tier==='child'&&s.minutes<900&&s.day%7<5)return 'town';if(['雨','台风','寒潮'].includes(C.weather(s.day)))return ['bamboo','river','mountain'].includes(n.home)?'town':n.home;if(C.market(s).open&&s.minutes>=600&&s.minutes<1020)return 'town';if(s.minutes>=900&&s.minutes<1080&&['lin','an','yu','ning'].includes(n.id))return cal.season===3?'town':'river';return n.home;};
  C.nextDay=s=>{
    const w=C.weather(s.day),nextW=C.weather(s.day+1),rain=['雨','台风'].includes(w),auto=s.upgrades.irrigation&&(w!=='高温'&&w!=='台风'||s.waterReserve>0);
    s.plots.forEach((p,i)=>{if(p.crop){const c=D.crops[p.crop],watered=p.watered||rain||auto;let rate=watered?1:.35;if(w==='寒潮'&&!s.greenhouse)rate*=.7;if(p.pest)rate*=.85;const matched=s.layouts.some(v=>v.id==='trellis'&&c.group==='叶菜'||v.id==='waterbed'&&['rice','lotus'].includes(p.crop)||v.id==='orchard'&&['lettuce','spinach'].includes(p.crop));if(matched)rate+=.1;p.growth=Math.min(c.days,p.growth+rate);if(watered)p.care=Math.min(30,p.care+1);if(s.day>7&&s.day%23===0&&i===s.day%24&&!s.layouts.some(v=>v.id==='scarecrow'))p.pest=true;}else p.soil=Math.min(2,p.soil+.25);p.watered=['雨','台风'].includes(nextW)||!!s.upgrades.irrigation&&(nextW!=='高温'&&nextW!=='台风'||s.waterReserve>0);});
    if(auto&&['高温','台风'].includes(w))s.waterReserve=Math.max(0,s.waterReserve-1);
    s.animals.forEach(a=>{if(!a.fed&&s.upgrades.coop&&C.has(s,{feed:1})){C.consume(s,{feed:1});a.fed=true;}if(a.fed){const extra=s.freeRange&&s.layouts.some(v=>v.id==='orchard')&&a.bond>=30&&s.day%3===0?1:0;a.ready=Math.min(7,a.ready+1+extra);}a.fed=false;});
    s.day++;s.minutes=390;s.stamina=100;s.scene='farm';s.player={x:911,y:500,direction:'down'};
    s.processing=s.processing.filter(p=>{if(p.readyDay>s.day)return true;if(p.station==='晾晒架'&&['雨','台风'].includes(w)){p.readyDay=s.day+1;return true;}C.add(s,p.id,p.qty);if(p.cooking!==false)s.stats.cooked+=p.qty;track(s,D.items[p.id].name+'加工完成，已放入背包。');return false;});
    const c=C.calendar(s),seasonKey=c.year+'-'+c.season;
    if(c.date===1)s.letters.unshift({id:'season-'+seasonKey,day:s.day,from:'禾溪邻里',title:D.seasonChapters[c.season].title,text:D.seasonChapters[c.season].goal+' 错过也能在生活簿补看补做。',gift:{feed:3}});
    if(s.day%7===0){const known=D.npcs.filter(n=>s.relations[n.id].points>=30),n=known[dayKey(s)%Math.max(1,known.length)];if(n){s.letters.unshift({id:'visit-'+s.day,day:s.day,from:n.name,title:'有空来坐坐',text:'这一周有空就来喝茶、吃饭。忙的话晚些来也行。带两份米给你，别忘了吃饭。',gift:{rice:2}});if(s.projects.canal){s.plots.forEach(p=>p.watered=true);track(s,n.name+'顺路帮忙润湿了菜地。');}}}
    s.letters=s.letters.slice(0,150);
    if(s.day%112===0){s.flags.yearReview=true;track(s,'走过完整四季，来年继续过自己的日子。');}
    return yes('早安，'+s.name+'。今天'+nextW+'。'+C.weatherAdvice(s.day));
  };
  C.yearSummary=s=>{const focus=s.stats.harvested>s.stats.cooked*2?'一方菜地慢慢熟悉了你的脚步':s.stats.cooked>10?'许多普通食材变成了与人分享的热饭':'你给散步、相处和慢慢观察留下了时间';return [focus+'。','老院完成 '+Object.values(s.upgrades).filter(Boolean).length+' 处修缮，乡亲共同完成 '+Object.values(s.projects).filter(Boolean).length+' 项公共事务。',D.npcs.filter(n=>s.stories[n.id].step>0).length+' 位邻居把自己的故事讲给了你。',s.marriage.spouse?'和'+D.npcs.find(n=>n.id===s.marriage.spouse).name+'组成了家，也保留着各自的工作和朋友。':'有人陪你吃饭，也有独处的晚上；怎样生活都值得认真。','爷爷的旧柜里收好 '+s.archives.length+' 件生活记录。未做完的事仍能延后，不按钱或全收集给日子评分。'];};
  C.yearPlan=(s,choice)=>{if(![0,1,2].includes(choice))return no('请选择自己的想法。');s.yearPlans[C.calendar(s).year-1]=choice;track(s,'来年的想法：'+['继续照看小院，也常与邻居来往','把手艺和饭桌分享给更多人','留一些出门看看的时间，也保留回家的路'][choice]);return yes('来年的安排已经写好。可以继续种植、社交、装修，所有未完成故事仍会等你。');};
  // Version 3 validates all persisted additions. Old saves receive defaults; corrupt new fields fail before replacing state.
  C.load=raw=>{
    let v;try{v=typeof raw==='string'?JSON.parse(raw):copy(raw);}catch(_){throw new Error('存档无法解析，请使用备份。');}
    const s=ensure(old.load(v));if(v.version<3)return s;
    const invalid=()=>{throw new Error('新增生活系统的存档字段无效，请使用备份。');};
    const number=(v,a,b)=>Number.isFinite(v)&&v>=a&&v<=b;
    const int=(v,a,b)=>Number.isInteger(v)&&number(v,a,b);
    const obj=x=>x&&typeof x==='object'&&!Array.isArray(x);
    const itemMap=x=>{if(!obj(x))invalid();const r={};for(const[k,n]of Object.entries(x)){if(!D.items[k]||!int(n,0,999999))invalid();if(n)r[k]=n;}return r;};
    s.storage=itemMap(v.storage||{});
    for(const[key,bag]of [['quality',s.bag],['storageQuality',s.storage]]){s[key]={};if(!obj(v[key]||{}))invalid();for(const[id,q]of Object.entries(v[key]||{})){if(!D.items[id]||!Array.isArray(q)||![2,3].includes(q.length)||!q.every(n=>int(n,0,999999))||q.reduce((a,b)=>a+b,0)>(bag[id]||0))invalid();s[key][id]=q;}}
    if(!Array.isArray(v.knownRecipes)||v.knownRecipes.some(id=>!D.recipes.some(r=>r.id===id)))invalid();s.knownRecipes=[...new Set(v.knownRecipes)];
    for(const n of D.npcs){const st=v.stories?.[n.id];if(st){if(!int(st.step,0,D.arcs[n.id].length)||!Array.isArray(st.choices)||st.choices.length!==st.step||st.choices.some(c=>![0,1].includes(c))||!int(st.lastDay,-1,s.day))invalid();s.stories[n.id]=copy(st);}}
    if(!obj(v.partners||{}))invalid();s.partners={};for(const[id,status]of Object.entries(v.partners||{})){if(D.npcs.find(n=>n.id===id)?.tier!=='romance'||!['friend','dating'].includes(status))invalid();s.partners[id]=status;}
    const m=v.marriage;if(!obj(m)||!(m.spouse===null||D.npcs.find(n=>n.id===m.spouse)?.tier==='romance')||!int(m.day,-1,s.day)||!obj(m.weekly)||!Array.isArray(m.memories))invalid();
    if(m.spouse&&(s.partners[m.spouse]!=='dating'||s.stories[m.spouse].step<4))invalid();s.marriage={spouse:m.spouse,day:m.day,weekly:{},memories:m.memories.filter(v=>int(v.day,0,s.day)&&['meal','visit','objects','plan'].includes(v.activity)).slice(-80)};
    for(const[k,val]of Object.entries(m.weekly))if(/^\d+-(meal|visit|objects|plan)$/.test(k)&&val===true)s.marriage.weekly[k]=true;
    for(const key of ['projects','toolUpgrades']){const valid=key==='projects'?D.projects:D.toolUpgrades;s[key]={};for(const[k,val]of Object.entries(v[key]||{})){if(!valid[k]||typeof val!=='boolean')invalid();s[key][k]=val;}}s.projects.bridge=!!s.flags.bridge;
    s.layouts=[];if(!Array.isArray(v.layouts)||v.layouts.length>24)invalid();for(const a of v.layouts){if(!D.furniture[a.id]||!int(a.slot,0,23)||s.layouts.some(x=>x.slot===a.slot))invalid();s.layouts.push({id:a.id,slot:a.slot});}s.greenhouse=s.layouts.some(v=>v.id==='greenhouse');
    s.furniture={};for(const[id,n]of Object.entries(v.furniture||{})){if(!D.furniture[id]||!int(n,0,99999))invalid();s.furniture[id]=n;}
    for(const k of Object.keys(D.skillNames)){const sk=v.skills?.[k];if(!sk||!int(sk.xp,0,99999)||!(sk.choice===null||D.skillChoices[k].some(c=>c[0]===sk.choice)))invalid();s.skills[k]=copy(sk);}
    for(const k of ['chapters','yearPlans']){s[k]={};for(const[id,c]of Object.entries(v[k]||{})){if(!(k==='chapters'?/^\d+-[0-3]$/:/^\d+$/).test(id)||!int(c,0,k==='chapters'?1:2))invalid();s[k][id]=c;}}
    s.letters=Array.isArray(v.letters)?v.letters.slice(0,150).map(m=>{if(!m||typeof m.id!=='string'||m.id.length>80||!int(m.day,0,s.day)||!['title','from','text'].every(k=>typeof m[k]==='string'&&m[k].length<2000))invalid();return {id:m.id,day:m.day,title:m.title,from:m.from,text:m.text,...(m.gift?{gift:itemMap(m.gift)}:{})};}):[];
    s.mailRead=Array.isArray(v.mailRead)?[...new Set(v.mailRead.filter(k=>typeof k==='string'&&k.length<80))].slice(-20000):[];
    for(const[k,valid]of [['archives',D.archives],['achievements',D.achievements]]){if(!Array.isArray(v[k])||v[k].some(id=>!valid.some(a=>a.id===id)))invalid();s[k]=[...new Set(v[k])];}
    if(!v.appearance||!['shirt','hair','skin'].every(k=>int(v.appearance[k],0,k==='skin'?2:3)))invalid();s.appearance={shirt:v.appearance.shirt,hair:v.appearance.hair,skin:v.appearance.skin,hat:v.appearance.hat!==false};
    if(!v.pet||!['cat','dog'].includes(v.pet.type)||typeof v.pet.name!=='string'||!number(v.pet.bond,0,100)||!int(v.pet.patted,-1,s.day))invalid();s.pet={type:v.pet.type,name:v.pet.name.slice(0,12)||'小团',bond:v.pet.bond,patted:v.pet.patted};
    s.waterReserve=int(v.waterReserve,0,3)?v.waterReserve:0;s.freeRange=v.freeRange!==false;s.buffs={laborDay:int(v.buffs?.laborDay,-1,s.day)?v.buffs.laborDay:-1};
    for(const k of ['seasonEvents','animalCare','lastGifts','resourcePressure']){if(!obj(v[k]||{})||Object.keys(v[k]||{}).length>20000)invalid();s[k]={};}
    for(const[k,val]of Object.entries(v.seasonEvents||{})){
      const meal=/^meal-(\d+)-([a-zA-Z]+)$/.exec(k);
      const valid=/^(tea|repair|stage|lost)-\d+$/.test(k)||/^festival-\d+-[0-3]$/.test(k)||/^favor-[0-3]$/.test(k)||(meal&&D.npcs.some(n=>n.id===meal[2]));
      if(valid&&(typeof val==='boolean'||int(val,0,1)))s.seasonEvents[k]=val;
    }
    for(const[k,val]of Object.entries(v.animalCare||{}))if(/^(hen|duck|cow)-(clean|pet)$/.test(k)&&int(val,0,s.day))s.animalCare[k]=val;
    for(const[k,id]of Object.entries(v.lastGifts||{}))if(s.relations[k]&&D.items[id])s.lastGifts[k]=id;
    for(const[k,val]of Object.entries(v.resourcePressure||{}))if(Object.hasOwn(D.scenes,k)&&int(val.day,0,s.day)&&int(val.count,0,99))s.resourcePressure[k]={day:val.day,count:val.count};
    s.eventLog=Array.isArray(v.eventLog)?v.eventLog.filter(e=>e&&int(e.day,0,s.day)&&typeof e.text==='string').slice(0,200).map(e=>({day:e.day,text:e.text.slice(0,600)})):[];
    s.processing=Array.isArray(v.processing)?v.processing.map(p=>{if(!p||!D.items[p.id]||!int(p.qty,1,400)||!int(p.readyDay,s.day,s.day+3)||!['晾晒架','腌菜坛','堆肥箱'].includes(p.station)&&p.id!=='pickles')invalid();return {id:p.id,qty:p.qty,readyDay:p.readyDay,station:p.station||'腌菜坛',cooking:p.cooking!==false,...(p.farmGrade!==undefined?(int(p.farmGrade,1,3)?{farmGrade:p.farmGrade}:(invalid(),{})): {})};}):[];
    s.plots.forEach((p,i)=>{const prev=v.plots[i];if(!int(prev.care??0,0,30))invalid();p.care=prev.care??0;p.pest=!!prev.pest;});
    const vs=v.settings||{};for(const k of ['music','ambient','effects'])s.settings[k]=number(vs[k],0,1)?vs[k]:.35;
    s.settings.textSpeed=['instant','slow','normal'].includes(vs.textSpeed)?vs.textSpeed:'instant';s.settings.textScale=[1,1.15,1.3].includes(vs.textScale)?vs.textScale:1;s.settings.contrast=!!vs.contrast;s.settings.vibration=!!vs.vibration;s.settings.gamepad=vs.gamepad!==false;s.settings.fishAssist=vs.fishAssist!==false;
    return s;
  };
  root.ZRZCore=C;if(typeof module!=='undefined')module.exports=C;
})(typeof globalThis!=='undefined'?globalThis:window);
