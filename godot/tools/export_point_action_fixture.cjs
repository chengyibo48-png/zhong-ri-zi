const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,V=ZRZVillage,A=ZRZActions;
const copy=x=>JSON.parse(JSON.stringify(x));
const rows=[];
function fresh(){const s=C.initial();s.stamina=50;s.minutes=600;return s;}
function add(kind,variant,point){
 const s=fresh();
 if(variant==='full')s.stamina=100;
 if(variant==='tired')s.stamina=0;
 if(kind==='pet'&&variant==='repeated')C.pet(s);
 if(kind==='gather'&&variant==='full-gather')s.forage.mode='full';
 if(kind==='gather'&&variant.startsWith('axe-')){s.toolkit.tools.axe.level=2;s.toolkit.tools.axe.branch=variant==='axe-care'?'care':'broad';}
 if(kind==='gather'&&variant==='collected')s.collected[point.id]=s.day;
 const before=copy(s);
 let result;
 if(kind==='rest')result=C.rest(s);
 if(kind==='pet')result=C.pet(s);
 if(kind==='gather')result=C.gather(s,point.id,point.item);
 rows.push({kind,variant,point,spec:A.point(point),before,result,expected:{stamina:s.stamina,minutes:s.minutes,money:s.money,bag:s.bag,quality:s.quality,pet:s.pet,ranchPet:s.ranch.pet,forage:s.forage}});
}
for(const kind of ['rest','pet'])for(const variant of ['normal','full','tired','repeated'])add(kind,variant,{kind,id:kind,x:2831,y:1652});
const points=V.points(fresh(),true).filter(p=>p.kind==='gather');
const items=new Set();
for(const point of points){if(items.has(point.item))continue;items.add(point.item);for(const v of ['normal','tired','full-gather'])add('gather',v,point);if(['wood','bamboo'].includes(point.item))for(const v of ['axe-broad','axe-care'])add('gather',v,point);if(point.item==='wood')add('gather','collected',point);}
const app=fs.readFileSync(require('node:path').join(__dirname,'../../src/app.js'),'utf8');
const expression=app.match(/const darkness=(.*?);fade.hidden/)[1];
const darkness=Function('Feedback','s','a','sceneFade','return '+expression);
const fades=[];
for(const motion of ['full','reduced'])for(const kind of ['door','sleep','read'])for(const progress of [0,.25,.6,.7,.9,1])for(const remaining of [0,.05,.15,.3]){
 const a={kind,door:kind==='door',progress};
 fades.push({motion,a,remaining,expected:darkness({ensure:s=>s},{prefs:{motion}},a,remaining)});
}
fades.push({motion:'full',a:null,remaining:.15,expected:darkness({ensure:s=>s},{prefs:{motion:'full'}},null,.15)});
fs.writeFileSync(process.argv[2],JSON.stringify({rows,fades},null,2));
console.log('Exported '+rows.length+' original world transactions and '+fades.length+' exact app fade samples');
