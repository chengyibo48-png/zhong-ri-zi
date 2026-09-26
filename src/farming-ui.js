(function(root){
'use strict';
const F=root.ZRZFarming,C=root.ZRZCore,D=root.ZRZData,X=root.ZRZPanels,V=root.ZRZVillage;
const ui={index:0,filter:'all',region:'all',crop:'all',tab:'field',batch:null};
const val=id=>document.getElementById(id)?.value;
const btn=(text,action,id='',extra='')=>'<button class="mini-btn" data-action="f-'+action+'" data-id="'+id+'" '+extra+'>'+text+'</button>';
const select=(id,items,value)=>'<select id="'+id+'">'+items.map(([k,v])=>'<option value="'+k+'" '+(String(k)===String(value)?'selected':'')+'>'+v+'</option>').join('')+'</select>';
const stat=(title,value,color)=>'<div class="farm-stat"><span>'+title+'</span><strong>'+Math.round(value)+'<small> / 100</small></strong><div class="farm-meter"><i style="width:'+value+'%;background:'+color+'"></i></div></div>';
const fieldName=i=>(i<24?'小院':'东坡')+' · '+String(i+1).padStart(2,'0')+' 号田';
function seedOptions(s){return Object.entries(D.crops).map(([id,c])=>[id,c.name+' · '+(s.bag[F.seedId(id,s.farm.seedKind)]||0)+' 份']);}
function selection(s){return '<div class="farm-controls"><label>作物'+select('farm-seed',seedOptions(s),s.seed)+'</label><label>种子品种'+select('farm-kind',Object.entries(F.kinds).map(([k,v])=>[k,v.name]),s.farm.seedKind)+'</label><label>株距'+select('farm-density',[['sparse','疏植 · 快长'],['balanced','标准 · 稳妥'],['dense','密植 · 2 份种子，多一份产量']],s.farm.density)+'</label>'+btn('记住播种选择','selection')+'</div>';}
function seeds(s,head){
 let h=head('一颗种子，一季期待。','普通种最高上品；乡传良种生长稍慢、抗虫，最高珍品；节令种快长，仅适季可种。')+selection(s);
 h+='<div class="farm-seed-summary"><strong>现在选好：'+D.crops[s.seed].name+' · '+F.kinds[s.farm.seedKind].name+'</strong><span>背包 '+(s.bag[F.seedId(s.seed,s.farm.seedKind)]||0)+' 份</span>'+btn('拿起种子袋','equip')+'</div><div class="inventory-grid">';
 h+=Object.entries(D.crops).map(([id,c])=>{const inSeason=c.seasons.includes(C.calendar(s).season),k=s.farm.seedKind,item=F.seedId(id,k),locked=k==='heirloom'&&s.day<14&&s.relations.qiao.points<20;return '<article class="item-card '+(id===s.seed?'farm-selected':'')+'"><div class="item-head"><canvas data-item="'+id+'" width="40" height="40"></canvas><strong>'+c.name+'</strong><span class="tag">'+(inSeason?'当季':'非当季')+'</span></div><p>'+c.days+' 天起 · 偏爱'+F.soils[F.profile(id).preferred].name+'<br>'+c.seasons.map(v=>D.seasons[v]).join(' / ')+' · '+c.group+'</p><small>持有 '+(s.bag[item]||0)+' 份 · '+(locked?'春十五或与沈禾熟悉后可购良种':'种子 '+D.items[item].cost+' 元 / 份')+'</small><div class="button-row">'+btn('选择','seed',id)+btn('购 1 份','buy',item,locked?'disabled':'')+btn('购 5 份','buy',item,'data-qty="5" '+(locked?'disabled':''))+'</div></article>';}).join('')+'</div>';return h;
}
function field(s){const i=ui.index,p=s.plots[i],b=s.farm.beds[i],r=F.preview(s,i),st=F.stage(s,i),cover=F.coverage(s,i),crop=p.crop?D.crops[p.crop]:null;
 let h='<div class="farm-detail-title"><span class="eyebrow">'+fieldName(i)+'</span><h2>'+(crop?crop.name:'等一颗种子的土地')+'</h2><span class="tag">'+st+'</span>'+btn('走到田边','walk',i)+'</div>';
 h+='<div class="farm-stats">'+stat('土壤肥力',b.fertility,'#9caa59')+stat('根部水分',b.moisture,'#5c9eaa')+stat('植株健康',b.health,'#64896c')+'</div>';
 if(crop){const k=Math.min(100,p.growth/crop.days*100);h+='<div class="farm-growth"><div class="farm-meter"><i style="width:'+k+'%"></i></div><span>种子 → 萌芽 → 幼苗 → 生长 → 开花 → 成熟</span><p>'+Math.round(k)+'% · '+(k>=100?'最佳采收窗口剩余 '+Math.max(0,4-b.ripeDays)+' 天；过期仍可收或留种':'预计还需约 '+Math.ceil((crop.days-p.growth)/(b.health<22?.3:.85))+' 天，随水土天气调整')+'</p></div>';}
 h+='<div class="farm-advice"><strong>今天看看这里</strong><ul>'+F.advice(s,i).map(t=>'<li>'+t+'</li>').join('')+'</ul></div>';
 h+='<div class="farm-facts"><span>土质 <b>'+F.soils[b.type].name+'</b></span><span>肥力档 <b>'+(b.fertility>=75?'肥沃':b.fertility>=38?'稳定':'待养护')+'</b></span><span>虫 / 病 / 草 <b>'+Math.round(b.pests)+' / '+Math.round(b.disease)+' / '+Math.round(b.weeds)+'</b></span><span>上茬 <b>'+(p.lastGroup||'尚无')+' · 连作 '+p.repeats+'</b></span><span>设施 <b>'+(cover.map(v=>F.facilities[v.type].name).join('、')||'暂无覆盖')+'</b></span><span>季节适应 <b>'+(crop?(crop.seasons.includes(C.calendar(s).season)?'当季适种':F.covered(s,i,'greenhouse')?'暖棚保护':'非适季 · 生长减慢'):'待选择作物')+'</b></span><span>轮作建议 <b>'+(p.lastGroup==='豆类'?'叶菜或果实':'豆类、不同科作物或休耕')+'</b></span></div>';
 if(r)h+='<div class="farm-harvest-preview">采收预览 <strong>'+r.qty+' 份 · '+F.grades[r.grade]+'</strong><small>专门留种：'+((b.health>=60?2:1)+(b.health>=75&&b.ripeDays>=4&&b.ripeDays<=8?1:0))+' 份 '+D.items[r.seed].name+'。持续照料决定品质。</small></div>';
 const action=(text,a,disabled=false)=>btn(text,'task',i,'data-op="'+a+'" '+(disabled?'disabled':''));
 h+='<div class="farm-actions">'+action('挥锄开垦 · 3 力','hoe',p.tilled&&!b.removed)+action('播种 · 2 力','sow',!!p.crop||!p.tilled)+action('浇一壶 · 2 力','water',!p.tilled)+action('疏沟排水 · 2 力','drain',b.moisture<=60)+action('收获 · 2 力','harvest',!crop||p.growth<crop.days)+action('专门留种 · 2 力','seedSave',!crop||p.growth<crop.days)+'</div>';
 h+='<details class="farm-more"><summary>施肥、护苗与土地整治</summary><div class="farm-actions">'+action('熟堆肥 ×1 · 2 力','fertilize')+action('缓释肥 ×1 · 2 力','slow')+action('绿肥翻埋 · 豆种 ×1','green',!!p.crop)+action('拔草 · 2 力','weed')+action('人工捉虫 · 3 力','manual')+action('草本护苗 ×1 · 2 力','bio')+action('速效处理 ×1 · 品质 −8','agent')+action('深耕 · 4 力','deep',!!p.crop)+action(b.fallow?'结束休耕':'休耕养地 · 2 力','fallow',!!p.crop)+action('撤去空田垄 · 可修复','remove',!!p.crop)+'</div><div class="farm-controls"><label>改良土质'+select('farm-soil',Object.entries(F.soils).map(([id,v])=>[id,v.name]),b.type)+'</label>'+btn('换土 · 堆肥 ×2 +20 元','soil',i,p.crop?'disabled':'')+'</div></details>';
 h+='<details class="farm-more"><summary>套种与留种设置</summary><p>同一垄最多两种作物。豆类搭配其他科、叶菜搭配根菜有互助；同科套种会争肥，不能叠种。瓜豆攀架、架下叶菜有微荫。先收主作物后，副作物会继续长大。</p>'+selection(s)+(b.companion?'<p>垄旁：'+D.crops[b.companion.crop].name+' · '+Math.round(b.companion.growth/D.crops[b.companion.crop].days*100)+'%</p>'+action('收下套种作物','companionHarvest'):action('用选中的种子套种 · 2 力','companion',!p.crop))+btn(s.farm.autoSeed?'自动留一份种子：开':'自动留一份种子：关','auto-seed')+'</details>';return h;
}
function infrastructure(s){const i=ui.index;let h='<h2>'+fieldName(i)+' · 田埂设施</h2><p>每处田埂最多两座。只照料范围内的田块，耐久为零时停用；台风磨损更快。</p><div class="farm-controls">'+btn(s.farm.overlay?'关闭地面覆盖线':'显示地面覆盖线','overlay')+btn('储水 '+s.farm.water+' / 120 · 补满 6 元 +3 力','fill')+'<label>喷灌水分阈值'+select('farm-threshold',[[30,'低于 30'],[40,'低于 40'],[55,'低于 55'],[65,'低于 65']],s.farm.threshold)+'</label>'+btn('设置阈值','threshold')+'</div>';
 for(const[id,v]of Object.entries(F.facilities)){const a=s.farm.facilities.find(f=>f.anchor===i&&f.type===id);h+='<article class="row-card"><div class="row-text"><h3>'+v.name+' <span class="tag">覆盖 '+s.plots.filter((_,j)=>{const a=V.plotPosition(i),b=V.plotPosition(j);return Math.hypot(a.x-b.x,a.y-b.y)<=v.radius;}).length+' 块田</span></h3><p>'+v.description+'<br>'+(a?'耐久 '+a.durability+' / 100 · '+(a.enabled?'使用中':'已暂停'):((s.furniture[id]||0)>0?'使用已有家具 ×1；免材料与资金':v.cost+' 元')+' · '+Object.entries(v.needs).map(([k,n])=>D.items[k].name+' ×'+n).join('、')+(v.day?' · 第三季解锁':''))+'</p></div><div class="row-actions">'+(a?btn('修理 · 木材 ×1 +5 元','facility',i,'data-type="'+id+'" data-mode="repair"')+btn(a.enabled?'暂停':'启用','facility',i,'data-type="'+id+'" data-mode="toggle"')+'<label>搬往田号<input class="farm-target" id="move-'+id+'" type="number" min="1" max="72" value="'+(i+1)+'"></label>'+btn('搬动 · 2 力','facility',i,'data-type="'+id+'" data-mode="move"'):btn('安置 · 3 力','facility',i,'data-type="'+id+'" data-mode="build" '+(v.day&&s.day<v.day?'disabled':'')))+'</div></article>';}
 h+='<h3>已建 '+s.farm.facilities.length+' 座</h3><div class="button-row">'+s.farm.facilities.map(a=>btn(fieldName(a.anchor)+' · '+F.facilities[a.type].name,'inspect',a.anchor)).join('')+'</div>';return h;
}
function guide(s){return '<div class="farm-guide"><h2>会呼吸的田地</h2><p>松土、播种、照料、看天、采收、留种，再让土地歇一歇。成长以每天结算为准，生活簿打开时会暂停时光。</p><h3>看得见的变化</h3><p>田里的六个生长阶段会改变形态。蓝色水滴表示润湿，褐色裂纹表示干燥，黄边叶片表示萎蔫，黑色小虫／叶斑提示风险；成熟田垄会闪光。没有倒计时逼迫：失照只会拖慢生长，萎蔫可以救回，晚收也仍有收成。</p><h3>水土与轮作</h3><p>水田土适合稻、藕、芋；沙壤土适合根菜；腐殖土适合叶菜。肥力低时用熟堆肥，缓释肥分五天供肥，空地可翻埋豆种或休耕。连续同科、密植和潮湿更容易出问题。不是所有地都要每天浇水。</p><h3>四档品质</h3><p>普通 / 优质 / 上品 / 珍品，售价分别为基础的 1 / 1.2 / 1.4 / 1.7 倍。普通食材能完成原有菜谱与订单；品质随物品存取，优先消耗普通。全用优质食材做即时料理可额外提升料理一档。图鉴保留最高收获品质。</p><h3>病虫害可以缓解</h3><p>幼虫、叶斑分开记录；15 以下轻微、15—44 提醒、45—69 较重、70 以上优先照料。高密同科、连作、湿热、弱土会增加风险，严重邻田会小范围传染。人工捉虫省材料，草本护苗兼治叶斑，速效处理更强但本茬品质评分减 8。稻草人只驱鸟。</p><h3>种子与设施</h3><p>春十五或与沈禾熟悉后能买乡传良种；健康的上品收成专门留种也可得到良种；成熟后第 4—8 天、健康达到 75，专门留种多一份。节令种可直接购买。开启自动留种后，每次采收另留一份原品种种子。喷灌用水箱储水，设施仅在田埂附近生效，可以搬动、修理、暂停。</p><h3>批量照料</h3><p>先按区域、作物和状态筛选，再预览任务与材料。开始后角色逐块走到田边做动作；体力或材料不足会停止并保留已完成部分，方向键或“停止带路”可取消。</p></div>';}
function render(s,A){
 F.ensure(s);ui.index=Math.max(0,Math.min(s.plots.length-1,ui.index));const ids=F.list(s,ui.filter,ui.region,ui.crop);
 let h='<div class="farm-book">'+A.head('禾溪 · 四时农事','种下期待，照料有度。每块田都有自己的水土与节奏。');
 h+='<div class="farm-overview">'+[['ready','熟了',F.list(s,'ready').length],['dry','待补水',F.list(s,'dry').length],['risk','需留意',F.list(s,'risk').length],['all','全部田地',s.plots.length]].map(([k,t,n])=>'<button data-action="f-filter" data-id="'+k+'" class="'+(ui.filter===k?'active':'')+'"><strong>'+n+'</strong><span>'+t+'</span></button>').join('')+'</div>';
 h+='<div class="farm-forecast">'+[0,1,2].map(n=>'<span>'+(n===0?'今日':n===1?'明日':'后日')+' <b>'+C.weather(s.day+n)+'</b></span>').join('')+'<small>'+C.weatherAdvice(s.day+1)+'</small></div>';
 h+='<div class="farm-controls"><label>片区'+select('farm-region',[['all','全部田地'],['home','稻香小院 · 24 块'],['pasture','东坡新田 · 48 块']],ui.region)+'</label><label>按作物'+select('farm-crop',[['all','全部作物'],...Object.entries(D.crops).map(([id,c])=>[id,c.name])],ui.crop)+'</label>'+btn('应用筛选','filters')+btn('仅看待播地','filter','empty')+'</div>';
 h+='<div class="farm-layout"><aside class="farm-map-wrap"><div class="farm-map-head">田亩索引 <small>'+ids.length+' 块符合筛选</small></div><div class="farm-map">';
 for(let i=0;i<s.plots.length;i++){const p=s.plots[i],b=s.farm.beds[i],ready=p.crop&&p.growth>=D.crops[p.crop].days;h+='<button class="farm-cell '+(ids.includes(i)?'':'dim ')+(ui.index===i?'selected ':'')+(ready?'ready ':p.crop?'growing ':'')+'" data-action="f-inspect" data-id="'+i+'" title="'+fieldName(i)+' · '+F.stage(s,i)+'" aria-label="'+fieldName(i)+' '+F.stage(s,i)+'"><span>'+String(i+1).padStart(2,'0')+'</span><b>'+(ready?'✦':b.pests>=15||b.disease>=15?'!':p.crop?'芽':p.tilled?'田':'·')+'</b><i style="width:'+b.moisture+'%"></i></button>';}
 h+='</div><p class="farm-map-key">✦ 可采收　芽 生长中　! 病虫提醒<br>01—24 小院　25—72 东坡<br>蓝线：水分 · 点选查看，角色不会传送</p><div class="farm-batch"><strong>对筛选结果批量安排</strong>'+[['water','补水'],['fertilize','堆肥'],['sow','播种'],['harvest','采收']].map(([id,t])=>btn(t,'batch',id)).join('')+'</div>';
 if(ui.batch){const tasks=F.plan(s,ids,ui.batch),n=tasks.length,material=ui.batch==='sow'?D.items[F.seedId(s.seed,s.farm.seedKind)].name+' ×'+n*(s.farm.density==='dense'?2:1):ui.batch==='fertilize'?'熟堆肥 ×'+n:'无需材料';h+='<div class="farm-batch-preview"><b>'+n+' 块可安排</b><p>最多 '+n*2+' 体力 · 当前 '+Math.floor(s.stamina)+'（特长可减免）<br>'+material+'<br>按序走到田边执行；途中可取消。</p>'+btn('开始这一批','batch-start',ui.batch,n?'':'disabled')+'</div>';}
 h+='</aside><section class="farm-main"><div class="tabs">'+[['field','这块田'],['seeds','种子袋'],['facilities','田埂设施'],['guide','农事手册']].map(([id,t])=>btn(t,'tab',id,ui.tab===id?'aria-current="page"':'')).join('')+'</div>';
 h+=ui.tab==='field'?field(s):ui.tab==='seeds'?seeds(s,A.head):ui.tab==='facilities'?infrastructure(s):guide(s);
 h+='</section></div><details class="farm-more"><summary>农资补给与收获图鉴</summary><div class="button-row">'+['compost','slowFertilizer','bioCare','plantCare','beanSeed'].map(id=>btn(D.items[id].name+' · '+D.items[id].cost+' 元（有 '+(s.bag[id]||0)+'）','buy',id)).join('')+'</div><p>'+Object.entries(s.farm.collection).map(([id,g])=>D.crops[id].name+' · '+F.grades[g-1]).join('　')+'</p></details></div>';return h;
}
const oldRender=X.render,oldDispatch=X.dispatch,oldAfter=X.after;
X.render=(name,arg,s,A)=>{if(name==='farmcare'){if(Number.isInteger(arg))ui.index=arg;return render(s,A);}if(name==='seeds')return seeds(s,A.head);return oldRender(name,arg,s,A);};
X.dispatch=(a,id,data,ctx)=>{
 if(!a.startsWith('f-'))return oldDispatch(a,id,data,ctx);
 const{s,apply,open,render:refresh,save,update,toast,close,queueFarm,equipSeed}=ctx;F.ensure(s);const use=r=>{apply(r);refresh();},store=()=>{save();update();refresh();},task=(op,arg,index=Number(id))=>{queueFarm([{index,action:op,arg}]);};
 if(a==='f-filter'){ui.filter=id;ui.batch=null;refresh();}
 if(a==='f-filters'){ui.region=val('farm-region');ui.crop=val('farm-crop');ui.batch=null;refresh();}
 if(a==='f-inspect'){ui.index=Number(id);open('farmcare');}
 if(a==='f-tab'){ui.tab=id;refresh();}
 if(a==='f-selection'){s.seed=val('farm-seed');s.farm.seedKind=val('farm-kind');s.farm.density=val('farm-density');store();toast('种子与株距已经记好。');}
 if(a==='f-seed'){s.seed=id;store();}
 if(a==='f-equip'){equipSeed();close();}
 if(a==='f-buy'){if(id.endsWith('_heirloom')&&s.day<14&&s.relations.qiao.points<20)toast('春十五或与沈禾熟悉后开放。',true);else use(C.buy(s,id,Number(data.qty)||1));}
 if(a==='f-task'){task(data.op,['sow','companion'].includes(data.op)?{crop:s.seed,kind:s.farm.seedKind,density:s.farm.density}:undefined);}
 if(a==='f-soil')task('soil',val('farm-soil'));
 if(a==='f-facility')task('facility',{type:data.type,mode:data.mode,target:Number(val('move-'+data.type))-1});
 if(a==='f-fill'){task('fill',null,ui.index);}
 if(a==='f-walk')task('inspect');
 if(a==='f-auto-seed'){s.farm.autoSeed=!s.farm.autoSeed;store();}
 if(a==='f-overlay'){s.farm.overlay=!s.farm.overlay;store();}
 if(a==='f-threshold'){s.farm.threshold=Number(val('farm-threshold'));store();}
 if(a==='f-batch'){ui.batch=id;refresh();}
 if(a==='f-batch-start'){const tasks=F.plan(s,F.list(s,ui.filter,ui.region,ui.crop),id);ui.batch=null;queueFarm(tasks);}
 return true;
};
X.after=(name,s,A)=>{if(name==='bag')return '<div class="paper-note">品质：优质 +20% · 上品 +40% · 珍品 +70%。使用与出售优先普通品质。'+Object.entries(s.quality).filter(([,q])=>q.some(n=>n>0)).map(([id,q])=>'<br>'+D.items[id].name+' · '+F.grades.slice(1).map((g,i)=>g+' '+(q[i]||0)).join(' / ')).join('')+'</div>'+A.button('存取与拆分物品','storage','','secondary');return oldAfter(name,s,A);};
})(window);

