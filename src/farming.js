(function(root){
'use strict';
const C=root.ZRZCore,D=root.ZRZData,V=root.ZRZVillage;
const clamp=(n,a=0,b=100)=>Math.max(a,Math.min(b,n)),copy=v=>JSON.parse(JSON.stringify(v)),yes=msg=>({ok:true,msg}),no=msg=>({ok:false,msg});
const soils={loam:{name:'壤土',evap:15,color:'#98724e'},sand:{name:'沙壤土',evap:23,color:'#bfa070'},clay:{name:'黏土',evap:9,color:'#826653'},humus:{name:'腐殖土',evap:13,color:'#665546'},wetland:{name:'水田土',evap:6,color:'#697765'}};
const grades=['普通','优质','上品','珍品'],kinds={normal:{name:'普通种',cap:2,rate:1,resist:0},heirloom:{name:'乡传良种',cap:3,rate:.92,resist:10},seasonal:{name:'节令种',cap:2,rate:1.14,resist:5}};
const facilities={
 sprinkler:{name:'竹管喷灌',radius:72,cost:70,needs:{wood:4,bamboo:6},description:'水分低于阈值时，每块消耗 1 格储水；补到 65。'},
 greenhouse:{name:'小暖棚',radius:62,cost:220,needs:{wood:10,bamboo:12},day:56,description:'第三季起可建；覆盖内可反季种植，挡寒潮。'},
 scarecrow:{name:'草帽稻草人',radius:110,cost:35,needs:{wood:3},description:'防成熟作物被鸟啄；不能治疗病虫害。'},
 shade:{name:'竹篾遮阳网',radius:72,cost:60,needs:{bamboo:6},description:'高温减蒸发、护叶；普通晴天稍慢。'},
 fence:{name:'田边矮篱',radius:68,cost:40,needs:{wood:5},description:'护住东坡幼苗，减少小动物踩踏。'},
 trellis:{name:'瓜豆攀爬架',radius:52,cost:45,needs:{bamboo:5},description:'瓜豆攀援加速；下层叶菜获得微荫。'},
 drain:{name:'浅沟排水渠',radius:70,cost:50,needs:{wood:3},description:'雨后将积水缓缓排至安全水分。'}
};
for(const[id,c]of Object.entries(D.crops)){
 for(const kind of ['heirloom','seasonal'])D.items[id+'_'+kind]={...D.items[c.seed],name:c.name+'·'+kinds[kind].name,cost:Math.ceil(c.cost*(kind==='heirloom'?2.8:1.5)),price:Math.max(1,Math.floor(c.cost/2)),kind:'种子',icon:'seed'};
}
Object.assign(D.items,{slowFertilizer:{name:'草木缓释肥',kind:'材料',icon:'bag',cost:20,price:8},bioCare:{name:'草本护苗液',kind:'材料',icon:'bottle',cost:14,price:5},plantCare:{name:'速效护苗剂',kind:'材料',icon:'bottle',cost:22,price:8}});
const seedId=(id,kind='normal')=>kind==='normal'?D.crops[id].seed:id+'_'+kind;
function profile(id){const c=D.crops[id],wet=['rice','lotus','taro'].includes(id),rootCrop=c.group==='根菜',climber=['bean','pea','broadbean','cucumber','pumpkin','wintermelon'].includes(id);return {wet,climber,preferred:wet?'wetland':rootCrop?'sand':c.group==='叶菜'?'humus':'loam',low:wet?55:rootCrop?28:35,high:wet?95:78,feed:c.group==='豆类'?-2:c.group==='果实'?6:4};}
function fresh(p){return {type:'loam',fertility:clamp(p.soil*50),moisture:p.watered?65:45,health:100,pests:p.pest?20:0,disease:0,weeds:0,stress:0,ripeDays:0,kind:'normal',density:'balanced',compacted:0,fallow:false,removed:false,condition:75,ticks:0,fertilized:-1,treated:-1,slow:0,penalty:0,companion:null,irrigated:-1};}
function ensure(s){if(!s.farm)s.farm={version:1,beds:s.plots.map(fresh),facilities:[],water:0,threshold:40,seedKind:'normal',density:'balanced',autoSeed:false,overlay:false,collection:{}};return s.farm;}
function sync(s,i){const b=ensure(s).beds[i],p=s.plots[i];p.soil=b.fertility/50;p.watered=b.moisture>=35;p.pest=b.pests>=15||b.disease>=15;}
function coverage(s,i){const a=V.plotPosition(i);return ensure(s).facilities.filter(f=>f.durability>0&&f.enabled&&Math.hypot(a.x-V.plotPosition(f.anchor).x,a.y-V.plotPosition(f.anchor).y)<=(root.ZRZTools?root.ZRZTools.radius(f):facilities[f.type].radius));}
const covered=(s,i,type)=>coverage(s,i).some(f=>f.type===type);
function compatible(a,b){if(a===b)return -1;const x=D.crops[a],y=D.crops[b];if(x.group===y.group)return -1;if(x.group==='豆类'||y.group==='豆类')return 1;if(x.group==='叶菜'&&y.group==='根菜'||y.group==='叶菜'&&x.group==='根菜')return 1;return 0;}
function neighbors(s,i){const p=V.plotPosition(i);return s.plots.map((_,j)=>j).filter(j=>j!==i&&Math.hypot(p.x-V.plotPosition(j).x,p.y-V.plotPosition(j).y)<63);}
function relation(s,i){const p=s.plots[i],b=ensure(s).beds[i];if(!p.crop)return 0;const ids=neighbors(s,i).map(j=>s.plots[j].crop).filter(Boolean);if(b.companion)ids.push(b.companion.crop);return clamp(ids.reduce((v,id)=>v+compatible(p.crop,id),0),-2,2);}
function stage(s,i){const p=s.plots[i],b=ensure(s).beds[i];if(b.removed)return '待修复地';if(b.fallow)return '休耕养地';if(!p.tilled)return '荒地';if(!p.crop)return b.compacted>55?'板结待松土':'待播种';if(b.health<22)return '萎蔫·可抢救';if(p.growth>=D.crops[p.crop].days)return b.ripeDays>=4?'留种期':'成熟';const k=p.growth/D.crops[p.crop].days;return k<.12?'种子':k<.28?'萌芽':k<.48?'幼苗':k<.72?'生长期':'开花结实';}
function score(s,i){const b=ensure(s).beds[i],p=s.plots[i];return clamp(b.condition*.65+b.health*.25+b.fertility*.1+(b.type===profile(p.crop).preferred?4:0)-Math.max(0,b.ripeDays-3)*4-b.penalty);}
function grade(s,i){const b=ensure(s).beds[i],v=score(s,i);return Math.min(kinds[b.kind].cap,v>=92?3:v>=78?2:v>=58?1:0);}
function preview(s,i){const p=s.plots[i],b=ensure(s).beds[i];if(!p.crop)return null;return {grade:grade(s,i),qty:Math.max(1,(b.fertility>=60?2:1)+(b.density==='dense'&&b.health>=70?1:0)-(b.pests+b.disease>=100?1:0)),seed:seedId(p.crop,b.health>=75&&grade(s,i)>=2?'heirloom':b.kind)};}
function advice(s,i){const p=s.plots[i],b=ensure(s).beds[i],out=[];if(b.removed)return ['松土修复后可重新使用'];if(b.fallow)return ['每天恢复肥力，随时结束休耕'];if(!p.tilled)return ['开垦消耗 3 体力'];if(p.crop&&p.growth>=D.crops[p.crop].days)out.push('可收获；成熟后 3 天为最佳采收期');if(b.health<35)out.push('先补水／排水并护苗，仍能救回');if(b.moisture<(p.crop?profile(p.crop).low:35))out.push('缺水：浇一壶，喷灌也可补水');if(b.moisture>(p.crop?profile(p.crop).high:85))out.push('偏涝：开沟排水，暂缓浇水');if(b.pests>=15)out.push('虫害 '+Math.round(b.pests)+'：人工捉虫或草本护苗');if(b.disease>=15)out.push('叶斑 '+Math.round(b.disease)+'：疏水并用护苗液');if(b.weeds>35)out.push('杂草争肥：拔草可改善');if(b.fertility<40)out.push('肥力低：堆肥、豆类轮作或休耕');if(b.compacted>55)out.push('土壤板结：空地深耕');if(p.repeats>=2)out.push('连作压力：下一茬换科或休耕');if(p.crop&&relation(s,i)<0)out.push('邻田同科竞争，混种豆类／根叶搭配更合适');if(p.crop&&!D.crops[p.crop].seasons.includes(C.calendar(s).season)&&!covered(s,i,'greenhouse'))out.push('当前非适季：露地生长减慢，可添小暖棚');if(!out.length)out.push('长势安稳，可以放心去村里走走');return out;}
function addQuality(s,id,n,g){C.add(s,id,n);if(g){s.quality[id]??=[0,0,0];while(s.quality[id].length<3)s.quality[id].push(0);s.quality[id][g-1]+=n;}}
function pay(s,cost,needs={},money=0){if(s.money<money)return no('零钱不足，需要 '+money+' 元。');if(!C.has(s,needs))return no('材料不足：'+Object.entries(needs).map(([id,n])=>D.items[id].name+' ×'+n).join('、'));if(!C.labor(s,cost,5))return no('体力不足，先歇一会儿。');C.consume(s,needs);s.money-=money;return null;}
function perform(s,i,action,arg){const previous=s._laborTool;s._laborTool=['hoe','restore','deep'].includes(action)?'hoe':['water','drain'].includes(action)?'water':null;try{return performAction(s,i,action,arg);}finally{if(previous===undefined)delete s._laborTool;else s._laborTool=previous;}}
function performAction(s,i,action,arg){
 const f=ensure(s),p=s.plots[i],b=f.beds[i];if(!p||!b)return no('这块地不存在。');let err;
 const done=msg=>{sync(s,i);if(s.skills)s.skills.farming.xp=Math.min(99999,s.skills.farming.xp+1);return yes(msg);};
 if(action==='hoe'||action==='restore'){if(p.crop)return no('先收下作物再松土。');if(p.tilled&&!b.removed&&!b.fallow)return no('已经松好土，可选择深耕或播种。');if(err=pay(s,3))return err;p.tilled=true;b.removed=false;b.fallow=false;b.compacted=Math.max(0,b.compacted-25);return done('挥锄松土，地块可以播种了。');}
 if(!p.tilled||b.removed)return no('先挥锄开垦或修复这块地。');
 if(action==='sow'||action==='companion'){
  const id=arg?.crop||s.seed,kind=arg?.kind||f.seedKind,c=D.crops[id],density=arg?.density||f.density;
  if(!Object.hasOwn(D.crops,id)||!Object.hasOwn(kinds,kind)||!['sparse','balanced','dense'].includes(density))return no('请选择有效种子与密度。');
  if(action==='sow'&&p.crop)return no('这里已经种下作物。');if(action==='companion'&&(!p.crop||b.companion))return no('主作物旁可套种一株。');
  if(action==='companion'&&compatible(p.crop,id)<0)return no('同科争肥，不适合在同一块地套种。换豆类或根叶搭配试试。');
  if(!c.seasons.includes(C.calendar(s).season)&&!(covered(s,i,'greenhouse')&&kind!=='seasonal'))return no('这个季节不适种；普通种与乡传良种可在小暖棚覆盖内播种。');
  if(err=pay(s,2,{[seedId(id,kind)]:density==='dense'&&action==='sow'?2:1}))return err;
  if(action==='companion'){b.companion={crop:id,growth:0,kind};return done('在垄旁套种'+c.name+'，成熟后可单独收下。');}
  p.crop=id;p.growth=0;b.kind=kind;b.density=density;b.health=100;b.stress=0;b.ripeDays=0;b.condition=75;b.ticks=0;b.penalty=0;b.fallow=false;return done('播下'+c.name+'·'+kinds[kind].name+'，'+(density==='dense'?'密植需多留意通风。':'留好株距，慢慢等它长大。'));
 }
 if(action==='water'){if(b.moisture>=95)return no('已经积水，先排水。');if(err=pay(s,2))return err;b.moisture=clamp(b.moisture+30);if(b.moisture>=40&&b.moisture<=85)b.health=clamp(b.health+8);return done('水沿田垄渗下，水分 '+Math.round(b.moisture)+' / 100'+(b.moisture>85?'，偏湿，暂缓再浇。':'。'));}
 if(action==='drain'){if(b.moisture<=60)return no('这块地暂时无需排水。');if(err=pay(s,2))return err;b.moisture=Math.max(55,b.moisture-30);b.health=clamp(b.health+5);return done('疏通小沟，积水缓缓流走。');}
 if(action==='fertilize'||action==='slow'||action==='green'){
  if(b.fertilized===s.day||b.slow>0&&action==='slow')return no('今天已有肥效，不必重复施肥。');
  if(action==='green'&&p.crop)return no('绿肥翻埋需要空地。');if(b.fertility>=95)return no('土壤肥沃，暂时不用再施肥。');
  const needs=action==='fertilize'?{compost:1}:action==='slow'?{slowFertilizer:1}:{beanSeed:1};
  if(err=pay(s,2,needs))return err;b.fertility=clamp(b.fertility+(action==='fertilize'?25:action==='green'?18:8));b.slow=action==='slow'?5:b.slow;b.fertilized=s.day;b.compacted=clamp(b.compacted-10);return done(action==='slow'?'缓释肥将在五天内慢慢养地。':'把有机肥轻轻拌进土里。');
 }
 if(action==='weed'){if(b.weeds<10)return no('田垄很干净。');if(err=pay(s,2))return err;b.weeds=0;return done('拔掉杂草，根须终于有了空间。');}
 if(['manual','bio','agent'].includes(action)){
  if(b.pests<1&&b.disease<1)return no('暂时没有病虫害，不必用药。');if(b.treated===s.day)return no('今天已处理过，明早再观察。');
  if(action==='manual'&&b.pests<1)return no('人工捉虫不能消除叶斑，请使用草本护苗液。');
  if(err=pay(s,action==='manual'?3:2,action==='bio'?{bioCare:1}:action==='agent'?{plantCare:1}:{}))return err;
  b.pests=clamp(b.pests-(action==='manual'?45:action==='bio'?35:80));if(action!=='manual')b.disease=clamp(b.disease-(action==='bio'?40:80));
  b.health=clamp(b.health+15);b.treated=s.day;if(action==='agent')b.penalty=clamp(b.penalty+8);return done(action==='agent'?'病叶与小虫得到控制；本茬品质评分 -8。':'仔细护好叶片，明天再看长势。');
 }
 if(['deep','fallow','remove','soil'].includes(action)){
  if(action==='soil'&&!Object.hasOwn(soils,arg))return no('请选择有效土质。');
  if(p.crop||b.companion)return no('请先收下作物，土地调整不会替你销毁庄稼。');
  if(err=pay(s,action==='deep'?4:2,action==='soil'?{compost:2}:{},action==='soil'?20:0))return err;
  if(action==='deep'){b.compacted=0;b.fertility=clamp(b.fertility+5);return done('深翻晒土，板结松开了。');}
  if(action==='fallow'){b.fallow=!b.fallow;return done(b.fallow?'铺好草屑，让土地休息。':'结束休耕，可以重新播种。');}
  if(action==='remove'){b.removed=true;p.tilled=false;return done('撤去田垄，保留土壤；随时可以修复。');}
  b.type=arg;return done('换入'+soils[arg].name+'，适种偏好已更新。');
 }
 if(action==='companionHarvest'){
  const a=b.companion;if(!a||a.growth<D.crops[a.crop].days)return no('套种作物还没成熟。');if(err=pay(s,2))return err;const g=Math.min(grade(s,i),kinds[a.kind].cap);addQuality(s,a.crop,1,g);s.stats.harvested++;const name=D.crops[a.crop].name;b.companion=null;return done('摘下垄旁的'+name+' ×1 · '+grades[g]+'。');
 }
 if(action==='harvest'||action==='seedSave'){
  if(!p.crop||p.growth<D.crops[p.crop].days)return no('还没到成熟时候。');if(err=pay(s,2))return err;
  const id=p.crop,c=D.crops[id],r=preview(s,i);let msg;
  if(action==='seedSave'){const n=(b.health>=60?2:1)+(b.health>=75&&b.ripeDays>=4&&b.ripeDays<=8?1:0);C.add(s,r.seed,n);msg='挑选饱满种子 ×'+n+'，收进种子袋。';}
  else {addQuality(s,id,r.qty,r.grade);s.stats.harvested+=r.qty;s.flags.firstHarvest=true;f.collection[id]=Math.max(f.collection[id]||0,r.grade+1);msg='收下'+c.name+' ×'+r.qty+' · '+grades[r.grade]+'。';if(f.autoSeed){C.add(s,seedId(id,b.kind),1);msg+=' 留了一份原品种种子。';}}
  p.repeats=p.lastGroup===c.group?p.repeats+1:1;p.lastGroup=c.group;b.fertility=clamp(b.fertility+(c.group==='豆类'?14:-5));p.crop=null;p.growth=0;b.ripeDays=0;b.ticks=0;
  if(b.companion){p.crop=b.companion.crop;p.growth=b.companion.growth;b.kind=b.companion.kind;b.companion=null;b.density='sparse';msg+=' 套种作物继续生长。';}
  return done(msg);
 }
 return no('请选择农事动作。');
}
function daily(s,day){
 const env=root.ZRZEnvironment?.profile(day),f=ensure(s),weather=C.weather(day),season=C.calendar({day}).season,rain=['雨','台风'].includes(weather),prior=f.beds.map(b=>({pests:b.pests,disease:b.disease}));
 for(let i=0;i<s.plots.length;i++){
  const p=s.plots[i],b=f.beds[i],types=new Set(coverage(s,i).map(v=>v.type)),has=k=>types.has(k),crop=p.crop?profile(p.crop):null;
  if(!p.tilled||b.removed){b.fertility=clamp(b.fertility+1);sync(s,i);continue;}
  b.moisture=clamp(b.moisture+(env?env.rain:rain?(weather==='台风'?48:34):0)-soils[b.type].evap*(env?env.evaporation:weather==='高温'?1.5:1)*(has('shade')?.65:1));
  if(has('drain')&&b.moisture>80)b.moisture=75;
  if(p.crop&&has('sprinkler')&&b.moisture<f.threshold&&f.water>0){f.water--;b.moisture=65;b.irrigated=s.day;}
  if(s.projects.canal&&s.day%7===0&&D.npcs.some(n=>s.relations[n.id].points>=30))b.moisture=Math.max(55,b.moisture);
  if(b.slow>0){b.fertility=clamp(b.fertility+5);b.slow--;}
  if(!p.crop){b.fertility=clamp(b.fertility+(b.fallow?9:3));b.compacted=clamp(b.compacted-3);b.pests=clamp(b.pests-8);b.disease=clamp(b.disease-8);if(b.fallow){p.repeats=Math.max(0,p.repeats-1);b.weeds=0;}sync(s,i);continue;}
  const c=D.crops[p.crop],rel=relation(s,i),dry=b.moisture<crop.low,wet=b.moisture>crop.high,off=!c.seasons.includes(season)&&!has('greenhouse'),cold=weather==='寒潮'&&!has('greenhouse'),heat=weather==='高温'&&!has('shade'),same=neighbors(s,i).filter(j=>s.plots[j].crop===p.crop).length;
  const risk=clamp(2+p.repeats*2+same*2+(b.density==='dense'?7:0)+(wet?9:0)+(heat?5:0)+(b.fertility<30?5:0)-kinds[b.kind].resist-(rel>0?4:0),0,35);
  const roll=(Math.imul(day+1,1103515245)+Math.imul(i+17,12345))>>>0;
  if(day>6&&roll%100<risk)b.pests=clamp(b.pests+14);
  if(day>6&&wet&&((roll>>>8)%100<risk))b.disease=clamp(b.disease+12);
  if(wet||b.density==='dense')for(const j of neighbors(s,i)){if(prior[j].pests>=60)b.pests=clamp(b.pests+2);if(prior[j].disease>=60)b.disease=clamp(b.disease+2);}
  b.weeds=clamp(b.weeds+(rain?5:2));b.compacted=clamp(b.compacted+(wet?3:1));
  const stress=(dry||wet?12:0)+(cold||heat||off?7:0)+(b.pests+b.disease)*.12+(b.weeds>60?5:0);
  b.health=clamp(b.health+(stress>12?-Math.min(15,stress-8):8),10,100);b.stress=stress>12?Math.min(999,b.stress+1):0;
  const condition=clamp(100-(dry||wet?28:0)-(off||cold||heat?15:0)-(b.pests+b.disease)*.25-(b.fertility<40?20:0)-(b.weeds>40?10:0)+(rel>0?3:0));
  b.condition=(b.condition*b.ticks+condition)/(b.ticks+1);b.ticks=Math.min(100000,b.ticks+1);
  let rate=(dry||wet?.55:1)*(off?.65:1)*(cold?.7:1)*(b.health<22?.25:1)*(1-(b.pests+b.disease)/400)*kinds[b.kind].rate;
  rate*=b.type===crop.preferred?1.08:1;rate*=b.density==='dense'?.94:b.density==='sparse'?1.05:1;rate*=rel>0?1.05:rel<0?.95:1;
  if(b.compacted>55)rate*=.85;if(b.fertility<25)rate*=.85;if(has('trellis')&&crop.climber)rate*=1.15;if(has('trellis')&&c.group==='叶菜'&&heat)rate*=1.1;if(has('shade')&&weather==='晴')rate*=.95;
  if(i>=24&&!has('fence')&&day%17===i%17&&p.growth<c.days*.5)b.health=clamp(b.health-6,10);
  if(!has('scarecrow')&&p.growth>=c.days&&day%13===i%13)b.penalty=clamp(b.penalty+3);
  if(p.growth>=c.days)b.ripeDays=Math.min(100000,b.ripeDays+1);else {p.growth=Math.min(c.days,p.growth+Math.max(.08,rate));b.fertility=clamp(b.fertility-crop.feed*(b.density==='dense'?1.25:1));}
  if(b.companion)b.companion.growth=Math.min(D.crops[b.companion.crop].days,b.companion.growth+rate*.9);
  sync(s,i);
 }
 for(const a of f.facilities)a.durability=clamp(a.durability-(root.ZRZTools?root.ZRZTools.decay(a,weather):(weather==='台风'?7:1)));
}
function facility(s,i,type,mode='build',target=null){const f=ensure(s),spec=facilities[type];if(!Object.hasOwn(facilities,type)||!s.plots[i])return no('请选择设施与地块。');let a=f.facilities.find(v=>v.anchor===i&&v.type===type),err;
 if(mode==='build'){if(a)return no('这里已有同类设施。');if(f.facilities.filter(v=>v.anchor===i).length>=2)return no('田埂最多放两座设施，请换一处位置。');if(spec.day&&s.day<spec.day)return no('小暖棚在第三季开放，现在可先准备木材与竹料。');const stock=(s.furniture[type]||0)>0;if(err=pay(s,3,stock?{}:spec.needs,stock?0:spec.cost))return err;if(stock)s.furniture[type]--;f.facilities.push({type,anchor:i,durability:100,enabled:true});return yes(spec.name+'安在田埂上，仅影响覆盖内的地块。');}
 if(!a)return no('没有找到这座设施。');if(mode==='move'){if(!Number.isInteger(target)||!s.plots[target]||target===i||f.facilities.filter(v=>v.anchor===target).length>=2||f.facilities.some(v=>v.anchor===target&&v.type===type))return no('目标田埂已满或位置无效。');if(err=pay(s,2))return err;a.anchor=target;return yes('把设施搬到了 '+(target+1)+' 号地旁。');}
 if(mode==='repair'){if(a.durability===100)return no('设施完好，无需维修。');if(err=pay(s,2,{wood:1},5))return err;a.durability=100;return yes('绑紧竹结，设施修好了。');}
 if(mode==='toggle'){a.enabled=!a.enabled;return yes(a.enabled?'设施已启用。':'设施已暂停。');}return no('未知设施操作。');
}
function fillWater(s){const f=ensure(s);if(f.water>=120)return no('水箱已经装满。');const err=pay(s,3,{},6);if(err)return err;f.water=120;return yes('挑水补满 120 格储水，喷灌每次照料一块消耗 1 格。');}
function list(s,filter='all',region='all',crop='all'){ensure(s);return s.plots.map((p,i)=>i).filter(i=>{const p=s.plots[i],b=s.farm.beds[i];return(region==='all'||(region==='home'?i<24:i>=24))&&(crop==='all'||p.crop===crop)&&(filter==='all'||filter==='ready'&&p.crop&&p.growth>=D.crops[p.crop].days||filter==='dry'&&p.crop&&p.tilled&&b.moisture<(p.crop?profile(p.crop).low:35)||filter==='risk'&&(b.pests>=15||b.disease>=15||p.crop&&b.health<40||p.tilled&&b.moisture>(p.crop?profile(p.crop).high:85))||filter==='empty'&&p.tilled&&!p.crop&&!b.removed);});}
function plan(s,ids,action){return [...new Set(ids)].filter(i=>{const p=s.plots[i],b=ensure(s).beds[i];if(!p||!b)return false;if(action==='harvest')return p.crop&&p.growth>=D.crops[p.crop].days;if(action==='sow')return p.tilled&&!p.crop&&!b.removed;if(action==='water')return p.crop&&p.tilled&&!b.removed&&b.moisture<(p.crop?profile(p.crop).low:35);if(action==='fertilize')return p.tilled&&b.fertility<70&&b.fertilized!==s.day;return false;}).map(index=>({index,action,arg:action==='sow'?{crop:s.seed,kind:s.farm.seedKind,density:s.farm.density}:undefined}));}
function validate(v,s){const f=v.farm;if(!f)return ensure(s);const bad=()=>{throw new Error('种植系统存档无效，请使用备份。');},num=(x,a=0,b=100)=>Number.isFinite(x)&&x>=a&&x<=b;
 if(f.version!==1||!Array.isArray(f.beds)||f.beds.length!==s.plots.length||!Array.isArray(f.facilities)||f.facilities.length>144||!num(f.water,0,120)||!num(f.threshold,20,65)||!Object.hasOwn(kinds,f.seedKind)||!['sparse','balanced','dense'].includes(f.density))bad();
 f.beds.forEach(b=>{if(!b||!Object.hasOwn(soils,b.type)||!Object.hasOwn(kinds,b.kind)||!['sparse','balanced','dense'].includes(b.density)||!['fertility','moisture','health','pests','disease','weeds','compacted','condition','penalty'].every(k=>num(b[k]))||!num(b.ripeDays,0,100000)||!num(b.ticks,0,100000)||!num(b.stress,0,999)||!num(b.slow,0,5)||!num(b.fertilized,-1,s.day)||!num(b.treated,-1,s.day)||!['removed','fallow'].every(k=>typeof b[k]==='boolean'))bad();if(b.companion&&(!Object.hasOwn(D.crops,b.companion.crop)||!Object.hasOwn(kinds,b.companion.kind)||!num(b.companion.growth,0,D.crops[b.companion.crop].days)))bad();});
 const seen=new Set();f.facilities.forEach(a=>{const k=a.anchor+'/'+a.type;if(!Object.hasOwn(facilities,a.type)||!Number.isInteger(a.anchor)||!s.plots[a.anchor]||!num(a.durability)||typeof a.enabled!=='boolean'||seen.has(k)||f.facilities.filter(v=>v.anchor===a.anchor).length>2)bad();seen.add(k);});
 if(!f.collection||typeof f.collection!=='object'||Array.isArray(f.collection))bad();for(const[id,g]of Object.entries(f.collection))if(!Object.hasOwn(D.crops,id)||!Number.isInteger(g)||g<1||g>4)bad();
 s.farm=copy(f);s.farm.autoSeed=!!f.autoSeed;s.farm.overlay=!!f.overlay;return s.farm;
}
const old={initial:C.initial,load:C.load,nextDay:C.nextDay,plot:C.plotAction,cook:C.cook,process:C.process,upgrade:C.upgrade,buy:C.buy};
C.initial=(...args)=>{const s=old.initial(...args);ensure(s);return s;};
C.load=raw=>{const v=typeof raw==='string'?JSON.parse(raw):copy(raw),s=old.load(v);validate(v,s);if(!v.farm){if(s.upgrades.irrigation){s.farm.facilities.push({type:'sprinkler',anchor:7,durability:100,enabled:true});s.farm.water=120;}for(const a of s.layouts){if(['trellis','greenhouse','scarecrow','fence'].includes(a.id)){const slot=C.layoutSlots[a.slot],anchor=s.plots.reduce((best,_,i)=>{const p=V.plotPosition(i),q=V.plotPosition(best);return Math.hypot(p.x-slot.x-1920,p.y-slot.y-1152)<Math.hypot(q.x-slot.x-1920,q.y-slot.y-1152)?i:best;},0);if(s.farm.facilities.filter(f=>f.anchor===anchor).length<2&&!s.farm.facilities.some(f=>f.anchor===anchor&&f.type===a.id))s.farm.facilities.push({type:a.id,anchor,durability:100,enabled:true});}}}s.plots.forEach((_,i)=>sync(s,i));return s;};
C.nextDay=s=>{ensure(s);const plots=copy(s.plots),jobs=s.processing.slice(),day=s.day,r=old.nextDay(s);for(const job of jobs)if(job.farmGrade&&!s.processing.includes(job)){s.quality[job.id]??=[0,0,0];while(s.quality[job.id].length<3)s.quality[job.id].push(0);s.quality[job.id][job.farmGrade-1]+=job.qty;}s.plots=plots;daily(s,day);return r;};
C.plotAction=(s,i,tool)=>['hoe','seed','water','hand'].includes(tool)?perform(s,i,{hoe:'hoe',seed:'sow',water:'water',hand:'harvest'}[tool]):old.plot(s,i,tool);
C.fertilize=(s,i)=>perform(s,i,'fertilize');C.clearPest=(s,i)=>perform(s,i,'manual');C.fillWater=fillWater;
function premiumNeeds(s,needs,n){return Object.entries(needs).every(([id,count])=>{const q=s.quality[id]||[],total=q.reduce((a,b)=>a+b,0);return total>=count*n&&(s.bag[id]||0)===total;});}
C.cook=(s,id,n=1,sub=false)=>{const recipe=D.recipes.find(r=>r.id===id),premium=recipe&&!sub&&premiumNeeds(s,recipe.ingredients,n),before=s.processing.length,r=old.cook(s,id,n,sub);if(r.ok&&premium){if(s.processing.length>before)s.processing.at(-1).farmGrade=2;else{const q=s.quality[id];if(q){while(q.length<3)q.push(0);const index=s.skills.cooking.choice==='host'?1:0;q[index]-=n;q[Math.min(2,index+1)]+=n;}}r.msg+=' 好食材让料理提升一档品质。';}return r;};
C.process=(s,id,n=1)=>{const recipe=D.processingRecipes.find(r=>r.id===id),premium=recipe&&premiumNeeds(s,recipe.needs,n),before=s.processing.length,r=old.process(s,id,n);if(r.ok&&premium){if(s.processing.length>before)s.processing.at(-1).farmGrade=1;else{s.quality[id]??=[0,0,0];s.quality[id][0]+=recipe.qty*n;}r.msg+=' 保留了原料的优质风味。';}return r;};
C.upgrade=(s,id)=>{const r=old.upgrade(s,id);if(r.ok&&id==='irrigation'){const f=ensure(s);const anchor=s.plots.findIndex((_,i)=>f.facilities.filter(a=>a.anchor===i).length<2&&!f.facilities.some(a=>a.anchor===i&&a.type==='sprinkler'));if(anchor>=0)f.facilities.push({type:'sprinkler',anchor,durability:100,enabled:true});f.water=120;r.msg+=' 配送一座局部竹管喷灌与满箱储水，可在四时农事中搬动。';}return r;};
C.buy=(s,id,n=1)=>id.endsWith('_heirloom')&&s.day<14&&s.relations.qiao.points<20?no('春十五或与沈禾熟悉后开放乡传良种。'):old.buy(s,id,n);
C.weatherAdvice=day=>({台风:'台风将带来积水并磨损设施；提前排水、修整田埂。',高温:'高温蒸发较快，可补储水或安装遮阳网。',寒潮:'寒潮会减缓露地生长，小暖棚覆盖内更稳妥。',小雪:'小雪日田里仍慢慢长，可安心做饭串门。',雨:'雨水会补水，低洼田注意排水；晒制可能顺延。'}[C.weather(day)]||'水土合适就让作物慢慢长，今日可出门走走。');
const F={ensure,soils,grades,kinds,facilities,seedId,profile,coverage,covered,compatible,neighbors,relation,stage,score,grade,preview,advice,perform,facility,fillWater,list,plan,daily};
root.ZRZFarming=F;if(typeof module!=='undefined')module.exports=F;
})(typeof window!=='undefined'?window:globalThis);

