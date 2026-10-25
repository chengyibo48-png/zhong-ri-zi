const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,E=ZRZEconomy,D=ZRZData,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
for(const id of Object.keys(D.items)){
 const s=C.initial();s.upgrades.storage=true;if(s.bag[id])C.consume(s,{[id]:s.bag[id]});
 const other=id==='wood'?'bamboo':'wood',before=copy(s),steps=[];
 const ops=[{op:'add',id,n:2},{op:'add',id:other,n:2},{op:'consume',id,n:2},{op:'add',id:'rice',n:1},{op:'add',id,n:3},{op:'add-quality',id,n:2,grade:2},{op:'store',id,n:3},{op:'add',id:other,n:1},{op:'take',id,n:3},{op:'reload'},{op:'consume',id,n:s.bag[id]||3},{op:'add',id,n:1}];
 for(const op of ops){
  if(op.op==='add')C.add(s,op.id,op.n);
  else if(op.op==='add-quality'){C.add(s,op.id,op.n);s.quality[op.id]??=[0,0,0];s.quality[op.id][op.grade-1]+=op.n;}
  else if(op.op==='consume'){op.n=s.bag[op.id];C.consume(s,{[op.id]:op.n});}
  else if(op.op==='store'||op.op==='take')E.transfer(s,op.id,op.n,op.op==='store');
  else {const loaded=C.load(JSON.stringify(s));Object.keys(s).forEach(k=>delete s[k]);Object.assign(s,loaded);}
  K.ensure(s);steps.push({task:copy(op),expected:{bag:copy(s.bag),storage:copy(s.storage),quality:copy(s.quality),storageQuality:copy(s.storageQuality),lots:copy(s.kitchen.lots),order:Object.keys(s.bag).filter(id=>s.bag[id]>0)}});
 }
 rows.push({id,before,steps});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Inventory lifecycle sequences: '+rows.length+', steps: '+rows.reduce((n,r)=>n+r.steps.length,0));
