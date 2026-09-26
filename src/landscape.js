(function(root){
  'use strict';
  const D=root.ZRZData||(typeof require!=='undefined'?require('./content.js'):null);
  const W=1920,H=1152,OX=480,OY=288;
  const maps={};
  const make=()=>({props:[],paths:[],water:[],fields:[],landmarks:[],solids:[]});
  const prop=(m,kind,x,y,more={})=>m.props.push({kind,x,y,...more});
  const path=(m,x,y,w,h,kind='stone')=>m.paths.push({x,y,w,h,kind});
  const house=(m,x,y,w,h,name,style='home')=>{prop(m,'house',x,y,{w,h,name,style});m.solids.push([x+8,y+55,w-16,h-52]);};
  const place=(m,id,name,x,y,kind='rest',item)=>m.landmarks.push({id:'landmark-'+id,name,x,y,kind,...(item?{item}:{})});
  const grove=(m,coords,kind='tree')=>coords.forEach(([x,y,size=1],i)=>prop(m,kind,x,y,{size,seed:x+y+i*27}));
  let m=maps.farm=make();
  path(m,480,504,860,46);path(m,879,464,53,620);path(m,620,766,1040,49);path(m,340,350,57,660);path(m,347,1081,1010,32);path(m,370,358,327,45);path(m,1380,721,430,47);path(m,1521,204,51,775);
  house(m,576,353,225,136,'爷爷的老屋');house(m,1086,382,148,108,'禾溪小灶','kitchen');house(m,1186,539,118,98,'鸡鸭小棚','brick');
  house(m,189,247,157,116,'农具间','brick');house(m,1540,294,183,126,'种子互助屋','brick');
  m.water.push({x:1348,y:170,w:90,h:605},{x:1490,y:824,w:260,h:190,lotus:true});m.solids.push([1348,170,90,555],[1490,824,260,190]);path(m,1315,727,160,41,'wood');
  m.fields.push({x:90,y:715,w:218,h:186,type:'flower'},{x:1564,y:510,w:205,h:151,type:'rice'});
  prop(m,'well',1104,577);prop(m,'board',609,677);prop(m,'bench',1092,708);prop(m,'mailbox',646,558);prop(m,'rack',682,471);prop(m,'laundry',196,614);prop(m,'drying',560,907);prop(m,'mill',320,622);prop(m,'bike',807,488);prop(m,'gate',816,1094,{w:165,name:'禾溪小院'});
  [[746,540,115],[935,540,114],[744,713,307],[1144,669,182],[120,466,204]].forEach(([x,y,w])=>prop(m,'fence',x,y,{w}));
  [[565,489],[803,482],[1056,482],[1209,497],[1239,496]].forEach(([x,y])=>prop(m,'pot',x,y));prop(m,'jar',1069,493);prop(m,'basket',719,544,{fill:'greens'});prop(m,'basket',748,534,{fill:'tomato'});
  grove(m,[[509,424,1.1],[844,415,.9],[1284,452,1.1],[513,820,1.1],[1213,821,1.1],[119,583,1.3],[1778,730,1.2],[1788,1048,1.1]],'tree');
  grove(m,[[145,175,1],[265,159,1],[410,191,1],[530,188,1],[683,187,1],[826,189,1],[993,185,1],[1135,190,1],[1292,173,1]],'orchard');
  grove(m,[[1424,856,1.2],[1747,920,1.1]],'willow');grove(m,[[421,600,.7],[445,734,.8],[512,923,.8]],'bamboo');
  place(m,'orchard','橘子园 · 树下歇歇',440,241);place(m,'drying','晒谷场 · 翻翻生活手记',682,908,'journal');place(m,'lotus','荷塘石阶 · 钓一竿',1470,907,'fish');place(m,'seedhouse','种子互助屋 · 看看农事',1640,438,'farmcare');place(m,'flower','田埂野菜 · 轻轻采一些',318,803,'gather','wildHerb');
  m=maps.town=make();path(m,190,587,1570,77);path(m,885,270,63,827);path(m,625,526,610,48);path(m,253,337,59,638);path(m,280,899,1375,52);path(m,1524,238,51,695);path(m,277,282,1290,50);
  house(m,598,386,219,145,'许婶杂货','shop');house(m,1046,373,241,160,'禾溪合作社');house(m,944,688,169,124,'邻里食堂','kitchen');house(m,169,121,210,142,'禾溪小学');house(m,534,115,205,140,'村卫生室','clinic');house(m,1070,116,215,142,'乡村邮政');house(m,1478,115,224,137,'方记米糕','shop');house(m,206,713,171,132,'竹木工坊','brick');
  m.solids.push([1070,587,165,63],[836,508,43,48]);prop(m,'board',857,559);prop(m,'table',1154,633);prop(m,'bench',558,704);prop(m,'bench',1221,718);prop(m,'bike',1014,547);prop(m,'board',1704,873);prop(m,'pavilion',1490,839,{w:185});prop(m,'gate',801,980,{w:225,name:'禾溪 · 烟火人间'});
  for(let i=0;i<5;i++)prop(m,'basket',631+i*31,535,{fill:i%2?'greens':'tomato'});for(let i=0;i<4;i++)prop(m,'basket',1100+i*37,617,{fill:i%2?'greens':'grain'});prop(m,'rack',455,834);prop(m,'drying',435,873);prop(m,'laundry',1205,835);
  grove(m,[[479,270,1.3],[868,254,1.2],[1402,271,1.2],[141,490,1.2],[448,559,1.1],[1359,476,1.1],[1306,849,1.15],[1765,527,1.3],[1723,997,1.1]],'tree');grove(m,[[562,827,.95],[1448,959,1]],'blossom');
  m.fields.push({x:72,y:968,w:329,h:83,type:'flower'},{x:430,y:936,w:231,h:112,type:'grain'});
  place(m,'school','小学窗下 · 村里的故事',286,294,'stories');place(m,'clinic','卫生室门廊 · 歇一会儿',643,281);place(m,'post','邮政代办点 · 读来信',1178,286,'mail');place(m,'baker','方记米糕 · 看看菜谱',1593,288,'recipes');place(m,'craft','竹木工坊 · 工具维修',299,869,'tools');place(m,'stage','古樟树下 · 邻里小聚',1478,852,'gatherings');
  m=maps.bamboo=make();path(m,864,203,75,841,'earth');path(m,320,546,1290,54,'earth');path(m,677,579,51,414,'earth');path(m,370,267,56,333,'earth');path(m,1049,327,574,53,'stone');path(m,1564,351,57,574,'earth');path(m,359,901,1252,49,'earth');
  prop(m,'pavilion',1000,502,{w:133});prop(m,'bench',966,742);prop(m,'house',290,181,{w:172,h:111,name:'竹编作坊',style:'brick'});m.solids.push([300,237,152,56]);prop(m,'rack',473,366);prop(m,'basket',490,365);prop(m,'mill',1320,335);prop(m,'table',1366,385);
  for(let y=145;y<1100;y+=113)for(let x=105;x<1840;x+=124){if(m.paths.some(p=>x>p.x-65&&x<p.x+p.w+65&&y>p.y-10&&y<p.y+p.h+105)||x>940&&x<1170&&y<550||x>245&&x<520&&y<390)continue;prop(m,'bamboo',x+(y%31),y,{size:.8+((x+y)%5)*.07,seed:x+y});}
  m.water.push({x:1100,y:698,w:254,h:114,lotus:true});m.solids.push([1100,698,254,114]);grove(m,[[1372,854,1.1],[541,464,1.1],[212,948,1.1]],'tree');prop(m,'boat',1426,757);
  place(m,'bamboo-work','竹编作坊 · 看看手艺',396,325,'tools');place(m,'bamboo-pond','竹林泉眼 · 在水边歇歇',1080,755);place(m,'bamboo-herb','竹篱下的野荠菜',465,640,'gather','wildHerb');place(m,'bamboo-north','石磨旁的茶桌 · 坐坐',1356,404);place(m,'bamboo-shoot','新竹下 · 轻轻采一些',1669,495,'gather','shoot');
  m=maps.river=make();path(m,104,451,1708,55);path(m,210,808,1510,52);path(m,910,325,84,594,'wood');path(m,242,179,57,293);path(m,1300,188,52,297);path(m,313,974,1068,43);
  m.water.push({x:25,y:518,w:1870,h:245});m.solids.push([25,518,868,245],[1020,518,875,245]);path(m,888,495,144,303,'wood');
  prop(m,'pavilion',1450,440,{w:153});prop(m,'boat',1690,596);prop(m,'boat',383,714);prop(m,'well',456,445);prop(m,'basket',724,484);prop(m,'rack',1183,884);
  house(m,360,239,182,124,'河湾人家','brick');house(m,1524,878,194,132,'晒网小屋','brick');m.fields.push({x:646,y:156,w:548,h:213,type:'rice'},{x:111,y:923,w:278,h:128,type:'flower'});
  grove(m,[[131,423,1.25],[662,441,1.2],[1266,440,1.1],[1768,426,1.2],[226,827,1.3],[688,921,1.2],[1404,851,1.1]],'willow');grove(m,[[874,410,.8],[1063,927,1.1]],'blossom');
  place(m,'lotus-dock','柳荫渡口 · 抛竿',1751,488,'fish');place(m,'river-south','晒网小屋 · 查看旧事',1589,1032,'archive');place(m,'ricepath','稻田水口 · 坐听水声',1231,368);place(m,'south-bench','河湾长椅 · 坐坐',558,852);place(m,'river-herb','河畔野荠菜',413,923,'gather','wildHerb');
  m=maps.mountain=make();path(m,871,484,66,596,'earth');path(m,742,524,485,50,'stone');path(m,599,674,321,43,'earth');path(m,599,422,49,304,'earth');path(m,1097,412,49,170,'earth');path(m,914,934,723,45,'earth');path(m,1557,373,48,596,'earth');path(m,1117,369,491,45,'stone');
  prop(m,'pavilion',991,508,{w:143});prop(m,'bench',528,696);prop(m,'stone',1577,396);prop(m,'board',1607,1006);house(m,249,820,190,128,'守茶人的小屋','brick');path(m,335,941,568,40,'earth');
  for(let i=0;i<6;i++)m.fields.push({x:75+i*29,y:170+i*69,w:529-i*33,h:45,type:'tea'});for(let i=0;i<5;i++)m.fields.push({x:1168,y:580+i*62,w:310-i*21,h:43,type:'tea'});
  grove(m,[[547,483,1.1],[777,744,1.1],[1024,715,.9],[1366,504,1.1],[1711,660,1.1],[1434,1068,1.2],[623,1036,1.2],[1834,415,1.25],[862,385,1.1]],'tree');grove(m,[[1188,979,.9],[1678,877,1.1],[734,924,1.1]],'orchard');prop(m,'drying',360,960);prop(m,'basket',382,976,{fill:'greens'});
  place(m,'teahouse','守茶人的屋檐 · 歇一会儿',352,978);place(m,'terrace','梯田石阶 · 采一点新茶',643,361,'gather','tea');place(m,'lookout','望村亭 · 翻阅生活手记',1072,538,'journal');place(m,'mountain-fruit','山坳果树 · 山果',1669,882,'gather','berry');place(m,'east-view','东坡石台 · 望望村庄',1617,419);
  // Hand-placed low plants, living-work details and stepping stones around the expanded paths.
  for(const [id,coords]of Object.entries({farm:[[1480,809],[1472,972],[1772,861],[1772,1034],[1306,932],[1288,1020],[729,487],[512,719],[1121,210],[188,958]],town:[[520,568],[1344,574],[795,884],[465,912],[1400,930],[1714,755],[372,318]],bamboo:[[990,684],[1373,814],[1028,827],[555,662],[1248,400],[742,818]],river:[[1091,469],[1368,487],[736,865],[457,845],[1681,1029],[137,831]],mountain:[[730,565],[971,938],[1488,889],[709,740],[1655,408],[1111,535]]}))coords.forEach(([x,y],i)=>prop(maps[id],i%3===0?'shrub':'flowers',x,y));
  for(const [x,y]of [[1449,808],[1458,839],[1465,872],[1467,943],[1464,985],[1506,1039],[1739,1021],[1776,877]])prop(maps.farm,'stone',x,y,{size:.5});
  prop(maps.farm,'bench',1368,873);prop(maps.farm,'basket',1455,902);prop(maps.farm,'rack',1640,733);prop(maps.farm,'table',433,247);prop(maps.farm,'fence',543,866,{w:215});prop(maps.farm,'fence',1025,866,{w:265});
  prop(maps.town,'laundry',101,487);prop(maps.town,'jar',486,838);prop(maps.town,'basket',482,866);prop(maps.river,'rack',1726,966);prop(maps.mountain,'basket',632,357,{fill:'greens'});
  // Explicit groves and landmarks are deterministic, not a procedural new region.
  for(const [id,v]of Object.entries(maps)){
    for(let x=50;x<W;x+=117){prop(v,id==='bamboo'?'bamboo':'tree',x,76+(x%3)*13,{size:.85+(x%4)*.06,seed:x});if(id!=='river')prop(v,'tree',x,1141,{size:.7,seed:x+99});}
    for(let y=187;y<1070;y+=141){prop(v,'tree',38,y,{size:.95,seed:y});prop(v,'tree',1882,y,{size:1.05,seed:y+7});}
    for(const p of v.props){if(['tree','orchard','blossom','willow'].includes(p.kind))v.solids.push([p.x-7,p.y-7,14,12]);if(p.kind==='well')v.solids.push([p.x-22,p.y-24,44,22]);if(p.kind==='mill')v.solids.push([p.x-25,p.y-23,50,21]);if(p.kind==='board')v.solids.push([p.x-24,p.y-24,48,10]);}
  }
  const api={width:W,height:H,offset:{x:OX,y:OY},maps,spawn:scene=>scene==='river'?{x:610,y:476,direction:'right'}:{x:909,y:778,direction:'up'},home:{x:911,y:500,direction:'down'}};
  root.ZRZLandscape=api;if(typeof module!=='undefined')module.exports=api;
})(typeof globalThis!=='undefined'?globalThis:window);
