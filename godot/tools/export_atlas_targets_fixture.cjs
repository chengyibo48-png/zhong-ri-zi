const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,V=ZRZVillage,S=ZRZScenes,F=ZRZFarming,R=ZRZRanch,G=ZRZForage,D=ZRZData,copy=x=>structuredClone(x),exact=require('./export_world_precision.cjs'),fd=fs.openSync(process.argv[2],'w');
const types=Object.keys(R.species),cropIds=Object.keys(D.crops),seed=C.initial(),raw=V.points(seed,true).filter(p=>p.kind==='gather');let count=0;const categories={},variants={};
for(let day=0;day<112;day++)for(let variant=0;variant<4;variant++){
 const s=copy(seed);s.day=day;s.minutes=[390,600,930,1200][variant];s.village.interior=variant===3?(day%2?'home-granny':R.barns.poultry.house):null;
 s.neighbors.day=day;s.neighbors.people.granny.event=day%3===0?{day,status:'accepted',completed:null,method:null}:null;
 ZRZMuseum.ensure(s).level=2;
 s.plots=Array.from({length:72},(_,i)=>{const id=cropIds[(i+day)%cropIds.length],days=D.crops[id].days;return {tilled:true,crop:(i+variant)%9===0?null:id,growth:days+[-.25,0,.25][(i+variant)%3],watered:false,soil:2,pest:false,lastGroup:'',repeats:0};});
 delete s.farm;const farm=F.ensure(s);farm.beds.forEach((b,i)=>{b.moisture=[0,39.49,39.5,39.99,40,100][(i+variant)%6];b.removed=i%13===0;b.fallow=i%11===0;b.kind=['normal','heirloom','seasonal'][i%3];});
 const forage=G.ensure(s);forage.mode=variant%2?'full':'gentle';forage.xp=variant?20:0;forage.discovered=raw.filter((p,i)=>variant!==0||i%3===0).map(p=>p.id);
 forage.patches=Object.fromEntries(raw.filter((p,i)=>(i+variant)%4===0).map((p,i)=>[p.id,{lastDay:day,readyDay:day+(i%2?3:0),pressure:8}]));
 s.collected=Object.fromEntries(raw.filter((p,i)=>(i+variant)%7===0).map(p=>[p.id,day]));
 s.toolkit.tools.axe.level=variant===2?2:0;s.toolkit.tools.axe.branch='broad';
 for(const barn of Object.values(s.ranch.barns)){barn.built=true;barn.space=2;}
 s.animals=types.map((type,i)=>{const a=copy(seed.animals[i%seed.animals.length]),spec=R.species[type],home=V.houses.find(h=>h.id===R.barns[spec.home].house),room=(i+variant)%3===0?home.id:null;
 Object.assign(a,{id:'atlas-'+type,name:['绒绒','小水','阿黄','团团','阿栗'][i],type,species:spec.name,product:spec.product,age:[0,Math.ceil(spec.adult*.45)-1,Math.ceil(spec.adult*.45),spec.adult,spec.elder][(i+day)%5],retired:(day+i)%7===0,ready:(i+variant)%5===0?1:0,feathers:(i+variant)%5===1?1:0,hunger:(i+variant)%5===2?39:40,illness:(i+variant)%5===3?20:0});
 a.qualityStock=[a.ready,0,0,0];a.position={x:3070+i*31.25,y:3082+i*24.5,direction:'right',room,inside:{x:420+i*20,y:490},walking:variant===1};return a;});
 s.atlas.pins=[{id:'pin-1',x:2831,y:1652,label:'常走的小路'},{id:'pin-2',x:2010,y:3715,label:'南坡晚风'}];s.atlas.nextId=3;
 const targets=S.targets(s);
 const probes=[{id:'harvest-0',x:1,y:1},{id:'gone',x:2831,y:1652},{x:2831.125,y:1652.75},{id:'water-1'},{id:'resource-'+raw[0].id},{id:'animal-atlas-hen'},{id:'region-river'},{id:'scenery-0'},{id:'pin-2'},null];
 const resolves=probes.map(input=>({input,expected:S.resolve(s,input)}));
 const clicks=[...S.layers.map(layer=>({x:2831.25,y:1652.5,layer})),{x:targets[0].x,y:targets[0].y,layer:'all'},{x:0,y:0,layer:'all'},{x:2010,y:3715,layer:'pins'}].map(p=>({...p,expected:S.clickPoint(s,p.x,p.y,p.layer)}));
 const row={day,variant,before:copy(s),targets:copy(targets),resolves:copy(resolves),clicks:copy(clicks)};
 fs.writeSync(fd,JSON.stringify(exact(row))+'\n');count++;variants[variant]=(variants[variant]||0)+1;
 for(const t of targets)categories[t.type]=(categories[t.type]||0)+1;
}
fs.closeSync(fd);fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify({cases:count,categories,variants}));console.log(JSON.stringify({cases:count,categories,variants}));
