const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,rows=[];
const variants=['steady','young','retired','lost','ill20','ill19','hungry39','hungry40','clean44','barn44','crowded','broken24','health44','product','feathers','feed89','feed90','fed-today','pet-today','missing-feed','care1','care2','efficient','buffs','all'];
for(const type of Object.keys(R.species))for(const breed of Object.keys(R.breeds))for(const feed of ['feed','hay','grainFeed','healthFeed'])for(const variant of variants){
 const s=C.initial();s.day=27;s.minutes=450;s.money=100000;s.animals=[];
 for(const b of Object.values(s.ranch.barns)){b.built=true;b.space=1;}
 R.buyAnimal(s,type,'female',breed,false);
 const a=s.animals[0],b=s.ranch.barns[R.species[type].home];
 Object.assign(a,{age:R.species[type].adult,retired:false,lost:false,illness:0,health:90,hunger:95.5,clean:90,ready:0,qualityStock:[0,0,0,0],feathers:0});a.care.feed=-1;a.care.pet=-1;
 s.ranch.feed=feed;s.bag[feed]=variant==='missing-feed'?0:20;s.stamina=['steady','care1','efficient'].includes(variant)?1:variant==='buffs'?0:10;
 if(variant==='young')a.age=R.species[type].adult-1;
 if(variant==='retired')a.retired=true;
 if(variant==='lost'||variant==='all')a.lost=true;
 if(variant==='ill20'||variant==='all')a.illness=20.5;
 if(variant==='ill19')a.illness=19.99;
 if(variant==='hungry39'||variant==='all')a.hunger=39.5;
 if(variant==='hungry40')a.hunger=40;
 if(variant==='clean44'||variant==='all')a.clean=44.99;
 if(variant==='barn44')b.clean=44.99;
 if(variant==='broken24'||variant==='all')b.durability=24.99;
 if(variant==='health44'||variant==='all')a.health=44.99;
 if(['product','care1','care2','efficient','buffs','all'].includes(variant)){a.ready=2;a.qualityStock=[2,0,0,0];}
 if(variant==='feathers')a.feathers=3;
 if(['feed89','fed-today','missing-feed'].includes(variant))a.hunger=89.5;
 if(variant==='feed90')a.hunger=90;
 if(variant==='fed-today')a.care.feed=s.day;
 if(variant==='pet-today')a.care.pet=s.day;
 if(variant==='care1')s.toolkit.tools.care.level=1;
 if(variant==='care2'){s.toolkit.tools.care.level=2;s.toolkit.tools.care.branch='broad';}
 if(variant==='efficient')b.efficiency=1;
 if(variant==='buffs'){s.skills.farming.choice='gentle';s.buffs.laborDay=s.day;s.kitchen.buff={kind:'暖胃',until:dayTime(s)+50};}
 if(variant==='crowded'||variant==='all')for(let i=1;i<=R.capacity(s,R.species[type].home);i++)s.animals.push({...a,id:'extra-'+i});
 const p={kind:'animal',id:a.id,name:'伙伴'};
 const expected=ZRZFeedback.describe(s,p),status=R.status(s,a);
 rows.push({type,breed,feed,variant,p,stamina:s.stamina,day:s.day,animals:s.animals,ranch:s.ranch,bag:s.bag,toolkit:s.toolkit,skills:s.skills,buffs:s.buffs,toolUpgrades:s.toolUpgrades,kitchen:s.kitchen,expected,status});
}
function dayTime(s){return s.day*1440+s.minutes;}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));console.log('Exported '+rows.length+' original animal descriptions and status lists');
