const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>Object.fromEntries(['day','minutes','stamina','money','kitchen','skills','stats','journal','eventLog','discovered','flags','bag','quality','knownRecipes','ranch','animals','pet','processing','toolkit','storage','storageQuality','upgrades'].map(k=>[k,s[k]]));
const variants=['normal','premium','mixed','excess','locked','missing','empty','low','gentle','labor','buff','late','qty0','qtyNegative','qtyFloat','qty21','qty20','qty2','qtyString','qtyBool','qtyNull','aged','overnight'];
function qty(v){return ({qty0:0,qtyNegative:-1,qtyFloat:1.5,qty21:21,qty20:20,qty2:2,qtyString:'2',qtyBool:true,qtyNull:null})[v]??(v==='qtyNull'?null:1);}
function base(){const s=C.initial();s.day=27;s.minutes=600.25;s.money=10000;return s;}
function extras(s,variant,items){
 if(variant==='low')s.stamina=0;
 if(variant==='gentle'){s.stamina=1;s.skills.farming.choice='gentle';}
 if(variant==='labor'){s.stamina=1;s.buffs.laborDay=s.day;}
 if(variant==='buff'){s.stamina=1;s.kitchen.buff={kind:'暖胃',until:s.day*1440+s.minutes+180};}
 if(variant==='late')s.minutes=1319.875;
 if(variant==='locked')s.economy.locked=items.slice(0,1);
 if(variant==='empty')for(const id of items)delete s.bag[id];
 if(variant==='missing'&&items.length)s.bag[items[0]]=0;
 K.ensure(s);
 if(variant==='aged')for(const id of items)if(s.kitchen.lots.bag[id])s.kitchen.lots.bag[id]=[{qty:s.bag[id],age:2}];
}
for(const id of [...Object.keys(R.recipes),'missing'])for(const variant of variants)for(const deviceOpen of (['cream','yogurt'].includes(id)?[false,true]:[false])){
 let s=base();const rec=R.recipes[id],n=qty(variant),scale=Number.isInteger(n)&&n>0&&n<=20?n:1,needs=rec?.needs||{},items=Object.keys(needs);
 for(const [item,q]of Object.entries(needs)){s.bag[item]=q*scale+(variant==='excess'?1:0);if(variant==='premium'||variant==='excess')s.quality[item]=[q*scale,0,0];if(variant==='mixed')s.quality[item]=[0,Math.max(0,q*scale-1),0];}
 extras(s,variant,items);
 if(deviceOpen)s.upgrades.kitchen=true;
 const input=copy(s);try{s=C.load(copy(s));}catch(error){rows.push({op:'craft',id,variant,deviceOpen,quantity:n,before:input,invalidLoad:true,sourceError:error.message});continue;}
 const before=copy(s),result=R.craft(s,id,n),expected=copy(snapshot(s)),steps=[];
 if(variant==='overnight'){for(let i=0;i<2;i++){const result=C.nextDay(s);steps.push({result,expected:copy(snapshot(s))});}}
 rows.push({op:'craft',id,variant,deviceOpen,quantity:n,before,result,expected,steps});
}
for(const id of ['feed','hay','grainFeed','healthFeed','bedding','missing'])for(const withdraw of [false,true])for(const variant of ['normal','premium','mixed','locked','empty','full','overflow','qty0','qtyNegative','qtyFloat','qty101','qty100','qtyString','qtyBool','qtyNull','low','aged','bulk']){
 let s=base();const n=variant==='qty101'?101:variant==='qty100'?100:variant==='bulk'?5:qty(variant),count=100;
 if(id!=='missing')s.bag[id]=count;s.ranch.stores[id]=variant==='empty'?0:variant==='full'?9999:variant==='overflow'?9998:count;
 if(id==='missing')delete s.ranch.stores[id];
 if(variant==='premium')s.quality[id]=[count,0,0];if(variant==='mixed')s.quality[id]=[0,98,0];
 extras(s,variant,[id]);if(variant==='empty')delete s.bag[id];
 const input=copy(s);try{s=C.load(copy(s));}catch(error){rows.push({op:'store',id,variant,quantity:n,withdraw,before:input,invalidLoad:true,sourceError:error.message});continue;}
 const before=copy(s),result=R.storeFeed(s,id,n,withdraw),expected=copy(snapshot(s));
 rows.push({op:'store',id,variant,quantity:n,withdraw,before,result,expected,steps:[]});
}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(r)).join('\n')+'\n');
console.log('Ranch craft/store cases: '+rows.length);
