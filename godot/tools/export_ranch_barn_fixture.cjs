const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>Object.fromEntries(['day','minutes','stamina','money','kitchen','skills','stats','journal','eventLog','discovered','flags','bag','quality','knownRecipes','ranch','animals','pet','processing','toolkit','storage','storageQuality','upgrades'].map(k=>[k,s[k]]));

const variants=['normal','missing','locked','money','low','gentle','labor','buff','late','unbuilt','level1','level2','max','enabled','installed','clean95','clean94','lastclean','waste0','waste10','durability100','premium','mixed','empty-animals'];
function fresh(id,act){const s=C.initial();s.day=27;s.minutes=600.25;s.money=100000;for(const b of Object.values(s.ranch.barns)){b.built=true;b.clean=40.25;b.waste=7;b.durability=60.25;}const b=s.ranch.barns[id];if(act==='build')b.built=false;for(const a of s.animals){a.clean=50.25;a.mood=61.75;}s.bag.wood=40;s.bag.bamboo=20;s.bag.bedding=3;return s;}
for(const id of Object.keys(R.barns))for(const action of ['build','space','comfort','protection','efficiency','autoFeed','autoClean','autoCollect','clean','bedding','repair','missing'])for(const variant of variants){
 let s=fresh(id,action);const b=s.ranch.barns[id];
 if(variant==='missing'){s.bag.wood=0;s.bag.bamboo=0;s.bag.bedding=0;}if(variant==='locked')s.economy.locked=['wood','bamboo','bedding'];
 if(variant==='money')s.money=0;if(variant==='low')s.stamina=0;
 if(variant==='gentle'){s.stamina=2;s.skills.farming.choice='gentle';}if(variant==='labor'){s.stamina=2;s.buffs.laborDay=s.day;}
 if(variant==='buff'){s.stamina=2;s.kitchen.buff={kind:'暖胃',until:s.day*1440+s.minutes+180};}if(variant==='late')s.minutes=1319.875;
 if(variant==='unbuilt')b.built=false;
 if(variant==='level1'||variant==='level2'||variant==='max')for(const key of ['space','comfort','protection','efficiency'])b[key]=variant==='max'?3:variant==='level2'?2:1;
 if(variant==='enabled')for(const key of ['autoFeed','autoClean','autoCollect'])b[key]=true;
 if(variant==='installed')for(const key of ['autoFeed','autoClean','autoCollect'])b[key+'Built']=true;
 if(variant==='clean95'){b.clean=95;b.waste=0;}if(variant==='clean94'){b.clean=94.75;b.waste=0;}
 if(variant==='lastclean')b.lastClean=s.day;if(variant==='waste0')b.waste=0;if(variant==='waste10')b.waste=10;
 if(variant==='durability100')b.durability=100;if(variant==='empty-animals')s.animals=[];
 if(variant==='premium')for(const k of ['wood','bamboo','bedding'])s.quality[k]=[s.bag[k],0,0];
 if(variant==='mixed')for(const k of ['wood','bamboo','bedding'])s.quality[k]=[0,s.bag[k]-1,0];
 K.ensure(s);s=C.load(copy(s));const before=copy(s),result=R.barnAction(s,id,action),expected=copy(snapshot(s)),steps=[];
 if(variant==='normal'&&result.ok)for(let i=0;i<2;i++){const result=C.nextDay(s);steps.push({result,expected:copy(snapshot(s))});}
 rows.push({op:'barn',id,action,variant,before,result,expected,steps});
}
for(const id of ['missing','']){let s=C.initial();K.ensure(s);s=C.load(copy(s));const before=copy(s),result=R.barnAction(s,id,'build');rows.push({op:'barn',id,action:'build',variant:'invalid',before,result,expected:copy(snapshot(s)),steps:[]});}
function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(exact(r))).join('\n')+'\n');console.log('Ranch barn cases: '+rows.length);
