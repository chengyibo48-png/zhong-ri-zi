(function(root){
'use strict';
const C=root.ZRZCore,D=root.ZRZData,V=root.ZRZVillage,F=root.ZRZFarming;
const clamp=(n,a=0,b=100)=>Math.max(a,Math.min(b,n)),copy=v=>JSON.parse(JSON.stringify(v)),own=(o,k)=>Object.hasOwn(o,k),yes=msg=>({ok:true,msg}),no=msg=>({ok:false,msg});
const species={
 hen:{name:'鸡',home:'poultry',product:'egg',adult:6,elder:280,cycle:1,feed:1,cost:90,gestation:4,color:'#ebd6a0'},
 duck:{name:'鸭',home:'poultry',product:'duckEgg',adult:8,elder:336,cycle:1,feed:1,cost:120,gestation:5,color:'#e1e2c8'},
 cow:{name:'牛',home:'cattle',product:'milk',adult:14,elder:448,cycle:1,feed:3,cost:420,gestation:8,color:'#b88b52'},
 sheep:{name:'羊',home:'sheepfold',product:'wool',adult:10,elder:392,cycle:3,feed:2,cost:240,gestation:6,color:'#e4dfc6'},
 pig:{name:'猪',home:'pigpen',product:'manure',adult:12,elder:336,cycle:2,feed:2,cost:180,gestation:6,color:'#d6a393'}
};
const breeds={local:{name:'乡土种',cost:1,feed:1,rate:1,resist:0,cap:2,desc:'容易照料，普通饲料就能安稳成长'},hardy:{name:'健壮种',cost:1.4,feed:1,rate:.9,resist:12,cap:3,desc:'抗寒抗病、慢一些，最高珍品'},productive:{name:'丰产种',cost:1.5,feed:1.3,rate:1.18,resist:-3,cap:3,desc:'生产稍快，胃口更大'}};
const traits={friendly:'亲人',shy:'胆小',hungry:'贪吃',strong:'健壮',busy:'勤快',picky:'挑食',social:'群居'};
const barns={poultry:{name:'鸡鸭舍',base:4,cost:100,wood:6,house:'ranch-poultry'},cattle:{name:'东坡牛棚',base:2,cost:180,wood:10,house:null},sheepfold:{name:'东坡羊圈',base:3,cost:150,wood:8,house:'ranch-sheepfold'},pigpen:{name:'东坡猪圈',base:3,cost:140,wood:8,house:'ranch-pigpen'}};
const items={
 hay:['青干草',4,8,'feed','材料'],grainFeed:['谷物精饲料',8,16,'feed','材料'],healthFeed:['草本营养料',12,24,'feed','材料'],bedding:['干草垫料',4,8,'feed','材料'],animalMedicine:['兽用护理药',12,28,'bottle','材料'],fertileHenEgg:['受精鸡蛋',10,32,'egg','材料'],fertileDuckEgg:['受精鸭蛋',14,42,'egg','材料'],wool:['柔软羊毛',58,null,'wool','材料'],feather:['蓬松羽毛',9,null,'feather','材料'],manure:['圈肥原料',5,null,'compost','材料'],truffle:['猪拱菌',42,null,'mushroom','食材'],cream:['手摇奶油',62,null,'milk','加工物'],yogurt:['陶罐酸奶',74,null,'milk','料理'],yarn:['手纺毛线',82,null,'wool','材料'],cloth:['柔软毛呢',165,null,'wool','材料']
};
for(const[id,[name,price,cost,icon,kind]]of Object.entries(items))D.items[id]={name,price,cost,icon,kind,...(id==='yogurt'?{energy:32}:{})};
const recipes={
 hay:{name:'晾成青干草',needs:{cabbage:2},out:'hay',qty:3},grain:{name:'配谷物精料',needs:{corn:1,rice:1},out:'grainFeed',qty:3},health:{name:'配草本营养料',needs:{hay:2,wildHerb:1},out:'healthFeed',qty:2},bedding:{name:'扎干草垫料',needs:{hay:1},out:'bedding',qty:2},compost:{name:'圈肥熟化',needs:{manure:2,bedding:1},out:'compost',qty:3,days:1,station:'堆肥箱'},cream:{name:'手摇奶油',needs:{milk:2},out:'cream',qty:2},yogurt:{name:'陶罐发酵酸奶',needs:{milk:2},out:'yogurt',qty:2,days:1,station:'腌菜坛'},yarn:{name:'纺一绞毛线',needs:{wool:2},out:'yarn',qty:2},cloth:{name:'织柔软毛呢',needs:{yarn:2},out:'cloth',qty:1}};
const feedKinds={feed:{name:'基础饲料',gain:55,quality:0},hay:{name:'青干草',gain:52,quality:3},grainFeed:{name:'谷物精料',gain:72,quality:8},healthFeed:{name:'营养饲料',gain:62,quality:6}};
const orders=[
 {id:'ranchMilk',title:'阿婆的小奶盅',npc:'granny',needs:{milk:2},money:85,reward:{hay:5},text:'给阿婆留两份鲜奶，普通品质就很好。没有期限。'},
 {id:'ranchWool',title:'素琴的暖冬毛线',npc:'luo',needs:{wool:3},money:220,reward:{grainFeed:3},text:'罗素琴想试试用本村羊毛纺线，三份羊毛就够开工。'},
 {id:'ranchYogurt',title:'食堂的陶罐酸奶',npc:'mei',needs:{yogurt:2},money:185,reward:{bedding:4},text:'方梅想给邻里的饭桌添两小罐酸奶，做好了随时送去。'}
];D.orders.push(...orders);
const zones=[{name:'塘边草甸',x:5470,y:1755},{name:'南坡牧草',x:5310,y:2130}];
function installWorld(){
 const existing=V.houses.find(h=>h.name==='东坡牧舍');barns.cattle.house=existing.id;
 for(const[id,x,y,w,h,name]of [['poultry',1080,745,190,110,'东坡鸡鸭舍'],['sheepfold',1390,745,185,110,'东坡羊圈'],['pigpen',1610,920,180,100,'东坡猪圈']]){
  const local={kind:'house',x,y,w,h,name,style:'brick'},q={...local,x:x+3840,y:y+1152,id:'ranch-'+id,region:'pasture',owner:null,theme:'wood',door:{x:x+3840+w*.48,y:y+1152+h+23}};
  V.maps.pasture.props.push(local);V.allProps.push(q);V.houses.push(q);V.solids.push([q.x+8,q.y+55,w-16,h-52]);
 }
}
installWorld();
const type=a=>a.type||Object.keys(species).find(k=>species[k].name===a.species),houseOf=a=>V.houses.find(h=>h.id===barns[species[type(a)].home].house);
const capacity=(s,id)=>ensure(s).barns[id].built?barns[id].base+s.ranch.barns[id].space*2:0;
const residents=(s,id)=>s.animals.filter(a=>species[type(a)].home===id);
const reserved=(s,id)=>ensure(s).births.filter(b=>species[b.type].home===id).length;
const stage=a=>a.retired?'颐养':a.age<species[type(a)].adult*.45?'幼崽':a.age<species[type(a)].adult?'成长':a.age>=species[type(a)].elder?'年长':'成年';
const mature=a=>a.age>=species[type(a)].adult;
function freshAnimal(a,index,day){
 const t=type(a),spec=species[t],h=V.houses.find(h=>h.id===barns[spec.home].house),p=V.safePosition({village:{}},{x:h.door.x+24+index*8,y:h.door.y+25});
 return {...a,fed:true,type:t,sex:'female',breed:'local',trait:['friendly','busy','strong'][index%3],age:spec.adult+12,hunger:a.fed?95:65,health:100,mood:80,clean:90,stress:0,illness:0,warning:0,progress:0,qualityStock:[a.ready||0,0,0,0],feedQuality:0,feathers:0,retired:false,rest:false,lost:false,care:{feed:a.fed?day:-1,pet:-1,clean:-1,treat:-1,breed:-20},position:{x:p.x,y:p.y,direction:'down',room:null,inside:{x:420+index*35,y:490}},generation:0,parents:[]};
}
function ensure(s){
 if(!s.ranch){s.ranch={version:1,nextId:1,barns:Object.fromEntries(Object.keys(barns).map(id=>[id,{built:['poultry','cattle'].includes(id),space:s.upgrades.coop?1:0,comfort:0,protection:0,efficiency:0,autoFeed:!!s.upgrades.coop,autoClean:false,autoCollect:false,durability:100,clean:90,waste:0,lastClean:-1}])),stores:{feed:0,hay:0,grainFeed:0,healthFeed:0,bedding:0},feed:'feed',policy:s.freeRange?'safe':'inside',zone:0,grass:[100,100],births:[],rehomed:[],notices:[],collection:{},pet:{hunger:80,energy:100,training:0,mode:'home',fed:-1,trained:-1,position:{x:2775,y:1690,direction:'right'}},roundUp:-1};s.animals=s.animals.map((a,i)=>freshAnimal(a,i,s.day));for(const b of Object.values(s.ranch.barns))if(b.autoFeed)b.autoFeedBuilt=true;}return s.ranch;
}
function status(s,a){ensure(s);const b=s.ranch.barns[species[type(a)].home],msgs=[];
 if(a.lost)msgs.push('走远了：留在南坡标记附近，可带回');
 if(a.illness>=20)msgs.push('不适 '+Math.round(a.illness)+'：休养、营养料或治疗');
 if(a.hunger<40)msgs.push('饲料不足');if(a.clean<45||b.clean<45)msgs.push('垫草潮湿，需要清理');
 if(residents(s,species[type(a)].home).length>capacity(s,species[type(a)].home))msgs.push('畜舍拥挤，建议扩容');
 if(b.durability<25)msgs.push('屋舍需修缮');if(a.health<45)msgs.push('健康较弱，建议留舍');
 if(a.ready>0)msgs.push('可收 '+D.items[a.product].name+' ×'+a.ready);
 if(!msgs.length)msgs.push(a.retired?'安心颐养，不再安排生产':mature(a)?'状态安稳，按自己的节奏照料':'正在长大，成年后再安排生产');
 return msgs;
}
function quality(s,a){const b=ensure(s).barns[species[type(a)].home],score=a.health*.26+a.hunger*.2+a.mood*.2+a.clean*.14+a.bond*.1+b.clean*.1+a.feedQuality+b.comfort*2-a.illness*.2-a.stress*.1;return Math.min(breeds[a.breed].cap,score>=92?3:score>=77?2:score>=55?1:0);}
function readyStock(a){a.ready=a.qualityStock.reduce((x,y)=>x+y,0);a.fed=a.hunger>=60;}
function addQuality(s,id,n,g){C.add(s,id,n);if(g){s.quality[id]??=[0,0,0];while(s.quality[id].length<3)s.quality[id].push(0);s.quality[id][g-1]+=n;}}
function charge(s,energy=2,needs={},money=0){if(!C.has(s,needs))return no('材料不足：'+Object.entries(needs).map(([id,n])=>D.items[id].name+' ×'+n).join('、'));if(s.money<money)return no('需要 '+money+' 元。');if(!C.labor(s,energy,5))return no('有些累，先休息或吃点东西。');C.consume(s,needs);s.money-=money;return null;}
function collect(s,a,auto=false){if(!a.ready&&!a.feathers)return no('还没有可以收下的产物。');const b=s.ranch.barns[species[type(a)].home];if(!auto&&!C.labor(s,b.efficiency?1:2,5))return no('先歇一会儿再收产物。');const n=a.ready;
 a.qualityStock.forEach((v,g)=>{if(v){addQuality(s,a.product,v,g);s.ranch.collection[a.product]=Math.max(s.ranch.collection[a.product]||0,g+1);}});a.qualityStock=[0,0,0,0];if(a.feathers)C.add(s,'feather',a.feathers);const extra=a.feathers;a.feathers=0;readyStock(a);return yes(({hen:'拾起',duck:'拾起',cow:'挤好',sheep:'剪下',pig:'收好'}[type(a)])+a.name+'的'+D.items[a.product].name+' ×'+n+(extra?'，另收羽毛 ×'+extra:'')+'。');}
function action(s,id,act,arg){
 const r=ensure(s),a=s.animals.find(v=>v.id===id);if(!a)return no('这位伙伴不在牧场里。');const spec=species[type(a)],barn=r.barns[spec.home];let e;
 if(act==='collect')return collect(s,a);
 if(act==='feed'){const food=arg||r.feed;if(!own(feedKinds,food))return no('请选择饲料。');if(a.hunger>=90||a.care.feed===s.day)return no('今天已吃得足够，不必反复添料。');if(food==='hay'&&!['cow','sheep','pig'].includes(type(a)))return no('鸡鸭更适合基础饲料或谷物精料。');const n=Math.ceil(spec.feed*breeds[a.breed].feed);if(e=charge(s,2,{[food]:n}))return e;a.hunger=clamp(a.hunger+feedKinds[food].gain);a.feedQuality=feedKinds[food].quality;a.bond=clamp(a.bond+(a.trait==='friendly'?6:3));a.mood=clamp(a.mood+8+(food==='hay'&&['cow','sheep'].includes(type(a))?5:0)-(a.trait==='picky'&&food==='feed'?3:0));if(food==='healthFeed'){a.health=clamp(a.health+12);a.illness=clamp(a.illness-12);}a.care.feed=s.day;readyStock(a);return yes(a.name+'低头吃起'+D.items[food].name+'，饱食 '+Math.round(a.hunger)+'。');}
 if(act==='pet'){if(a.care.pet===s.day)return no('今天已经陪过它，可以放心做别的事。');if(e=charge(s,1))return e;a.bond=clamp(a.bond+(a.trait==='friendly'?7:4));a.mood=clamp(a.mood+12);a.stress=clamp(a.stress-15);a.care.pet=s.day;return yes(a.name+'靠过来，舒服地眯起眼。');}
 if(act==='clean'){if(a.clean>=95||a.care.clean===s.day)return no('皮毛已经很干净。');if(e=charge(s,2))return e;a.clean=100;a.mood=clamp(a.mood+6);a.care.clean=s.day;return yes('轻轻梳洗'+a.name+'，皮毛清爽了。');}
 if(act==='treat'||act==='vet'){if(a.health>=95&&a.illness<1)return no('它很健康，暂时不必治疗。');if(a.care.treat===s.day)return no('今天已护理过，先让它歇一歇。');if(e=charge(s,2,act==='treat'?{animalMedicine:1}:{},act==='vet'?35:0))return e;a.health=clamp(a.health+(act==='vet'?45:30));a.illness=clamp(a.illness-(act==='vet'?70:45));a.stress=clamp(a.stress-15);a.care.treat=s.day;a.rest=true;return yes('处理好不适，安排'+a.name+'回舍休养；状态改善后可恢复放牧。');}
 if(act==='rest'){a.rest=!a.rest;return yes(a.rest?'安排留舍休养。':'允许按牧场策略活动。');}
 if(act==='retire'){if(!mature(a))return no('幼崽还在长大。');a.retired=!a.retired;return yes(a.retired?'留在牧场安心颐养，不再安排产出。':'恢复生产安排，仍按健康状况慢慢来。');}
 if(act==='rescue'){if(!a.lost)return no('它正在牧场附近。');if(e=charge(s,2))return e;a.lost=false;a.rest=true;a.mood=clamp(a.mood+15);a.stress=clamp(a.stress-20);return yes('认出你的脚步，'+a.name+'愿意跟你回舍休息。');}
 if(act==='name'){if(typeof arg!=='string'||!arg.trim())return no('请写一个名字。');a.name=arg.trim().slice(0,12);return yes('记住了它的名字。');}
 return no('请选择照料动作。');
}
function spaceFor(s,t){const id=species[t].home;return s.animals.length+s.ranch.births.length<32&&residents(s,id).length+reserved(s,id)<capacity(s,id);}
function addAnimal(s,t,sex,breed,age=0,parents=[]){
 const r=ensure(s),id='livestock-'+r.nextId++,n=species[t],a=freshAnimal({id,type:t,species:n.name,name:['团团','麦麦','阿栗','豆花','小穗','糯米'][r.nextId%6]+r.nextId,personality:'',product:n.product,bond:0,fed:false,ready:0},r.nextId,s.day);
 a.age=age;a.sex=sex;a.breed=breed;a.trait=Object.keys(traits)[(r.nextId+s.day)%7];a.personality=traits[a.trait];a.parents=parents.slice();a.generation=parents.length?1+Math.max(...s.animals.filter(v=>parents.includes(v.id)).map(v=>v.generation),0):0;a.position.room=houseOf(a).id;a.position.inside={x:360+(r.nextId%6)*55,y:490+(r.nextId%2)*34};s.animals.push(a);return a;
}
function buyAnimal(s,t,sex='female',breed='local',young=true){ensure(s);if(!own(species,t)||!['female','male'].includes(sex)||!own(breeds,breed))return no('请选择有效种类与品种。');if(!spaceFor(s,t))return no('畜舍尚未修好或没有空位；孕育中的幼崽也预留床位。');const n=species[t],cost=Math.round(n.cost*breeds[breed].cost*(young?.7:1));const e=charge(s,2,{},cost);if(e)return e;const a=addAnimal(s,t,sex,breed,young?0:n.adult);return yes('迎来'+n.name+'“'+a.name+'”，已安置在'+barns[n.home].name+'。');}
function breed(s,motherId,fatherId){const r=ensure(s),m=s.animals.find(a=>a.id===motherId),f=s.animals.find(a=>a.id===fatherId);if(!m||!f||m===f||type(m)!==type(f)||m.sex!=='female'||f.sex!=='male')return no('需要同种成年母畜与公畜配对。');if([m,f].some(a=>!mature(a)||a.retired||a.health<70||a.hunger<55||a.mood<50||a.illness>10||a.lost))return no('先让双方成年、吃饱、恢复健康与心情，再安排繁殖。');if(r.births.some(b=>b.mother===m.id)||s.day-m.care.breed<12)return no('刚生产的母畜需要休养，或已有孕育安排。');if(!spaceFor(s,type(m)))return no('先给未来幼崽预留一个床位。');if(r.barns[species[type(m)].home].clean<50)return no('先清理畜舍，再迎接新生命。');const e=charge(s,3,{grainFeed:2},20);if(e)return e;const t=type(m),b={id:'birth-'+r.nextId++,type:t,mother:m.id,father:f.id,breed:m.breed===f.breed?m.breed:(r.nextId%2?m.breed:f.breed),remaining:species[t].gestation,total:species[t].gestation};r.births.push(b);m.care.breed=s.day;return yes('安排好了，约 '+b.remaining+' 个舒适日后迎来幼崽；床位已经预留。');}
function incubate(s,t){const r=ensure(s);if(!['hen','duck'].includes(t))return no('孵化区只接收受精鸡鸭蛋。');if(r.barns.poultry.comfort<1)return no('先给鸡鸭舍添置舒适巢箱。');if(!spaceFor(s,t))return no('孵化也需要预留床位。');const e=charge(s,2,{[t==='hen'?'fertileHenEgg':'fertileDuckEgg']:1});if(e)return e;r.births.push({id:'birth-'+r.nextId++,type:t,mother:null,father:null,breed:'local',remaining:species[t].gestation,total:species[t].gestation});return yes('把受精蛋放进温暖巢箱，普通食用蛋不会误拿去孵化。');}
function barnAction(s,id,act){const r=ensure(s),b=r.barns[id];if(!b)return no('请选择畜舍。');let e;
 if(act==='build'){if(b.built)return no('畜舍已经可以使用。');if(e=charge(s,4,{wood:barns[id].wood,bamboo:4},barns[id].cost))return e;b.built=true;return yes(barns[id].name+'修好了，门内有了干净床位。');}
 if(!b.built)return no('先修好这座畜舍。');
 if(['space','comfort','protection','efficiency'].includes(act)){if(b[act]>=3)return no('这一项已升至三级。');if(e=charge(s,3,{wood:4+b[act]*2,bamboo:3},60+b[act]*50))return e;b[act]++;return yes(barns[id].name+'的'+{space:'空间',comfort:'舒适巢床',protection:'通风排水与围护',efficiency:'收集工位'}[act]+'升级到 '+b[act]+' 级。');}
 if(['autoFeed','autoClean','autoCollect'].includes(act)){if(b[act]){b[act]=false;return yes('已暂停自动照料。');}if(!b[act+'Built']){if(e=charge(s,3,{wood:5,bamboo:4},100))return e;b[act+'Built']=true;}b[act]=true;return yes('已启用'+{autoFeed:'食槽自动添料',autoClean:'自动更换垫草',autoCollect:'自动收集'}[act]+'，材料取自牧场料仓。');}
 if(act==='clean'){if(b.lastClean===s.day||b.clean>=95&&b.waste===0)return no('畜舍干净，今天不用重复清扫。');if(e=charge(s,3))return e;const n=Math.min(8,b.waste);if(n)C.add(s,'manure',n);b.waste=Math.max(0,b.waste-n);b.clean=100;b.lastClean=s.day;residents(s,id).forEach(a=>a.clean=clamp(a.clean+15));return yes('清扫'+barns[id].name+'，收下圈肥原料 ×'+n+'，可熟化后养田。');}
 if(act==='bedding'){if(b.clean>=95)return no('垫草还很清爽。');if(e=charge(s,2,{bedding:1}))return e;b.clean=clamp(b.clean+35);residents(s,id).forEach(a=>{a.clean=clamp(a.clean+10);a.mood=clamp(a.mood+6);});return yes('铺开干草垫料，屋里暖和干爽了。');}
 if(act==='repair'){if(b.durability>=100)return no('屋舍完好。');if(e=charge(s,3,{wood:2},10))return e;b.durability=100;return yes('补好屋顶、扎紧篱门，防护恢复了。');}
 return no('请选择升级或照料方式。');
}
function storeFeed(s,id,n=5,withdraw=false){const r=ensure(s);if(!own(r.stores,id)||!Number.isInteger(n)||n<1||n>100)return no('请选择有效物品与数量。');if(withdraw){if(r.stores[id]<n)return no('料仓数量不足。');r.stores[id]-=n;C.add(s,id,n);}else{if(!C.has(s,{[id]:n}))return no('背包数量不足。');if(r.stores[id]+n>9999)return no('料仓这一格已满。');C.consume(s,{[id]:n});r.stores[id]+=n;}return yes((withdraw?'取回':'存入')+D.items[id].name+' ×'+n+'。');}
function craft(s,id,n=1){ensure(s);const rec=recipes[id];if(!own(recipes,id)||!Number.isInteger(n)||n<1||n>20)return no('选择 1—20 批。');const needs=Object.fromEntries(Object.entries(rec.needs).map(([k,v])=>[k,v*n])),prem=Object.entries(needs).every(([k,v])=>(s.bag[k]||0)===(s.quality[k]||[]).reduce((a,b)=>a+b,0)&&(s.bag[k]||0)>=v),e=charge(s,2,needs);if(e)return e;if(rec.days)s.processing.push({id:rec.out,qty:rec.qty*n,readyDay:s.day+rec.days,station:rec.station,cooking:rec.out==='yogurt',...(prem?{farmGrade:1}:{})});else addQuality(s,rec.out,rec.qty*n,prem?1:0);return yes(rec.name+' ×'+n+(rec.days?'，明早完成。':'，已经收好。'));}
function rehome(s,id,confirm=false){const r=ensure(s),a=s.animals.find(v=>v.id===id);if(!a)return no('没有这位伙伴。');if(!confirm)return no('请在游戏中确认送养。');if(r.births.some(b=>b.mother===id||b.father===id))return no('它正参与孕育，请等幼崽出生后再安排。');if(a.ready||a.feathers)return no('先收好它的产物再办理送养。');if(r.rehomed.length>=32)return no('送养记录已满，请先接回伙伴。');const fee=Math.round(species[type(a)].cost*.4);r.rehomed.push({animal:copy(a),fee,day:s.day});s.animals=s.animals.filter(v=>v.id!==id);s.money+=fee;return yes(a.name+'搬去邻村牧场，收到 '+fee+' 元照料补贴；有空位时可按同价接回。');}
function adopt(s,id){const r=ensure(s),record=r.rehomed.find(v=>v.animal.id===id);if(!record||!spaceFor(s,type(record.animal)))return no('没有记录或畜舍没有空位。');const e=charge(s,2,{},record.fee);if(e)return e;const a=record.animal;a.lost=false;a.position.room=houseOf(a).id;a.position.inside={x:480,y:500};s.animals.push(a);r.rehomed=r.rehomed.filter(v=>v!==record);return yes('把'+a.name+'接回来了，名字、亲近与品种都还在。');}
function petAction(s,act){const r=ensure(s),p=r.pet;let e;
 if(act==='feed'){if(p.fed===s.day||p.hunger>=95)return no('它今天已经吃饱。');if(e=charge(s,1,{feed:1}))return e;p.hunger=clamp(p.hunger+50);p.energy=clamp(p.energy+15);p.fed=s.day;s.pet.bond=clamp(s.pet.bond+3);return yes('给'+s.pet.name+'添好一小碗饭。');}
 if(act==='train'){if(p.trained===s.day)return no('今天练过啦，明天再来。');if(p.energy<15)return no('它有些累，先休息。');if(e=charge(s,2))return e;p.training=clamp(p.training+10);p.energy-=15;p.trained=s.day;s.pet.bond=clamp(s.pet.bond+4);return yes(s.pet.type==='dog'?'练习听铃与召回；训练达到 20 后能协助看护。':'练习回家与巡粮仓；训练达到 20 后减少粮耗。');}
 if(['home','follow','patrol'].includes(act)){p.mode=act;return yes({home:'让它回小院休息。',follow:'它会沿路跟在身后，进屋时在门外等你。',patrol:'它会在牧场巡看，照料和训练越好，帮忙越稳妥。'}[act]);}
 return C.pet(s);
}
function notice(s,text){s.ranch.notices.unshift({day:s.day,text});s.ranch.notices=s.ranch.notices.slice(0,24);}
function safeOut(s,a){return !a.lost&&mature(a)&&!a.rest&&!a.retired&&a.health>=45&&a.illness<45&&s.ranch.policy!=='inside'&&!['台风','寒潮','小雪','高温'].includes(C.weather(s.day))&&!(s.ranch.policy==='safe'&&C.weather(s.day)==='雨')&&s.minutes>=480&&s.minutes<1050;}
function daily(s,day){const r=ensure(s),weather=C.weather(day),wet=['雨','台风'].includes(weather),extreme=['台风','寒潮','高温'].includes(weather),dog=s.pet.type==='dog'&&r.pet.mode==='patrol'&&r.pet.training>=20&&r.pet.hunger>=35,cat=s.pet.type==='cat'&&r.pet.training>=20&&r.pet.hunger>=35,prior=Object.fromEntries(s.animals.map(a=>[a.id,a.illness]));
 for(const[id,b]of Object.entries(r.barns)){if(!b.built)continue;const group=residents(s,id),crowd=Math.max(0,group.length-capacity(s,id));b.clean=clamp(b.clean-group.length*(id==='pigpen'?4:2)-(wet?5:1)-crowd*5);b.waste=Math.min(99,b.waste+group.length);b.durability=clamp(b.durability-(weather==='台风'?5:day%7===0?1:0));
  if(b.autoClean&&b.durability>0&&b.clean<65&&r.stores.bedding>0){r.stores.bedding--;b.clean=95;group.forEach(a=>a.clean=clamp(a.clean+25));const n=Math.min(8,b.waste);C.add(s,'manure',n);b.waste-=n;}
  for(const a of group){const t=type(a),sp=species[t];a.age=Math.min(100000,a.age+1);a.hunger=clamp(a.hunger-(16+sp.feed*2)*(a.trait==='hungry'?1.15:1));a.clean=clamp(a.clean-(id==='pigpen'?8:4)-(wet?3:0)+(b.protection?2:0));
   const ranging=r.policy!=='inside'&&!extreme&&!(r.policy==='safe'&&wet)&&mature(a)&&!a.rest&&!a.retired&&a.health>=45&&!a.lost,zone=t==='duck'?0:r.zone;
   if(ranging&&r.grass[zone]>10){a.hunger=clamp(a.hunger+(t==='cow'||t==='sheep'?12:7));a.mood=clamp(a.mood+6);r.grass[zone]=clamp(r.grass[zone]-(sp.feed+1));}
   if(b.autoFeed&&b.durability>0&&a.hunger<55){const feeds=[r.feed,'feed','hay','grainFeed','healthFeed'].filter((f,i,all)=>all.indexOf(f)===i&&(f!=='hay'||['cow','sheep','pig'].includes(t))),food=feeds.find(f=>(r.stores[f]||0)>=Math.ceil(sp.feed*breeds[a.breed].feed));if(food){r.stores[food]-=Math.ceil(sp.feed*breeds[a.breed].feed);a.hunger=clamp(a.hunger+feedKinds[food].gain);a.feedQuality=feedKinds[food].quality;}else notice(s,barns[id].name+'料仓不足，自动添料暂停。');}
   const pressure=(a.hunger<25?12:0)+(b.clean<35||a.clean<35?9:0)+crowd*6+(extreme&&b.protection===0?6:0)+(a.trait==='social'&&group.length<2?4:0);
   a.warning=pressure>=9?Math.min(99,a.warning+1):Math.max(0,a.warning-1);
   if(a.warning>=2)a.illness=clamp(a.illness+Math.max(1,pressure/3-breeds[a.breed].resist*.25-(a.trait==='strong'?2:0)));
   if(b.clean<40&&group.some(o=>o!==a&&prior[o.id]>60))a.illness=clamp(a.illness+3);
   if(a.rest&&a.hunger>35&&b.clean>50){a.illness=clamp(a.illness-8);a.health=clamp(a.health+8);}
   a.health=clamp(a.health+(pressure<9&&a.illness<30?4:-Math.min(8,pressure*.25+a.illness*.05)),15);
   a.mood=clamp(a.mood+(pressure<9?2:-5)+b.comfort-(a.illness>45?4:0));a.stress=clamp(a.stress+(pressure>=9?7:-6)+(a.trait==='shy'&&extreme&&b.protection===0?5:0));if(a.trait==='social'&&group.length<2)a.mood=clamp(a.mood-4);
   if(ranging&&!b.protection&&!dog&&a.warning>=1&&day%19===s.animals.indexOf(a)%19){a.lost=true;a.stress=clamp(a.stress+15);notice(s,a.name+'走到了南坡边，地图与名册会标记位置，可带回。');}
   if(ranging&&r.policy==='day'&&!b.protection&&!dog&&day%17===s.animals.indexOf(a)%17){a.mood=clamp(a.mood-8);a.stress=clamp(a.stress+8);notice(s,a.name+'听见野外动静有些受惊，可安抚或增建围护。');}
   const canProduce=mature(a)&&!a.retired&&!a.lost&&a.health>=30&&a.hunger>=25&&(a.sex==='female'||['sheep','pig'].includes(t));
   if(canProduce&&a.ready<28){let rate=breeds[a.breed].rate*(a.trait==='busy'?1.08:1)*(a.health<60?.55:1)*(a.age>=sp.elder?.65:1)*(a.illness>30?.6:1);a.progress+=rate;while(a.progress>=sp.cycle&&a.qualityStock.reduce((x,y)=>x+y,0)<28){a.progress-=sp.cycle;const g=quality(s,a);a.qualityStock[g]++;if(['hen','duck'].includes(t)&&day%5===0)a.feathers=Math.min(20,a.feathers+1);if(t==='pig'&&ranging&&day%4===0)C.add(s,'truffle',1);}}
   if(!canProduce&&!mature(a))a.progress=0;a.feedQuality=Math.max(0,a.feedQuality-1);readyStock(a);if(b.autoCollect&&b.durability>0&&(a.ready||a.feathers))collect(s,a,true);
  }
 }
 for(let i=0;i<2;i++)r.grass[i]=clamp(r.grass[i]+(r.zone!==i?10:4)+(wet?5:0));
 for(const b of [...r.births]){const home=r.barns[species[b.type].home],m=s.animals.find(a=>a.id===b.mother);if(home.clean<40||m&&(m.health<50||m.hunger<30)||extreme&&home.comfort<1)continue;b.remaining=Math.max(0,b.remaining-1);if(!b.remaining){const a=addAnimal(s,b.type,r.nextId%2?'female':'male',b.breed,0,[b.mother,b.father].filter(Boolean));if(m){if(r.nextId%2===0){a.trait=m.trait;a.personality=traits[a.trait];}m.care.breed=s.day;m.rest=true;}r.births=r.births.filter(v=>v!==b);notice(s,'新伙伴 '+a.name+' 出生了！已安置在'+barns[species[b.type].home].name+'。');}}
 r.pet.hunger=clamp(r.pet.hunger-12);r.pet.energy=clamp(r.pet.energy+(r.pet.mode==='home'?30:10));if(day%13===0&&!cat&&r.stores.grainFeed>0){r.stores.grainFeed--;notice(s,'粮仓有一点鼠耗：谷物精料 −1。盖好料箱或训练猫咪巡看。');}
 if(s.animals.some(a=>a.warning>=2||a.illness>=20))notice(s,'有伙伴需要留意，打开牧场名册可查看原因与护理方式。');
}
function validate(v,s){const r=v.ranch;if(!r)return ensure(s);const bad=()=>{throw Error('畜牧存档数据无效，请使用备份。');},num=(n,a=0,b=100)=>Number.isFinite(n)&&n>=a&&n<=b,int=(n,a=0,b=100)=>Number.isInteger(n)&&num(n,a,b),obj=x=>x&&typeof x==='object'&&!Array.isArray(x);
 if(r.version!==1||!obj(r.barns)||!int(r.nextId,1,1000000)||!['safe','day','inside'].includes(r.policy)||![0,1].includes(r.zone)||!own(feedKinds,r.feed)||!Array.isArray(r.grass)||r.grass.length!==2||!r.grass.every(n=>num(n))||!obj(r.stores)||!Array.isArray(v.animals)||v.animals.length>32)bad();
 for(const id of Object.keys(barns)){const b=r.barns[id];if(!obj(b)||typeof b.built!=='boolean'||!['space','comfort','protection','efficiency'].every(k=>int(b[k],0,3))||!['durability','clean'].every(k=>num(b[k]))||!int(b.waste,0,99)||!int(b.lastClean,-1,s.day)||!['autoFeed','autoClean','autoCollect'].every(k=>typeof b[k]==='boolean'))bad();}
 for(const id of ['feed','hay','grainFeed','healthFeed','bedding'])if(!int(r.stores[id],0,9999))bad();
 const ids=new Set();function checkAnimal(a){if(!obj(a)||typeof a.id!=='string'||!/^(hen|duck|cow|livestock-\d+)$/.test(a.id)||ids.has(a.id)||!own(species,a.type)||!own(breeds,a.breed)||!own(traits,a.trait)||!['female','male'].includes(a.sex)||typeof a.name!=='string'||a.name.length>12||a.species!==species[a.type].name||a.product!==species[a.type].product||!int(a.age,0,100000)||!int(a.generation,0,100000)||!['bond','hunger','health','mood','clean','stress','illness','warning','feedQuality'].every(k=>num(a[k]))||!num(a.progress,0,10)||!Array.isArray(a.qualityStock)||a.qualityStock.length!==4||!a.qualityStock.every(n=>int(n,0,28))||a.qualityStock.reduce((x,y)=>x+y,0)>28||!int(a.feathers,0,20)||!['retired','rest','lost'].every(k=>typeof a[k]==='boolean')||!obj(a.care)||!['feed','pet','clean','treat','breed'].every(k=>int(a.care[k],-20,s.day))||!Array.isArray(a.parents)||a.parents.length>2||a.parents.some(id=>typeof id!=='string'||id.length>40))bad();ids.add(a.id);const p=a.position;if(!obj(p)||!num(p.x,24,V.WIDTH-24)||!num(p.y,38,V.HEIGHT-24)||!(p.room===null||p.room===barns[species[a.type].home].house)||!obj(p.inside)||!num(p.inside.x,113,847)||!num(p.inside.y,205,602))bad();if(!p.room)Object.assign(p,V.safePosition({village:{}},p));Object.assign(p.inside,V.safePosition({village:{interior:houseOf(a).id}},p.inside));readyStock(a);}
 v.animals.forEach(checkAnimal);if(!Array.isArray(r.rehomed)||r.rehomed.length>32)bad();for(const b of r.rehomed){if(!int(b.fee,0,100000)||!int(b.day,0,s.day))bad();checkAnimal(b.animal);}
 if(!Array.isArray(r.births)||r.births.length+v.animals.length>32)bad();const births=new Set(),mothers=new Set();for(const b of r.births){if(!obj(b)||typeof b.id!=='string'||births.has(b.id)||!own(species,b.type)||!own(breeds,b.breed)||!int(b.total,1,10)||!int(b.remaining,0,b.total)||b.mother!==null&&!v.animals.some(a=>a.id===b.mother&&a.type===b.type&&a.sex==='female')||b.father!==null&&!v.animals.some(a=>a.id===b.father&&a.type===b.type&&a.sex==='male'))bad();if(b.mother&&mothers.has(b.mother))bad();if(b.mother)mothers.add(b.mother);births.add(b.id);}
 const p=r.pet;if(!obj(p)||!['hunger','energy','training'].every(k=>num(p[k]))||!['home','follow','patrol'].includes(p.mode)||!int(p.fed,-1,s.day)||!int(p.trained,-1,s.day)||!obj(p.position)||!num(p.position.x,24,V.WIDTH-24)||!num(p.position.y,38,V.HEIGHT-24))bad();
 if(!Array.isArray(r.notices)||r.notices.length>24||r.notices.some(n=>!int(n.day,0,s.day)||typeof n.text!=='string'||n.text.length>300)||!obj(r.collection)||Object.entries(r.collection).some(([k,n])=>!D.items[k]||!int(n,1,4)))bad();
 const used=[...ids,...births].map(id=>Number(id.split('-').at(-1))||0);r.nextId=Math.max(r.nextId,...used.map(n=>n+1));s.animals=copy(v.animals);s.ranch=copy(r);return s.ranch;
}
const old={initial:C.initial,load:C.load,nextDay:C.nextDay,upgrade:C.upgrade,pet:C.pet};
C.initial=(...a)=>{const s=old.initial(...a);ensure(s);return s;};
C.load=raw=>{const v=typeof raw==='string'?JSON.parse(raw):copy(raw),s=old.load(v);validate(v,s);return s;};
C.nextDay=s=>{ensure(s);const animals=s.animals,day=s.day;let out;s.animals=[];try{out=old.nextDay(s);}finally{s.animals=animals;}daily(s,day);return out;};
C.tend=(s,id)=>{ensure(s);const a=s.animals.find(a=>a.id===id);return a?.ready||a?.feathers?action(s,id,'collect'):action(s,id,'feed');};
C.animalAction=(s,id,act)=>action(s,id,act);
C.upgrade=(s,id)=>{const r=old.upgrade(s,id);if(r.ok&&id==='coop'){const b=ensure(s).barns.poultry;b.space=Math.max(1,b.space);b.autoFeed=b.autoFeedBuilt=true;r.msg+=' 鸡鸭舍新增床位和自动食槽；请在牧场料仓存入饲料。';}return r;};
C.pet=s=>{ensure(s);const r=old.pet(s);if(r.ok)s.ranch.pet.energy=clamp(s.ranch.pet.energy+5);return r;};
const R={species,breeds,traits,barns,feedKinds,recipes,zones,ensure,type,houseOf,capacity,residents,reserved,stage,mature,status,quality,action,collect,buyAnimal,breed,incubate,barnAction,storeFeed,craft,rehome,adopt,petAction,safeOut,daily};
const loadWithRanch=C.load,deliver=C.deliver;
C.load=raw=>{const s=loadWithRanch(raw),done=s.ranch.delivered||[];if(!Array.isArray(done)||done.some(id=>!orders.some(o=>o.id===id)))throw Error('牧场心愿记录无效。');s.ranch.delivered=[...new Set(done)];for(const id of done)s.flags[id]=true;return s;};
C.deliver=(s,id)=>{if(!orders.some(o=>o.id===id))return deliver(s,id);ensure(s);s.ranch.delivered??=[];if(s.ranch.delivered.includes(id))return no('这份牧场心意已经送到了。');const out=deliver(s,id);if(out.ok)s.ranch.delivered.push(id);return out;};
root.ZRZRanch=R;if(typeof module!=='undefined')module.exports=R;
})(typeof window!=='undefined'?window:globalThis);
