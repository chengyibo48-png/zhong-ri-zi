(function(root){
'use strict';
const V=root.ZRZVillage,C=root.ZRZCore,B=root.ZRZBuild;
const TILE=32;
const biomes={
 farm:{name:'稻香小院',material:'earth',accent:'#bb9c61',plants:'flowers'},
 town:{name:'禾溪老街',material:'stone',accent:'#9fa799',plants:'planter'},
 river:{name:'柳岸水乡',material:'sand',accent:'#bbc3a1',plants:'reeds'},
 bamboo:{name:'竹影山坞',material:'leaves',accent:'#819266',plants:'fern'},
 mountain:{name:'青岚茶山',material:'gravel',accent:'#9aa18c',plants:'tea'},
 pasture:{name:'东坡牧场',material:'earth',accent:'#b4a476',plants:'clover'}
};
// Each asset shares a bottom-centre anchor between painting and collision.
// Ground decoration is deliberately traversable; only the visible base blocks feet.
const assets={
 bench:{name:'竹木歇脚凳',w:64,h:29,box:[-30,-9,60,13],service:'rest'},
 teaRack:{name:'竹匾晾茶架',w:76,h:43,box:[-35,-10,70,14],service:'forage'},
 grainMat:{name:'簸箕晒谷席',w:84,h:18,box:null,service:'farmcare',layer:'ground'},
 loom:{name:'竹篾编织架',w:70,h:66,box:[-32,-8,64,12],service:'tools'},
 washstone:{name:'青石洗衣台',w:70,h:26,box:[-33,-14,66,19],service:'forage'},
 board:{name:'乡村物产牌',w:52,h:62,box:[-24,-7,48,11],service:'economy'},
 jars:{name:'封泥酱缸',w:68,h:33,box:[-30,-13,60,18],service:'processing'},
 hayrack:{name:'草料编栏',w:72,h:43,box:[-34,-11,68,16],service:'animals'},
 weather:{name:'竹竿风向标',w:56,h:83,box:[-6,-5,12,10],service:'weather'},
 lamp:{name:'防雨石脚灯',w:22,h:67,box:[-8,-5,16,10]},
 woodpile:{name:'码齐的柴垛',w:44,h:25,box:[-20,-9,40,12]},
 basket:{name:'竹编生活篮',w:24,h:20,box:null},
 plants:{name:'乡土植物丛',w:34,h:30,box:null},
 stones:{name:'苔石地脚',w:32,h:12,box:null,layer:'ground'}
};
for(const [id,name]of Object.entries({seedTray:"分格育苗盘",scale:"木座杆秤",netCoil:"收拢渔网",bambooBundle:"分捆竹料",teaCrate:"竹筐茶青",haybale:"扎绳草捆"}))assets[id]={...assets.woodpile,name};
for(const a of Object.values(assets))Object.assign(a,{anchor:'bottom-center',layer:a.layer||'objects',fixed:true,seasons:[0,1,2,3],biomes:Object.keys(biomes)});
const plans=[
 ['farm','晒谷小场','grainMat',2695,2142,'稻谷摊成薄层，木耙留下细细的纹路。'],
 ['farm','育苗歇脚角','bench',3115,1382,'竹凳旁的陶盆里，幼苗顺着日光长。'],
 ['farm','田边观风处','weather',2855,1502,'看布尾与风向，再决定灌溉和遮雨。'],
 ['town','供销点货角','board',3335,530,'算盘、秤砣与货签，记着禾溪的物产行情。'],
 ['town','酱香晒缸巷','jars',3695,930,'深浅不同的酱缸系着布盖，石板留下日常磨痕。'],
 ['town','街口茶凳','bench',3455,1010,'旧长凳、搪瓷杯，给赶集人留一处歇脚。'],
 ['river','石埠洗衣角','washstone',515,2454,'搓衣石磨得光滑，岸边芦苇依着风轻摆。'],
 ['river','渔家晒篾架','loom',1455,2694,'竹篾与晒网分层搭开，留出走向水边的路。'],
 ['river','芦岸歇脚处','bench',1675,2654,'望水歇脚，沙地上留下零碎足印。'],
 ['bamboo','竹匠编篾角','loom',395,1982,'竹篾按长短收拢，编到一半的纹样挂在架上。'],
 ['bamboo','林缘药草匾','teaRack',1455,1942,'竹匾旁的蕨叶遮着湿土，先辨认再采集。'],
 ['bamboo','竹荫茶凳','bench',695,2162,'落叶铺在石头边，凳下留出干爽的脚踏。'],
 ['mountain','茶青晾晒坪','teaRack',1715,690,'嫩叶薄薄铺开，山风从竹匾间穿过。'],
 ['mountain','山路歇肩处','bench',355,710,'挑担的人把竹篮放在石旁，坐下喝口茶。'],
 ['mountain','茶坡望风标','weather',1155,310,'风向布尾越过茶坡，远处碎石仍留出山道。'],
 ['pasture','草料整理角','hayrack',2195,2874,'干草按捆摆放，通往圈门的道路保持宽敞。'],
 ['pasture','轮牧歇脚处','bench',2675,3094,'矮凳旁长着三叶草，隔着围栏看伙伴散步。'],
 ['pasture','南坡物产亭牌','board',3635,2774,'羊毛、鲜乳与谷物各有去处，交货前先看行情。']
];
const intersects=(a,b,p=0)=>a.x<b.x+b.w+p&&a.x+a.w>b.x-p&&a.y<b.y+b.h+p&&a.y+a.h>b.y-p;
const hash=(x,y,z=0)=>{let n=Math.imul(x+374761393,668265263)^Math.imul(y+z*73,1274126177);n=Math.imul(n^(n>>>13),1274126177);return (n^(n>>>16))>>>0;};
function material(region,x,y){const cx=Math.floor(x/6),cy=Math.floor(y/6),n=hash(cx,cy,Object.keys(biomes).indexOf(region));const dx=x-cx*6-(1+n%4),dy=y-cy*6-(1+(n>>>4)%4);return n%5===0&&dx*dx+dy*dy<3.4?biomes[region].material:'grass';}
function tile(region,x,y){const kind=material(region,x,y);let edges=0;for(const [i,dx,dy]of [[0,0,-1],[1,1,0],[2,0,1],[3,-1,0]])if(material(region,x+dx,y+dy)!==kind)edges|=1<<i;return {kind,edges,variant:hash(x,y)%4};}
const sites=[],objects=[],collisions=[];
for(const [region,name,asset,ax,ay,story]of plans){
 const p={x:ax,y:ay};
 const site={id:'scenery-'+sites.length,region,name,asset,x:p.x,y:p.y,story};
 sites.push(site);
 const secondary={farm:'seedTray',town:'scale',river:'netCoil',bamboo:'bambooBundle',mountain:'teaCrate',pasture:'haybale'}[region];
 const props=[[asset,0,0],['lamp',sites.length%2?76:-76,-5],['plants',sites.length%2?-74:74,-22],['plants',66,38],['basket',-56,18],['stones',-78,42],[secondary,sites.length%3===0?-52:52,-38]];
 for(const [kind,dx,dy]of props){
  const a=assets[kind],o={id:site.id+'-'+kind+'-'+dx,site:site.id,region,kind,x:p.x+dx,y:p.y+dy,variant:sites.length%4};
  objects.push(o);if(a.box){const [x,y,w,h]=a.box,b=[o.x+x,o.y+y,w,h];collisions.push(b);V.solids.push(b);}
 }
}
const navigation=B.navigationKey;B.navigationKey=s=>navigation(s)+'/scenery-v17';
function points(s){return s.village.interior?[]:sites.map(p=>({id:p.id,name:p.name,kind:assets[p.asset].service,scenery:true,region:p.region,x:p.x,y:p.y+27,top:p.y-assets[p.asset].h,story:p.story}));}
const oldPoints=V.points;V.points=(s,all=false)=>oldPoints(s,all).concat(points(s).filter(p=>all||Math.abs(p.x-s.player.x)<1200&&Math.abs(p.y-s.player.y)<900));root.ZRZWorld.points=V.points;
const oldDestination=V.destination;V.destination=(s,type,id)=>points({...s,village:{...s.village,interior:null}}).find(p=>p.id===id)||oldDestination(s,type,id);
function describe(s,p){const verbs={rest:'坐下歇脚',forage:'翻看山野手记',farmcare:'查看田间照料',weather:'观察风向与天气',tools:'查看工具养护',economy:'查看物产行情',processing:'查看加工与料理',animals:'查看伙伴照料'};return {name:p.name,verb:verbs[p.kind],state:p.kind==='rest'?'歇脚恢复体力 · 时间照常流逝':p.kind==='weather'?C.weather(s.day)+' · '+root.ZRZEnvironment.profile(s.day).label:'乡村生活设施',detail:p.story,reason:'',ready:true};}
root.ZRZTiles={TILE,assets,biomes,sites,objects,collisions,hash,material,tile,points,describe,intersects};
})(typeof window!=='undefined'?window:globalThis);

