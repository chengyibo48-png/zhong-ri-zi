(function(root){
  'use strict';
  const D=root.ZRZData,C=root.ZRZCore,V=root.ZRZVillage,R=root.ZRZRanch;
  const copy=x=>JSON.parse(JSON.stringify(x)),yes=msg=>({ok:true,msg}),no=msg=>({ok:false,msg}),clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
  const grades=['普通','优质','上品','珍品'];
  const extra={riceWine:['桂香米酿',108,20,'jar','加工物'],berryJam:['山果蜜酱',58,16,'jar','加工物'],cheese:['乡村鲜奶酪',86,28,'milk','加工物'],gardenSoup:['随手田园汤',26,18,'mushroomSoup','料理'],springBowl:['荠菜春笋羹',86,38,'greens','料理'],summerDrink:['山果凉饮',64,30,'milk','料理'],autumnToast:['南瓜奶香饼',155,48,'pumpkinCake','料理'],winterMilk:['芝麻暖奶',98,40,'milk','料理']};
  for(const[id,[name,price,energy,icon,kind]]of Object.entries(extra))D.items[id]={name,price,energy,icon,kind};
  const newRecipes=[['springBowl',{wildHerb:1,shoot:1},0,'清润'],['summerDrink',{berry:2,tea:1},1,'轻快'],['autumnToast',{pumpkin:1,flour:1,cream:1},2,'饱足'],['winterMilk',{milk:1,sesame:1},3,'暖胃']];
  for(const[id,ingredients,season,flavor]of newRecipes)D.recipes.push({id,ingredients,station:'灶台',source:'experiment',category:'节令食品',season,flavor,story:D.seasons[season]+'季的乡间风味；试配或做过 5 道菜后领会。'});
  const stations={
    stove:{name:'柴火灶',station:'灶台',x:240,y:315,minutes:20},steam:{name:'竹蒸笼',station:'蒸笼',x:340,y:315,minutes:35},
    mill:{name:'青石磨',station:'石磨',x:700,y:315,minutes:45},press:{name:'木梁榨油机',station:'榨油机',x:790,y:400,minutes:90},
    pickle:{name:'陶土腌菜缸',station:'腌菜坛',x:725,y:520,minutes:1440},dry:{name:'檐下烘干架',station:'晾晒架',x:240,y:530,minutes:1440},
    ferment:{name:'米酿木桶',upgrade:'kitchen',x:600,y:315,minutes:2880},dairy:{name:'乳品发酵架',upgrade:'kitchen',x:590,y:480,minutes:1440},
    preserve:{name:'小铜蜜酱锅',upgrade:'kitchen',x:390,y:390,minutes:100},compost:{name:'院边堆肥篓',station:'堆肥箱',x:340,y:530,minutes:1440}
  };
  const stationFor=name=>Object.keys(stations).find(id=>stations[id].station===name)||'stove';
  const processing=D.processingRecipes.map(r=>({...r,stationId:stationFor(r.station),out:r.id,minutes:r.days?1440:stations[stationFor(r.station)].minutes}));
  processing.push({id:'riceWine',name:'酿一桶桂香米酿',out:'riceWine',stationId:'ferment',needs:{rice:2},qty:1,minutes:2880},{id:'berryJam',name:'熬山果蜜酱',out:'berryJam',stationId:'preserve',needs:{berry:3},qty:1,minutes:100},...['cream','yogurt'].map(id=>({id,name:R.recipes[id].name,out:id,stationId:'dairy',needs:R.recipes[id].needs,qty:2,minutes:id==='cream'?45:1440})),{id:'cheese',name:'压制鲜奶酪',out:'cheese',stationId:'dairy',needs:{milk:3},qty:2,minutes:2880});
  // A useful processing margin, without multiplying crops into a runaway cash loop.
  D.items.oil.price=112;D.items.berryJam.price=58;
  const food=id=>D.items[id]&&(['食材','料理'].includes(D.items[id].kind)||['flour','oil','driedMushroom','driedFish','dryTea','cream','yogurt','cheese','riceWine','berryJam'].includes(id));
  function shelf(id){if(['riceWine','berryJam','pickles','radishPickle','driedMushroom','driedFish','dryTea','oil'].includes(id))return 28;if(['rice','wheat','peanut','sesame','flour','bean'].includes(id))return 21;if(['milk','cream','fish','shrimp','crab','perch','loach'].includes(id))return 5;if(D.items[id]?.kind==='料理'||['yogurt','cheese'].includes(id))return 7;return 12;}
  function ensure(s){
    s.kitchen??={version:1,jobs:[],nextId:1,equipment:Object.fromEntries(Object.keys(stations).map(id=>[id,{level:0,clean:100}])),lots:{bag:{},storage:{}},cold:false,mastery:{},experiments:[],buff:null};
    for(const side of ['bag','storage']){const map=s.kitchen.lots[side],bag=side==='bag'?s.bag:s.storage;for(const id of new Set([...Object.keys(bag),...Object.keys(map)])){if(!food(id)){delete map[id];continue;}const count=bag[id]||0,lots=map[id]||[],total=lots.reduce((n,l)=>n+l.qty,0);if(total<count)lots.push({qty:count-total,age:0});else if(total>count)take(lots,total-count);map[id]=lots;if(!count)delete map[id];}}
    return s.kitchen;
  }
  function take(lots,n){const moved=[];while(n>0&&lots.length){const l=lots[0],qty=Math.min(n,l.qty);moved.push({qty,age:l.age});l.qty-=qty;n-=qty;if(!l.qty)lots.shift();}return moved;}
  const now=s=>s.day*1440+s.minutes;
  function fresh(s,id,side='bag',qty=1){ensure(s);let left=qty,age=0;for(const l of s.kitchen.lots[side][id]||[]){const n=Math.min(left,l.qty);age+=n*l.age;left-=n;if(!left)break;}age/=Math.max(1,qty-left);const ratio=clamp(1-age/shelf(id),0,1);return {ratio,age,days:Math.max(0,Math.ceil(shelf(id)-age)),label:ratio>.55?'新鲜':ratio>.2?'尚可':ratio>0?'宜先用':'陈放'};}
  function sourceGrade(s,needs,n=1){let sum=0,count=0;for(const[id,num]of Object.entries(needs)){let left=num*n;count+=left;const q=s.quality[id]||[],ordinary=Math.max(0,(s.bag[id]||0)-q.reduce((a,b)=>a+b,0));left=Math.max(0,left-ordinary);for(let i=0;i<3;i++){const take=Math.min(left,q[i]||0);sum+=take*(i+1);left-=take;}}return sum/Math.max(1,count);}
  function quality(s,r,needs,n,manual=0){const f=Math.min(...Object.entries(needs).filter(([id])=>food(id)).map(([id,num])=>fresh(s,id,'bag',num*n).ratio),1),eq=s.kitchen.equipment[r.stationId||stationFor(r.station)];let grade=Math.floor(sourceGrade(s,needs,n)*.7+(f>.55?1:0)+manual+Math.min(.75,(s.kitchen.mastery[r.id]||0)*.1)+(eq?.level||0)*.25+(r.season===C.calendar(s).season?.5:0));if(f===0||eq?.clean<30)grade=Math.min(grade,1);return clamp(grade,0,3);}
  function available(s,id){const st=stations[id];return !!st&&(st.upgrade?!!s.upgrades[st.upgrade]:C.canUseStation(s,st.station));}
  function needs(s,r,sub,n){const result={...r.ingredients};if(!sub)return result;const groups={cabbage:['spinach','lettuce','bokchoy','mustard','wildHerb'],egg:['duckEgg'],fish:['perch','loach'],mushroom:['driedMushroom'],rice:['corn'],bean:['pea','broadbean']};for(const[id,q]of Object.entries(result)){if((s.bag[id]||0)>=q*n||!groups[id])continue;const alt=groups[id].find(k=>(s.bag[k]||0)>=((result[k]||0)+q)*n);if(alt){delete result[id];result[alt]=(result[alt]||0)+q;}}return result;}
  function record(s,id,qty,grade){C.add(s,id,qty);if(grade){s.quality[id]??=[0,0,0];while(s.quality[id].length<3)s.quality[id].push(0);s.quality[id][grade-1]+=qty;}s.kitchen.mastery[id]=Math.min(9999,(s.kitchen.mastery[id]||0)+1);}
  function capacity(s,id){return 5+s.kitchen.equipment[id].level*5;}
  function enqueue(s,r,n,ingredients,cooking=false){
    ensure(s);const id=r.stationId,eq=s.kitchen.equipment[id];if(!available(s,id))return no('先在修缮小院添置对应设备：'+stations[id].name+'。');
    if(!Number.isInteger(n)||n<1||n>capacity(s,id))return no('这台设备每批可做 1—'+capacity(s,id)+' 份。');
    const jobs=s.kitchen.jobs.filter(j=>j.station===id);if(jobs.length>=2+eq.level)return no('工位已满，先收取成品或升级容量。');if(!C.has(s,ingredients,n))return no('原料还没备齐。');
    const grade=quality(s,r,ingredients,n);if(!C.labor(s,2,5))return no('体力不足，歇一歇再投料。');C.consume(s,ingredients,n);
    const start=Math.max(now(s),...jobs.map(j=>j.ready)),duration=Math.ceil(r.minutes*(1-eq.level*.15));
    s.kitchen.jobs.push({key:s.kitchen.nextId++,recipe:r.id,id:r.out||r.id,qty:(r.qty||1)*n,station:id,start,ready:start+duration,grade,cooking,weatherDelay:0});eq.clean=Math.max(0,eq.clean-8*n);s.flags.firstCook||=cooking;s.skills[cooking?'cooking':'craft'].xp=Math.min(99999,s.skills[cooking?'cooking':'craft'].xp+2*n);
    return yes('已在'+stations[id].name+'投料，'+n+' 份原料合为一批，完成后走近收取。');
  }
  function start(s,id,n=1){const r=processing.find(r=>r.id===id);return r?enqueue(s,r,n,r.needs):no('没有这份加工配方。');}
  function make(s,id,n=1,sub=false,heat=null){
    ensure(s);const r=D.recipes.find(r=>r.id===id);if(!r||!s.knownRecipes.includes(id))return no('这道菜还没学会，先请教乡亲或试配。');if(!Number.isInteger(n)||n<1||n>20)return no('一次做 1—20 份。');
    const st=stationFor(r.station);if(!available(s,st)||(r.upgrade&&!s.upgrades[r.upgrade]))return no('先在修缮小院整理'+r.station+'。');if(r.season!==undefined&&r.season!==C.calendar(s).season&&s.kitchen.equipment.stove.level<2)return no('这是'+D.seasons[r.season]+'季做法；灶台升至 2 级可全年制作。');
    const ingredients=needs(s,r,sub,n);if(!C.has(s,ingredients,n))return no('食材还没备齐，替代搭配也按整批用量检查。');
    if(['腌菜坛','晾晒架'].includes(r.station))return enqueue(s,{...r,stationId:st,minutes:1440,qty:1},n,ingredients,true);
    if(heat!==null&&(!Number.isFinite(heat)||heat<0||heat>100))return no('火候读数无效。');
    const bonus=heat===null?0:heat>=35&&heat<=75?1:0,grade=quality(s,r,ingredients,n,bonus);
    if(!C.labor(s,2+Math.floor(n/5),10))return no('体力不足，歇一歇再做饭。');C.consume(s,ingredients,n);record(s,id,n,grade);s.flags.firstCook=true;s.stats.cooked+=n;s.skills.cooking.xp=Math.min(99999,s.skills.cooking.xp+3*n);s.kitchen.equipment[st].clean=Math.max(0,s.kitchen.equipment[st].clean-3);
    for(const recipe of D.recipes.filter(r=>r.source==='experiment'))if(s.stats.cooked>=5)C.unlockRecipe(s,recipe.id);
    return yes(D.items[id].name+' ×'+n+' 出锅 · '+grades[grade]+(heat===null?' · 家常快做':bonus?' · 火候恰好':' · 火候稍偏，仍是一顿热饭')+'。');
  }
  function collect(s,key){ensure(s);const i=s.kitchen.jobs.findIndex(j=>j.key===Number(key)),j=s.kitchen.jobs[i];if(!j)return no('这份成品已经收过了。');if(j.ready>now(s))return no('还在慢慢加工，稍后再来。');record(s,j.id,j.qty,j.grade);if(j.cooking)s.stats.cooked+=j.qty;s.kitchen.jobs.splice(i,1);return yes('收好'+D.items[j.id].name+' ×'+j.qty+' · '+grades[j.grade]+'。保鲜从收取日开始。');}
  function equipment(s,id,action){ensure(s);const e=s.kitchen.equipment[id];if(!e)return no('没有这个工位。');if(!available(s,id))return no('先添置这台设备。');if(action==='clean'){if(e.clean===100)return no('工位已经干净。');if(!C.labor(s,2,5))return no('体力不足。');e.clean=100;return yes('擦洗锅台、晾干器具，工位恢复干净。');}if(action!=='upgrade'||e.level>=2)return no('设备已达到最高等级。');const cost=90+e.level*110,wood=6+e.level*4;if(s.money<cost||!C.has(s,{wood,bamboo:4}))return no('升级需要 '+cost+' 元、木料 '+wood+'、竹材 4。');s.money-=cost;C.consume(s,{wood,bamboo:4});e.level++;return yes(stations[id].name+'升级：容量增加，后续加工加快，品质更稳定。');}
  function cold(s){ensure(s);if(s.kitchen.cold)return no('阴凉储藏已备好。');if(s.money<150||!C.has(s,{bamboo:6}))return no('需要 150 元与竹材 6。');s.money-=150;C.consume(s,{bamboo:6});s.kitchen.cold=true;s.upgrades.storage=true;return yes('添好阴凉食橱。储物柜食材按四分之一速度陈放，原有食材年龄保留。');}
  function category(id){if(['milk','cream','yogurt','cheese'].includes(id))return '奶香';if(['rice','wheat','flour','corn','taro'].includes(id))return '谷香';if(['berry','watermelon','pumpkin','sweetpotato'].includes(id))return '甘甜';if(['fish','shrimp','crab','egg','duckEgg','mushroom','truffle'].includes(id))return '鲜香';if(['tea','wildHerb','shoot','dryTea'].includes(id))return '清香';return '田园';}
  function experiment(s,first,second){ensure(s);if(!food(first)||!food(second)||D.items[first].kind==='料理'||D.items[second].kind==='料理')return no('选两样食材或加工原料。');const ingredients={};for(const id of [first,second])ingredients[id]=(ingredients[id]||0)+1;if(!C.has(s,ingredients))return no('所选材料不足；相同材料需要两份。');
    const r=D.recipes.find(r=>Object.keys(r.ingredients).every(k=>k===first||k===second)&&Object.keys(ingredients).every(k=>k in r.ingredients));
    if(r){C.unlockRecipe(s,r.id);return yes('闻到'+category(first)+'与'+category(second)+'，领会了'+D.items[r.id].name+'！配比已记入菜谱，原料保留。');}
    if(!C.labor(s,2,8))return no('体力不足。');const grade=quality(s,{id:'gardenSoup',station:'灶台'},ingredients,1);C.consume(s,ingredients);record(s,'gardenSoup',1,grade);s.stats.cooked++;s.flags.firstCook=true;const signature=[first,second].sort().join('+');if(!s.kitchen.experiments.includes(signature))s.kitchen.experiments.push(signature);s.kitchen.experiments=s.kitchen.experiments.slice(-40);return yes('做成一碗'+category(first)+'·'+category(second)+'田园汤，回复 18 体力。搭配已记下，可以再次制作。');
  }
  const buffFor=id=>['summerDrink','cucumberSalad'].includes(id)?'轻快':['winterMilk','milkPudding','laba'].includes(id)?'暖胃':D.recipes.find(r=>r.id===id)?.category==='田间便当'?'饱足':null;
  const activeBuff=s=>s.kitchen?.buff&&s.kitchen.buff.until>now(s)?s.kitchen.buff:null;
  const old={initial:C.initial,load:C.load,nextDay:C.nextDay,add:C.add,consume:C.consume,storage:C.storageMove,eat:C.eat,price:C.price,labor:C.labor};
  C.initial=(...a)=>{const s=old.initial(...a);ensure(s);return s;};
  C.add=(s,id,n=1)=>{ensure(s);const r=old.add(s,id,n);ensure(s);return r;};
  C.consume=(s,ns,n=1)=>{ensure(s);const r=old.consume(s,ns,n);ensure(s);return r;};
  C.storageMove=(s,id,n,to)=>{ensure(s);const source=to?'bag':'storage',dest=to?'storage':'bag',lots=copy(s.kitchen.lots[source][id]||[]),r=old.storage(s,id,n,to);if(r.ok&&food(id)){const moved=take(lots,n);s.kitchen.lots[source][id]=lots;s.kitchen.lots[dest][id]??=[];s.kitchen.lots[dest][id].push(...moved);s.kitchen.lots[dest][id].sort((a,b)=>b.age-a.age);}return r;};
  C.price=(s,id,n=1)=>Math.floor(old.price(s,id,n)*(food(id)?(.7+.3*fresh(s,id,'bag',n).ratio):1));
  C.eat=(s,id)=>{const f=food(id)?fresh(s,id).ratio:1,grade=sourceGrade(s,{[id]:1}),before=s.stamina,r=old.eat(s,id);if(r.ok){s.stamina=Math.min(100,before+Math.round((D.items[id].energy+(D.items[id].kind==='料理'&&s.skills.cooking.choice==='home'?8:0))*(.65+.35*f)+grade*3));r.msg='吃了'+D.items[id].name+'，体力回复 '+(s.stamina-before)+' 点。';ensure(s);const kind=buffFor(id);if(kind){s.buffs.laborDay=-1;s.kitchen.buff={kind,until:now(s)+180};r.msg+=' '+kind+'持续 180 游戏分钟，新料理增益替换旧增益。';}r.msg+=' 新鲜度与品质已计入回复。';}return r;};
  C.labor=(s,cost,time)=>old.labor(s,cost,time);
  C.cook=make;C.process=start;
  // Older actions use core-local inventory helpers; reconcile their pantry lots before saving.
  for(const name of ['gift','buy','gather','fish','deliver','joinFestival','upgrade','repair','talk'])if(C[name]){const action=C[name];C[name]=(...args)=>{ensure(args[0]);const result=action(...args);ensure(args[0]);return result;};}
  const oldCraft=R.craft;R.craft=(s,id,n=1)=>['cream','yogurt'].includes(id)?start(s,id,n):oldCraft(s,id,n);
  C.nextDay=s=>{ensure(s);const existing=copy(s.kitchen.lots),oldDay=s.day,w=C.weather(oldDay);for(const side of ['bag','storage'])for(const lots of Object.values(existing[side]))for(const l of lots)l.age=Math.min(3650,l.age+(side==='storage'?(s.kitchen.cold?.25:.5):1));s.kitchen.lots=existing;
    // Delay only unfinished drying; queued batches shift together, at most once per wet day.
    if(['雨','台风'].includes(w)&&s.kitchen.equipment.dry.level<2){for(const j of s.kitchen.jobs.filter(j=>j.station==='dry'&&j.ready>now(s))){j.ready+=1440;j.weatherDelay++;if(j.start>now(s))j.start+=1440;}}
    const r=old.nextDay(s);ensure(s);return r;};
  function validate(v,s){if(!v.kitchen){ensure(s);return;}const k=v.kitchen,bad=()=>{throw new Error('厨房存档字段无效，请使用备份。');},num=(x,a,b)=>Number.isFinite(x)&&x>=a&&x<=b,int=(x,a,b)=>Number.isInteger(x)&&num(x,a,b),obj=x=>x&&typeof x==='object'&&!Array.isArray(x);if(k.version!==1||!int(k.nextId,1,1e9)||typeof k.cold!=='boolean'||!obj(k.equipment)||!obj(k.mastery)||!obj(k.lots)||!Array.isArray(k.jobs)||k.jobs.length>40||!Array.isArray(k.experiments)||k.experiments.length>40)bad();
    for(const id of Object.keys(stations)){const e=k.equipment[id];if(!e||!int(e.level,0,2)||!num(e.clean,0,100))bad();}
    const keys=new Set();for(const j of k.jobs){if(!obj(j)||!int(j.key,1,k.nextId-1)||keys.has(j.key)||!D.items[j.id]||!stations[j.station]||!int(j.qty,1,400)||!int(j.grade,0,3)||!num(j.start,0,1e12)||!num(j.ready,j.start,1e12)||!int(j.weatherDelay,0,999999)||typeof j.cooking!=='boolean'||!(processing.some(r=>r.id===j.recipe&&r.out===j.id&&r.stationId===j.station)||D.recipes.some(r=>r.id===j.recipe&&r.id===j.id&&stationFor(r.station)===j.station)))bad();keys.add(j.key);}
    for(const side of ['bag','storage']){if(!obj(k.lots[side]))bad();for(const[id,lots]of Object.entries(k.lots[side])){if(!food(id)||!Array.isArray(lots)||lots.length>5000||lots.some(l=>!obj(l)||!int(l.qty,1,999999)||!num(l.age,0,3650))||lots.reduce((n,l)=>n+l.qty,0)>(s[side][id]||0))bad();}}
    for(const[id,n]of Object.entries(k.mastery))if(!D.items[id]||!int(n,0,9999))bad();for(const e of k.experiments)if(typeof e!=='string'||e.length>100||e.split('+').length!==2||!e.split('+').every(food))bad();if(k.buff&&(!['轻快','暖胃','饱足'].includes(k.buff.kind)||!num(k.buff.until,0,1e12)))bad();s.kitchen=copy(k);ensure(s);
  }
  C.load=raw=>{const v=typeof raw==='string'?JSON.parse(raw):copy(raw),s=old.load(v);validate(v,s);return s;};
  const house=()=>V.houses.find(h=>h.name==='禾溪小灶');
  function point(s,station='stove'){const h=house(),st=stations[station]||stations.stove;return {id:'kitchen-'+station,kind:'kitchen-station',name:st.name,station,house:h.id,x:st.x,y:st.y};}
  function perform(s,t){return t.op==='process'?start(s,t.id,t.n):t.op==='collect'?collect(s,t.id):['clean','upgrade'].includes(t.op)?equipment(s,t.id,t.op):t.op==='experiment'?experiment(s,t.id,t.second):make(s,t.id,t.n,t.op==='sub');}
  // Preview the exact transaction on a private copy; arrival runs it again on current resources.
  const preview=(s,t)=>perform(copy(s),t);
  root.ZRZKitchen={ensure,stations,processing,grades,food,shelf,fresh,quality,needs,available,capacity,now,make,start,collect,equipment,cold,category,experiment,buffFor,activeBuff,house,point,stationFor,perform,preview};
})(typeof window!=='undefined'?window:globalThis);
