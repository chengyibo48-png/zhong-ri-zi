(function(root){
  'use strict';
  const D=root.ZRZData,C=root.ZRZCore,L=root.ZRZLandscape,B=root.ZRZWorld,A=root.ZRZArt;
  const WIDTH=5760,HEIGHT=2304,ROOM={width:960,height:672,interior:true},CELL=24;
  const regions=[{id:'mountain',name:'青岚茶山',x:0,y:0,color:'#849878'},{id:'town',name:'禾溪老街',x:1920,y:0,color:'#b0a380'},{id:'river',name:'柳岸水乡',x:3840,y:0,color:'#7babac'},{id:'bamboo',name:'竹影山坞',x:0,y:1152,color:'#608c70'},{id:'farm',name:'稻香小院',x:1920,y:1152,color:'#9baf67'},{id:'pasture',name:'东坡牧场',x:3840,y:1152,color:'#b8b977'}];
  const offsets=Object.fromEntries(regions.map(r=>[r.id,r]));
  const corridors=[{x:18,y:1066,w:5724,h:64},{x:18,y:2220,w:5724,h:54},{x:924,y:16,w:72,h:2272},{x:2818,y:16,w:64,h:1150},{x:2818,y:1148,w:178,h:58},{x:2952,y:1152,w:44,h:1136},{x:4764,y:16,w:72,h:2272}];
  const baseline=C.initial();
  const profiles={
    granny:['farm','旧时光小院','绣花、旧照片与收好的棉被','plum','绣架','针脚里藏着一朵很小的青菜花。','老相册','年轻的阿婆站在还没有修好的河埠前。','搪瓷缸','杯底刻着“饭要一起吃”。'],
    qiao:['farm','禾苗实验屋','绿色盆栽、种子抽屉和观察笔记','green','育苗盘','两棵豆苗，一棵向阳，一棵在认真长根。','种子柜','抽屉按春夏秋冬排好，留了一格给你的种子。','生长尺','最长的一条刻度旁写着：慢一点，也很好。'],
    lin:['town','听雨书屋','蓝白书架、学生画作与窗边阅读角','blue','故事书','书签是学生送来的银杏叶。','黑板','粉笔写着：今天观察一种新植物。','地球仪','故乡被一颗小小的纸星星标了出来。'],
    chen:['bamboo','木香工作屋','木色工作台、榫卯、工具墙','wood','榫卯台','轻轻拼合，两块木头严丝合缝。','木马','小木马的底座留了一个修补过的结。','旧木尺','刻度旁有四代人的名字。'],
    xu:['town','暖灯杂货居','红格桌布、货签和整齐账本','red','算盘','珠子清脆地响了三下。','零钱罐','罐身写着：给忘带零钱的邻居。','旧货签','“第一单：盐一袋”，纸边已经发黄。'],
    zhou:['mountain','茶风小舍','茶青、竹篓与透光茶席','tea','茶席','杯里立起一片小小的嫩叶。','焙茶筛','焙过的茶香像晴天的山坡。','登山杖','握柄磨得光滑，挂着一段旧红绳。'],
    mei:['town','米香人家','奶黄桌布、面团木案和竹蒸笼','gold','面团','揉一揉，面团圆得像刚升起的月亮。','米糕模','模底是她自己刻的小梅花。','蒸笼','第一屉总留给最早出门的邻居。'],
    ning:['farm','四季食堂居','暖橙餐桌、食谱卡和搪瓷碗','gold','食谱卡','每道菜后面都记着一个人的口味。','汤锅','浮起的热气里有南瓜的甜香。','便当盒','盒盖画着一棵歪歪的小菜苗。'],
    an:['town','薄荷小屋','干净白布、薄荷与手工花瓶','blue','药草架','薄荷叶的边缘像小小的锯齿。','急救包','每一格都有手写标签，连创可贴也按尺寸排好。','玻璃花瓶','一枝野花，让值夜后的清晨柔软一点。'],
    yu:['river','听水小屋','湖蓝地图、修补渔网与观察窗','blue','水质记录','今天的河水比去年清了一点。','修网架','补好的结整齐细密，不留小鱼会困住的口。','贝壳铃','晃一晃，有河风从屋里经过。'],
    yan:['river','光影小筑','暖灰相片墙、木框和相机台','wood','相机','快门咔嚓一声，记下一束窗边的光。','照片墙','照片的主角是邻居们做饭、赶集和打盹的样子。','胶片盒','盒子上写着：普通的一天，也要认真收藏。'],
    luo:['farm','种子暖屋','紫色织物、纸信封和种子篮','plum','种子信封','信封角上写着“留给第一次种菜的人”。','织布架','布里织了一段今年雨水的颜色。','草帽','帽檐缝着一颗很小的木纽扣。'],
    liang:['town','杏林小居','浅青药柜、老书与竹靠椅','green','听诊器','金属仍被主人擦得明亮。','诊疗本','最后一页记的是邻居送来的菜。','竹靠椅','扶手旁放着还没读完的一页医书。'],
    wu:['river','水轮人家','蓝灰工具柜、水渠图与零件盒','blue','水轮模型','轻推一下，木轮和小齿轮一起转动。','水渠图','他把每一条容易堵塞的弯都圈了出来。','扳手','柄上缠了一层布，拿起来不磨手。'],
    jiang:['town','小曲院','胭脂布帘、戏服箱与曲谱','red','留声机','响起一小段轻快的乡间曲调。','戏服箱','袖口缝着一片很细的银线叶子。','扇子','展开扇面，是旧戏台还没修好时的模样。'],
    zhouSenior:['mountain','茶隐老屋','深绿茶具、山石和老竹椅','tea','老茶壶','壶盖一合，茶香安静地留在屋里。','山石','石缝里竟然种着一小株苔草。','茶谱','空白处写着：好茶也要有人一起喝。'],
    luSenior:['bamboo','竹篾小院','竹色家具、编织篮与手艺图','wood','竹编台','一压一挑，细竹篾慢慢编成花纹。','小竹鸟','轻轻碰一下，竹鸟点了点头。','手艺册','第一页画着他小时候做坏的第一只篮子。'],
    tao:['river','远信小屋','邮绿信箱、地图与明信片墙','green','明信片','一张没有寄出的卡片写着：村里的晚霞很好看。','邮戳','今天的日期在纸上留下一个圆圆的印子。','小自行车模型','后座上还做了一只迷你的邮包。'],
    he:['mountain','村史小筑','赭色旧报、村庄沙盘与木档案柜','wood','村庄沙盘','沙盘里有你刚刚走过的那条路。','旧报纸','有人用红笔圈出了禾溪村的第一场电影。','讲述卡','卡片上提醒自己：让每个人都有机会说话。'],
    song:['bamboo','叮当修理屋','靛蓝帆布、工具架和旧收音机','blue','收音机','调一调，杂音里传来一小段天气预报。','发条钟','钟表又稳稳地走了起来。','零件盒','没有扔掉的小螺丝，终有一天派上用场。'],
    lan:['farm','叶子画房','淡粉窗帘、蜡笔与压叶标本','plum','蜡笔画','一棵树上画了四种季节。','叶子标本','这片叶子的名字还空着，等她自己发现。','纸风铃','轻轻晃动，纸叶子在光里转圈。'],
    bao:['river','风车小屋','麦黄垫子、纸风车和木积木','gold','大风车','纸叶片越转越快，他给它起名叫“南风”。','积木桥','桥底刚好能让一只玩具小船通过。','宝物罐','里面装着三颗石子和一个很认真的秘密。'],
    qi:['river','新芽记者屋','天蓝书桌、采访本与照片夹','blue','采访本','问题一：你最喜欢村里的哪一天？','小录音机','按下播放，听见一声没忍住的笑。','剪报','第一篇小报道的标题是“今天有人帮了我”。'],
    xiaohe:['bamboo','齿轮阁','陶土色桌面、机械草图与木轮','wood','机械图','一台不用电的小浇水器，已经画到第三版。','木齿轮','顺着转一圈，每一颗齿都接得刚刚好。','模型车','后斗里摆着一颗种子，他说这是重要货物。']
  };
  const themes={green:['#618a70','#c8d7b0','#e4d9b5'],blue:['#648d9d','#c8dce0','#e7dac0'],wood:['#9b7953','#d7c5a0','#ebdcb8'],red:['#ab6460','#e3c3b1','#efdfbd'],plum:['#8b748e','#d8c9d3','#e8dcbf'],gold:['#b89754','#e9dbb0','#eee2c3'],tea:['#607b58','#b9cbb0','#ddd2ae']};
  const houses=[],extraProps=[],outdoorActions=[],animalsOrigin={x:4930,y:1700};
  function overlap(a,b,pad=0){return a.x<b.x+b.w+pad&&a.x+a.w+pad>b.x&&a.y<b.y+b.h+pad&&a.y+a.h+pad>b.y;}
  function regionAt(x,y){return regions.find(r=>x>=r.x&&x<r.x+1920&&y>=r.y&&y<r.y+1152)||offsets.farm;}
  function localState(s,id){const o=offsets[id];return {...s,scene:id==='pasture'?'farm':id,player:{...s.player,x:s.player.x-o.x,y:s.player.y-o.y}};}
  const maps=Object.fromEntries(Object.entries(L.maps).map(([id,m])=>[id,structuredClone(m)]));
  maps.pasture={props:[],paths:[{x:0,y:670,w:1920,h:56,kind:'earth'},{x:905,y:0,w:62,h:1152,kind:'stone'}],fields:[{x:1180,y:780,w:560,h:270,type:'grain'}],water:[{x:1170,y:380,w:420,h:180,lotus:true}],landmarks:[],solids:[[1170,380,420,180]]};
  maps.pasture.props.push({kind:'house',x:1080,y:95,w:250,h:160,name:'东坡牧舍',style:'brick'},{kind:'house',x:270,y:130,w:185,h:124,name:'丰收粮仓',style:'brick'},{kind:'house',x:610,y:155,w:170,h:112,name:'堆肥工具房',style:'brick'});
  for(const p of maps.pasture.props)maps.pasture.solids.push([p.x+8,p.y+55,p.w-16,p.h-52]);
  for(let i=0;i<9;i++){maps.pasture.props.push({kind:'fence',x:240+i*160,y:355,w:132},{kind:'drying',x:110+i*135,y:740});}
  for(const [x,y]of [[140,300],[580,310],[840,180],[1670,300],[1730,750],[160,1100]])maps.pasture.props.push({kind:'tree',x,y,size:1.1,seed:x});
  maps.pasture.props.push({kind:'well',x:650,y:610},{kind:'rack',x:770,y:415},{kind:'table',x:560,y:420},{kind:'basket',x:1240,y:320},{kind:'basket',x:1290,y:321},{kind:'bench',x:1600,y:620});
  maps.pasture.props.push({kind:'haystack',x:350,y:590},{kind:'haystack',x:435,y:613},{kind:'haystack',x:785,y:542},{kind:'cart',x:1035,y:300},{kind:'cart',x:405,y:305},{kind:'scarecrow',x:1210,y:829},{kind:'scarecrow',x:1690,y:978},{kind:'fence',x:265,y:638,w:255},{kind:'board',x:1120,y:295});
  for(const [x,y]of [[560,530],[820,800],[1640,664],[1550,1040],[1740,583]])maps.pasture.props.push({kind:'flowers',x,y},{kind:'shrub',x:x+32,y:y+18});
  for(const [x,y,w,h]of [[318,562,65,28],[400,585,70,28],[753,514,64,28],[1000,282,68,30],[375,287,62,28]])maps.pasture.solids.push([x,y,w,h]);
  // Existing public buildings remain functional and every front door gains an interior.
  for(const r of regions)for(const p of maps[r.id].props.filter(p=>p.kind==='house')){
    const id='building-'+r.id+'-'+houses.length;
    houses.push({...p,id,region:r.id,x:p.x+r.x,y:p.y+r.y,owner:null,theme:p.style==='brick'?'wood':r.id==='river'?'blue':'green',door:{x:p.x+r.x+p.w*.48,y:p.y+r.y+p.h+21}});
  }
  for(const [id,pf]of Object.entries(profiles)){
    const region=offsets[pf[0]],m=maps[region.id];let candidate=null;
    const candidates=[];for(let y=60;y<900;y+=32)for(let x=48;x<1740;x+=32)candidates.push({x,y,w:162,h:120});
    for(const p of candidates){const reserved={x:p.x-28,y:p.y-25,w:218,h:197};if(corridors.some(q=>overlap({...reserved,x:reserved.x+region.x,y:reserved.y+region.y},q,12)))continue;if(region.id==='farm'&&overlap(reserved,{x:766,y:554,w:263,h:151},22))continue;if(B.points({...baseline,scene:region.id}).some(q=>!['npc','travel','gather'].includes(q.kind)&&overlap(reserved,{x:q.x-28,y:q.y-28,w:56,h:56})))continue;if(m.water.some(w=>overlap(reserved,w,25))||m.props.some(q=>q.kind==='house'&&overlap(reserved,q,30))||m.paths.some(q=>overlap({x:p.x,y:p.y,w:p.w,h:p.h},q,5)))continue;candidate=p;break;}
    if(!candidate)throw Error('No safe homestead for '+id);
    const p=candidate,clear={x:p.x-25,y:p.y-65,w:p.w+60,h:p.h+155};
    m.props=m.props.filter(q=>q.kind==='house'||!(q.x>clear.x&&q.x<clear.x+clear.w&&q.y>clear.y&&q.y<clear.y+clear.h));
    m.solids=m.solids.filter(q=>!overlap({x:q[0],y:q[1],w:q[2],h:q[3]},clear));
    const house={kind:'house',...p,id:'home-'+id,region:region.id,owner:id,theme:pf[3],name:D.npcs.find(n=>n.id===id).name+'家',style:['wood','gold'].includes(pf[3])?'brick':'home'};
    m.props.push(house);m.solids.push([p.x+8,p.y+55,p.w-16,p.h-52]);
    m.paths.push({x:p.x-12,y:p.y+p.h+3,w:p.w+26,h:43,kind:'earth'});
    for(const q of [{kind:'pot',x:p.x-8,y:p.y+p.h+1},{kind:'jar',x:p.x+p.w+17,y:p.y+p.h+8},{kind:'bench',x:p.x+p.w-42,y:p.y+p.h+53}])m.props.push(q);
    houses.push({...house,x:p.x+region.x,y:p.y+region.y,door:{x:p.x+region.x+p.w*.48,y:p.y+region.y+p.h+24}});
  }
  // Life between houses: allotments, carts, wells, work courts and planted verge clusters.
  for(const r of regions){const m=maps[r.id];for(let y=210;y<1020;y+=245)for(let x=145;x<1850;x+=280){const area={x:x-45,y:y-55,w:120,h:112};if(m.water.some(p=>overlap(area,p,20))||m.props.some(p=>p.kind==='house'&&overlap(area,p,40))||m.paths.some(p=>overlap(area,p,15)))continue;
      const n=(Math.floor(x/280)+Math.floor(y/245)*3)%5; m.props.push({kind:['drying','laundry','flowers','rack','shrub'][n],x,y},{kind:n%2?'basket':'pot',x:x+60,y:y+17});
    }}

  function inCorridor(x,y,margin=0){return corridors.some(p=>x>p.x+margin&&x<p.x+p.w-margin&&y>p.y+margin&&y<p.y+p.h-margin);}
  const allProps=[];for(const r of regions)for(const p of maps[r.id].props){const q={...p,x:p.x+r.x,y:p.y+r.y,region:r.id};if(p.kind!=='house'&&inCorridor(q.x,q.y))continue;allProps.push(q);}
  const solids=regions.flatMap(r=>maps[r.id].solids.map(([x,y,w,h])=>[x+r.x,y+r.y,w,h]));
  const extraPlot=i=>({x:3940+(i-24)%12*43,y:2000+Math.floor((i-24)/12)*39});
  const plotPosition=i=>i<24?{x:B.plotPosition(i).x+1920,y:B.plotPosition(i).y+1152}:extraPlot(i);
  const plotAt=(x,y)=>{for(let i=0;i<72;i++){const p=plotPosition(i);if(x>p.x-19&&x<p.x+19&&y>p.y-20&&y<p.y+14)return i;}return -1;};
  const chores=[['brush','梳毛桩','brush',4945,1514],['trough','添水槽','water',5170,1780],['hay','补充草架','feed',4880,1640],['compost','翻拌堆肥','compost',4470,1500],['churn','手摇乳桶','churn',5400,1490],['windmill','试转风车','wind',5580,1900],['wash','洗菜台','wash',4540,2070],['bell','牧场铜铃','bell',4860,1855]];
  for(const [id,name,action,x,y]of chores)outdoorActions.push({id:'chore-'+id,name,kind:'chore',action,x,y});
  for(const r of regions)outdoorActions.push({id:'spot-'+r.id,name:({town:'老街木车 · 整理菜篮',bamboo:'竹编歇脚台 · 编一朵竹花',river:'柳岸风铃 · 听听风',mountain:'山间观景镜 · 看云海',farm:'晒谷竹匾 · 翻一翻',pasture:'稻草风车 · 轻轻转动'})[r.id],kind:'ambient',action:r.id,x:r.x+1750,y:r.y+1060});
  function roomObjects(h){const kitchenObjects=root.ZRZKitchen?.roomObjects?.(h);if(kitchenObjects)return kitchenObjects;const ranchObjects=root.ZRZRanch?.roomObjects?.(h);if(ranchObjects)return ranchObjects;const pf=h.owner?profiles[h.owner]:null;
    const services=/杂货/.test(h.name)?['shop','货架 · 买卖']:/灶|食堂|米糕/.test(h.name)?['cook','灶台 · 做家常菜']:/邮/.test(h.name)?['mail','收发乡间来信']:/小学/.test(h.name)?['stories','黑板上的乡村故事']:/卫生/.test(h.name)?['rest','坐诊椅 · 休息']:/竹编|工坊|工具/.test(h.name)?['tools','工作台 · 整理工具']:/粮仓|农具/.test(h.name)?['storage','储物架']:/牧舍|小棚|鸡鸭舍|羊圈|猪圈/.test(h.name)?['animals','照料伙伴']:/合作/.test(h.name)?['gatherings','乡亲们的聚会']:/种子/.test(h.name)?['farmcare','农事观察台']:['archive','翻看屋里的旧物'];
    const labels=pf?[pf[4],pf[6],pf[8]]:services[0]==='shop'?['算盘','旧货签','邻里账本']:services[0]==='cook'?['面团','蒸笼','食谱卡']:services[0]==='mail'?['明信片','邮戳','邮袋']:services[0]==='stories'?['黑板','故事书','蜡笔画']:services[0]==='animals'?['草帽','伙伴观察本','牧场铜铃']:[h.name.includes('老屋')?'老相册':'窗边旧物','主人手记','回忆抽屉'];
    return [{id:'room-exit',kind:'exit',name:'推门回到村庄',x:480,y:590},...labels.map((name,i)=>({id:h.id+'-egg-'+i,kind:'egg',index:i,name:'动手看看 · '+name,x:[260,690,725][i],y:[305,302,500][i],house:h.id})),{id:'room-tea',kind:'tea',name:'倒一杯热茶',x:430,y:395},{id:'room-bed',kind:h.name==='爷爷的老屋'?'sleep':'bed-visit',name:h.name==='爷爷的老屋'?'床铺 · 睡个好觉':'整理坐垫',x:220,y:508},...(!h.owner?[{id:'room-service',kind:services[0],name:services[1],x:620,y:536}]:[])];
  }
  function insideBlocked(x,y){if(x<113||x>847||y<205||y>602)return true;return [[164,254,160,37],[627,248,140,40],[658,443,144,38],[158,447,152,53],[380,328,140,41]].some(([a,b,w,h])=>x>a&&x<a+w&&y>b&&y<b+h);}
  function blocked(s,x,y){if(s.village?.interior)return insideBlocked(x,y);if(!Number.isFinite(x)||!Number.isFinite(y)||x<24||y<38||x>WIDTH-24||y>HEIGHT-24)return true;
    if(inCorridor(x,y,7)&&!houses.some(h=>x>h.x+2&&x<h.x+h.w-2&&y>h.y+51&&y<h.y+h.h+3))return false;
    return solids.some(([a,b,w,h])=>x>a-6&&x<a+w+6&&y>b-3&&y<b+h+5);
  }
  function clearLine(s,a,b){const n=Math.ceil(Math.hypot(b.x-a.x,b.y-a.y)/6);for(let i=1;i<=n;i++)if(blocked(s,a.x+(b.x-a.x)*i/n,a.y+(b.y-a.y)*i/n))return false;return true;}
  let grid=null,roomGrid=null;const worldEdges=new Map(),roomEdges=new Map();
  function route(s,x,y,from=s.player){if(blocked(s,x,y))return [];if(clearLine(s,from,{x,y}))return [{x,y}];const room=!!s.village?.interior,w=room?ROOM.width:WIDTH,h=room?ROOM.height:HEIGHT,cols=Math.ceil(w/CELL),rows=Math.ceil(h/CELL),size=cols*rows;
    let g=room?roomGrid:grid;if(!g){g=new Uint8Array(size);for(let i=0;i<size;i++)g[i]=blocked(s,(i%cols)*CELL+12,Math.floor(i/cols)*CELL+12)?1:0;if(room)roomGrid=g;else grid=g;}
    const cell=p=>{const cx=Math.floor(p.x/CELL),cy=Math.floor(p.y/CELL),candidates=[];for(let yy=Math.max(0,cy-2);yy<=Math.min(rows-1,cy+2);yy++)for(let xx=Math.max(0,cx-2);xx<=Math.min(cols-1,cx+2);xx++){const i=yy*cols+xx,q={x:xx*CELL+12,y:yy*CELL+12};if(!g[i]&&clearLine(s,p,q))candidates.push({i,...q,d:Math.hypot(q.x-p.x,q.y-p.y)});}return candidates.sort((a,b)=>a.d-b.d)[0];};
    const a=cell(from),b=cell({x,y});if(!a||!b)return [];const prev=new Int32Array(size);prev.fill(-2);prev[a.i]=-1;const q=new Int32Array(size);q[0]=a.i;let tail=1,found=false;
    for(let k=0;k<tail;k++){const v=q[k];if(v===b.i){found=true;break;}for(const d of [-1,1,-cols,cols]){const n=v+d;if(n<0||n>=size||(Math.abs(d)===1&&Math.floor(v/cols)!==Math.floor(n/cols))||g[n]||prev[n]!==-2)continue;const memo=room?roomEdges:worldEdges,key=Math.min(v,n)*size+Math.max(v,n);if(!memo.has(key))memo.set(key,clearLine(s,{x:v%cols*CELL+12,y:Math.floor(v/cols)*CELL+12},{x:n%cols*CELL+12,y:Math.floor(n/cols)*CELL+12}));if(!memo.get(key))continue;prev[n]=v;q[tail++]=n;}}
    if(!found)return [];const result=[{x,y}];for(let v=b.i;v!==-1;v=prev[v])result.push({x:v%cols*CELL+12,y:Math.floor(v/cols)*CELL+12});result.reverse();
    const smooth=[];let last=from;for(let i=0;i<result.length;){let next=Math.min(result.length-1,i+10);while(next>i&&!clearLine(s,last,result[next]))next--;smooth.push(result[next]);last=result[next];i=next+1;}return smooth;
  }
  function safePosition(s,p){if(!blocked(s,p.x,p.y))return {...p};for(let r=12;r<800;r+=12)for(let a=0;a<24;a++){const q={x:p.x+Math.cos(a*Math.PI/12)*r,y:p.y+Math.sin(a*Math.PI/12)*r,direction:p.direction||'down'};if(!blocked(s,q.x,q.y))return q;}return {x:2831,y:1652,direction:'down'};}
  function homeOf(id){return houses.find(h=>h.owner===id);}
  function initialVillage(){return {interior:null,returnPoint:null,memories:{},chores:{},npc:{},riding:false};}
  const old={initial:C.initial,load:C.load,nextDay:C.nextDay,npcScene:C.npcScene};
  function prepare(s,source){s.village=initialVillage();if(s.plots.length===24)s.plots.push(...Array.from({length:48},()=>({tilled:false,crop:null,growth:0,watered:false,soil:2,lastGroup:null,repeats:0,care:0,pest:false})));
    if(source?.worldRevision!==3){const r=offsets[s.scene];s.player.x+=r.x;s.player.y+=r.y;}else if(source.village){const v=source.village;if(v.interior!==null&&v.interior!==undefined&&!houses.some(h=>h.id===v.interior))throw Error('房屋存档数据无效。');s.village.interior=v.interior||null;
      if(v.returnPoint&&Number.isFinite(v.returnPoint.x)&&Number.isFinite(v.returnPoint.y)&&v.returnPoint.x>=24&&v.returnPoint.x<=WIDTH-24&&v.returnPoint.y>=38&&v.returnPoint.y<=HEIGHT-24)s.village.returnPoint={x:v.returnPoint.x,y:v.returnPoint.y,direction:'down'};
      for(const type of ['memories','chores'])for(const [k,d]of Object.entries(v[type]||{})){if(Number.isInteger(d)&&d>=0&&d<=s.day&&k.length<90)s.village[type][k]=d;}
      for(const n of D.npcs){const q=v.npc?.[n.id];if(q&&Number.isFinite(q.x)&&Number.isFinite(q.y)&&q.x>=24&&q.x<=WIDTH-24&&q.y>=38&&q.y<=HEIGHT-24)s.village.npc[n.id]={x:q.x,y:q.y,direction:['up','down','left','right'].includes(q.direction)?q.direction:'down',room:q.room===homeOf(n.id).id?q.room:null};}
    }
    s.worldRevision=3;for(const n of D.npcs){if(s.village.npc[n.id]&&!s.village.npc[n.id].room){const p=safePosition({village:{}},s.village.npc[n.id]);Object.assign(s.village.npc[n.id],p);}if(!s.village.npc[n.id]){const h=homeOf(n.id),p=safePosition({village:{}},h.door);s.village.npc[n.id]={x:p.x,y:p.y,direction:'down',room:s.minutes<420||s.minutes>=1170?h.id:null};}}
    s.player=safePosition(s,s.player);if(s.village.interior){const h=houses.find(h=>h.id===s.village.interior);s.scene=h.region==='pasture'?'farm':h.region;s.village.returnPoint||={...h.door};}else{s.scene=regionAt(s.player.x,s.player.y).id;if(s.scene==='pasture')s.scene='farm';}return s;
  }
  C.initial=(...a)=>prepare(old.initial(...a));
  C.load=raw=>{let v;try{v=typeof raw==='string'?JSON.parse(raw):structuredClone(raw);}catch(_){throw Error('存档无法解析。');}return prepare(old.load(v),v);};
  C.nextDay=s=>{const before={player:{...s.player},scene:s.scene,interior:s.village.interior,returnPoint:s.village.returnPoint};const r=old.nextDay(s);s.player=before.player;s.scene=before.scene;s.worldRevision=3;s.village.interior=before.interior;s.village.returnPoint=before.returnPoint;s.village.riding=false;for(const n of D.npcs){const h=homeOf(n.id);s.village.npc[n.id]={...h.door,direction:'down',room:h.id};}resetRuntime(s);return r;};
  C.npcScene=(s,n)=>{const p=s.village?.npc[n.id];if(!p)return old.npcScene(s,n);const id=p.room?homeOf(n.id).region:regionAt(p.x,p.y).id;return id==='pasture'?'farm':id;};
  const runtime=new WeakMap();
  function stateRuntime(s){let r=runtime.get(s);if(!r){r={clock:0,actors:{},fx:[],bubble:[],action:null};runtime.set(s,r);}return r;}
  function resetRuntime(s){runtime.delete(s);}
  function workPoint(s,n){const r=offsets[n.home]||offsets.farm,pts=B.points({...s,scene:r.id,player:{x:909,y:778}}),p=pts.find(p=>p.id===n.id)||{x:700+(D.npcs.indexOf(n)%4)*120,y:760};return safePosition({village:{}},{x:p.x+r.x,y:p.y+r.y});}
  function stepActor(s,p,target,dt,speed,rt,inside=false){const nav={village:inside?{interior:inside}:{}};if(!rt.path?.length)rt.path=route(nav,target.x,target.y,p);if(!rt.path.length)return false;let budget=speed*dt;while(rt.path.length&&budget>0){const q=rt.path[0],dx=q.x-p.x,dy=q.y-p.y,d=Math.hypot(dx,dy);if(d<.01){rt.path.shift();continue;}p.direction=Math.abs(dx)>Math.abs(dy)?dx>0?'right':'left':dy>0?'down':'up';const v=Math.min(d,budget);const nx=p.x+dx/d*v,ny=p.y+dy/d*v;if(blocked(nav,nx,ny)){rt.path=[];return false;}p.x=nx;p.y=ny;budget-=v;if(d<=v+.01)rt.path.shift();}return true;}
  function update(s,dt){const rt=stateRuntime(s);rt.clock+=dt;
    if(root.ZRZRanch)root.ZRZRanch.update(s,dt);else for(let i=0;i<s.animals.length;i++){const a=animalPosition(s,i),base={x:4990+i*140,y:1930+i%2*125},focus=rt.animalFocus&&rt.clock<rt.animalFocus.until?rt.animalFocus:null;if(a.focus!==focus){a.focus=focus;a.path=[];a.target=null;}if(!a.target||!focus&&rt.clock>a.next){a.target=safePosition({village:{}},focus?{x:focus.x-55+i*53,y:focus.y+42+i%2*19}:{x:base.x+Math.sin(rt.clock*.15+i*3)*65,y:base.y+Math.cos(rt.clock*.13+i)*45});a.next=rt.clock+9;a.path=[];}if(Math.hypot(a.x-a.target.x,a.y-a.target.y)>3)stepActor(s,a,a.target,dt,focus?94:28,a);}
    for(const [i,n]of D.npcs.entries()){const p=s.village.npc[n.id],h=homeOf(n.id),a=rt.actors[n.id]||=( {wait:2+i*.31,path:[],phase:'',walking:false});const night=s.minutes<420+i%4*9||s.minutes>=1110+i%6*8,wet=['雨','台风','小雪','寒潮'].includes(C.weather(s.day)),phase=night?'home':wet?'shelter':s.minutes<720?'work':s.minutes<870?'lunch':'wander';
      if(a.phase!==phase){a.path=[];a.target=null;a.phase=phase;a.wait=0;}
      if(phase==='home'||phase==='shelter'){if(p.room===h.id){a.inside||={x:565,y:430,direction:'left'};a.insideRt||={path:[],wait:i*.4,target:null};const q=a.insideRt;if(q.wait>0){q.wait-=dt;a.walking=false;}else{q.target||=[{x:560,y:430},{x:480,y:491},{x:344,y:310},{x:738,y:360}][Math.floor(rt.clock/7+i)%4];a.walking=stepActor(s,a.inside,q.target,dt,34,q,h.id);if(!q.path.length){q.target=null;q.wait=3+i%5;}}continue;}a.target=h.door;if(Math.hypot(p.x-h.door.x,p.y-h.door.y)<10){p.room=h.id;a.path=[];a.walking=false;continue;}}
      else{if(p.room){p.room=null;p.x=h.door.x;p.y=h.door.y;a.wait=.4;}if(a.wait>0){a.wait-=dt;a.walking=false;continue;}if(!a.target){const center=phase==='lunch'?h.door:workPoint(s,n),angle=rt.clock*.21+i*2.3,spread=phase==='work'?75:180;a.target=safePosition({village:{}},{x:center.x+Math.cos(angle)*spread,y:center.y+Math.sin(angle)*spread});}}
      const dist=Math.hypot(p.x-s.player.x,p.y-s.player.y);if(!s.village.interior&&dist<58){a.walking=false;continue;}a.walking=stepActor(s,p,a.target,dt,n.tier==='child'?92:n.age>60?56:76,a);
      if(!a.path.length){a.target=null;a.wait=3+(i%5)*1.1;a.walking=false;}
    }
    rt.fx=rt.fx.filter(e=>rt.clock-e.at<e.duration);rt.bubble=rt.bubble.filter(e=>rt.clock-e.at<e.duration);if(rt.action&&rt.clock-rt.action.at>rt.action.duration)rt.action=null;
    if(!s.village.interior){const region=regionAt(s.player.x,s.player.y),scene=region.id==='pasture'?'farm':region.id;if(s.scene!==scene){s.scene=scene;return true;}}return false;
  }
  function npcPoint(s,n){const p=s.village.npc[n.id],h=homeOf(n.id);if(s.village.interior){if(p.room!==s.village.interior)return null;return {id:n.id,kind:'npc',npc:n,name:n.name+' · 在家',...(stateRuntime(s).actors[n.id]?.inside||{x:565,y:430,direction:'left'})};}if(p.room)return null;return {id:n.id,kind:'npc',npc:n,name:n.name+' · '+(stateRuntime(s).actors[n.id]?.phase==='work'?'工作与散步':'在村里走走'),...p};}
  function animalPosition(s,i){if(root.ZRZRanch)return root.ZRZRanch.position(s,s.animals[i].id);const rt=stateRuntime(s);rt.animals||=[];return rt.animals[i]||=( {x:4990+i*140,y:1930+i%2*125,direction:'down',path:[],target:null,next:0});}
  function points(s,all=false){if(s.village.interior){const h=houses.find(h=>h.id===s.village.interior);return roomObjects(h).concat(D.npcs.map(n=>npcPoint(s,n)).filter(Boolean),root.ZRZRanch?.points(s)||[]);}
    let list=[];for(const r of regions.filter(r=>r.id!=='pasture')){const local=localState(s,r.id);list.push(...B.points(local).filter(p=>!['npc','travel','animal','sleep','cook','shop'].includes(p.kind)&&p.id!=='pet').map(p=>({...p,id:p.id,region:r.id,...safePosition({village:{}},{x:p.x+r.x,y:p.y+r.y})})));}
    list.push(...houses.map(h=>({id:h.id,kind:'enter',name:h.owner?D.npcs.find(n=>n.id===h.owner).name+'家 · 推门拜访':h.name+' · 推门进去',...h.door,house:h.id})),...outdoorActions,...D.npcs.map(n=>npcPoint(s,n)).filter(Boolean),...(root.ZRZRanch?root.ZRZRanch.points(s):s.animals.map((a,i)=>({id:a.id,kind:'animal',name:a.name+' · '+(a.ready?'收取产物':'喂食与亲近'),...animalPosition(s,i)}))),root.ZRZRanch?root.ZRZRanch.petPoint(s):{id:'pet',kind:'pet',name:s.pet.name+' · 陪它玩',x:2775,y:1690});
    return all?list:list.filter(p=>Math.abs(p.x-s.player.x)<1200&&Math.abs(p.y-s.player.y)<900);
  }
  function destination(s,type,id){if(type==='animal'&&root.ZRZRanch)return root.ZRZRanch.destination(s,id);if(type==='cook'||type==='shop'){const h=houses.find(h=>h.name===(type==='cook'?'禾溪小灶':'许婶杂货'));return {id:h.id,house:h.id,kind:'enter',name:h.name,...h.door};}if(type==='npc'){const n=D.npcs.find(n=>n.id===id),p=npcPoint({...s,village:{...s.village,interior:null}},n);return p||{id:homeOf(id).id,house:homeOf(id).id,kind:'enter',name:n.name+'家',...homeOf(id).door};}if(type==='house'){const h=houses.find(h=>h.id===id);return h?{id:h.id,house:h.id,kind:'enter',name:h.name,...h.door}:null;}if(type==='region'){const r=offsets[id];return r?{id:'district-'+id,kind:'walk',name:r.name,...safePosition({village:{}},{x:r.x+({mountain:960,town:950,river:1060,bamboo:950,farm:1000,pasture:1020}[id]),y:r.y+({mountain:700,town:780,river:715,bamboo:680,farm:760,pasture:680}[id])})}:null;}return points({...s,village:{...s.village,interior:null}},true).find(p=>p.id===id||p.kind===type&&(!id||p.region===id));}
  function enter(s,id){const h=houses.find(h=>h.id===id);if(!h||s.village.interior||Math.hypot(s.player.x-h.door.x,s.player.y-h.door.y)>70)return false;s.village.returnPoint={x:h.door.x,y:h.door.y+12,direction:'down'};s.village.interior=id;s.village.riding=false;s.scene=h.region==='pasture'?'farm':h.region;s.player={x:480,y:567,direction:'up'};return true;}
  function leave(s){if(!s.village.interior)return false;const h=houses.find(h=>h.id===s.village.interior);s.village.interior=null;s.player=safePosition(s,s.village.returnPoint||h.door);s.village.returnPoint=null;return true;}
  function feedback(s,p,kind,text='',duration=1.2,item=null){const r=stateRuntime(s);r.fx.push({x:p.x,y:p.y,kind,item,at:r.clock,duration});r.action={kind,at:r.clock,duration};if(p.kind==='chore'&&['feed','brush','water','bell'].includes(kind))r.animalFocus={x:p.x,y:p.y,until:r.clock+24};if(text)r.bubble.push({x:p.x,y:p.y-55,text,at:r.clock,duration:4});}
  function inspect(s,p){const h=houses.find(h=>h.id===s.village.interior);if(!h)return {ok:false,msg:'走进小屋再看看。'};const pf=h.owner?profiles[h.owner]:null,first=s.village.memories[p.id]===undefined;s.village.memories[p.id]=s.day;const msg=pf?pf[5+p.index*2]:'这里收藏着'+h.name+'平常却珍贵的一天。';if(first){C.log(s,'在'+h.name+'发现了'+p.name.replace('动手看看 · ','')+'。');if(h.owner)s.relations[h.owner].points=Math.min(100,s.relations[h.owner].points+1);}feedback(s,p,['inspect','music','spark'][p.index],msg,2);return {ok:true,msg:first?'收下一段屋里的小故事。':'又看见了熟悉的小细节。'};}
  function chore(s,p){const key=p.id+'-'+s.day;if(s.village.chores[p.id]===s.day&&!['wind','bell','wash'].includes(p.action))return {ok:false,msg:'今天已经照料好了。'};let msg='';if(p.action==='feed'){if(!C.has(s,{feed:1}))return {ok:false,msg:'带一份草谷饲料来补草架吧。'};C.consume(s,{feed:1});s.animals.forEach(a=>a.fed=true);msg='草架添满，伙伴们慢慢围了过来。';}else if(p.action==='brush'){s.animals.forEach(a=>a.bond=Math.min(100,a.bond+2));msg='浮毛梳干净，伙伴们舒服地眯起眼。';}else if(p.action==='compost'){if(!C.labor(s,3,8))return {ok:false,msg:'歇一会儿再来翻堆肥。'};C.add(s,'compost',1);msg='翻好堆肥，收下一份熟堆肥。';}else if(p.action==='churn'){if(!C.has(s,{milk:1}))return {ok:false,msg:'带一份鲜奶来，试试手摇乳桶。'};C.consume(s,{milk:1});s.stamina=Math.min(100,s.stamina+15);msg='摇匀一杯温奶，体力恢复 15。';}else if(p.action==='water'){s.animals.forEach(a=>a.bond=Math.min(100,a.bond+1));msg='清水缓缓流进槽里。';}else msg=({wind:'风车转起来了，叶片投下一圈圈影子。',bell:'叮——铜铃把伙伴们唤了过来。',wash:'水珠落下，菜叶亮晶晶。'})[p.action]||'轻轻动一动，村庄有了回应。';s.village.chores[p.id]=s.day;feedback(s,p,p.action,msg,2);return {ok:true,msg};}
  function hit(s,x,y){if(!s.village.interior){const i=plotAt(x,y);if(i>=0)return {id:'plot-'+i,kind:'plot',index:i,...plotPosition(i),name:'菜地'};}return points(s).filter(p=>Math.abs(x-p.x)<29&&y>p.y-44&&y<p.y+20).sort((a,b)=>Math.hypot(a.x-x,a.y-y)-Math.hypot(b.x-x,b.y-y))[0]||null;}
  function title(s){const h=houses.find(h=>h.id===s.village.interior);return h?h.owner?profiles[h.owner][1]:h.name:regionAt(s.player.x,s.player.y).name;}
  const api={WIDTH,HEIGHT,ROOM,regions,offsets,maps,houses,profiles,themes,allProps,solids,corridors,outdoorActions,chores,regionAt,localState,plotPosition,plotAt,blocked,clearLine,route,safePosition,homeOf,roomObjects,prepare,update,stateRuntime,npcPoint,animalPosition,points,destination,enter,leave,feedback,inspect,chore,hit,title,resetRuntime};
  root.ZRZVillage=api;root.ZRZWorld={...B,points,hit,route,blocked,clearLine,plotAt,plotPosition,width:WIDTH,height:HEIGHT,restorePosition:s=>{const p=safePosition(s,s.player),changed=p.x!==s.player.x||p.y!==s.player.y;s.player=p;return changed;},getBounds:s=>s.village?.interior?ROOM:{width:WIDTH,height:HEIGHT}};
})(typeof globalThis!=='undefined'?globalThis:window);
