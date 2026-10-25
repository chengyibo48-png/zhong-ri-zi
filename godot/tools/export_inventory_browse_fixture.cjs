const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const vm=require('node:vm'),C=ZRZCore,D=ZRZData,E=ZRZEconomy,K=ZRZKitchen,states=[],rows=[],values=[];
const source=fs.readFileSync(require('node:path').join(__dirname,'../../src/economy-ui.js'),'utf8');
const fn=source.slice(source.indexOf('function itemIds('),source.indexOf('\nfunction pager('));
for(const day of [0,5,112]){
 const s=C.initial();s.day=day;s.bag={};s.storage={};s.quality={};s.storageQuality={};
 Object.keys(D.items).reverse().forEach((id,i)=>{s.bag[id]=i%11+1;s.storage[id]=i%7+1;if(i%3===0)s.quality[id]=[s.bag[id],0,0];if(i%4===0)s.storageQuality[id]=[0,s.storage[id],0];});
 K.ensure(s);for(const side of ['bag','storage'])for(const id of Object.keys(s[side]))if(K.food(id))s.kitchen.lots[side][id]=[{qty:s[side][id],age:(Object.keys(D.items).indexOf(id)%4)*K.shelf(id)/3}];
 const index=states.length;states.push(JSON.parse(JSON.stringify(s))); values.push(Object.fromEntries(Object.keys(D.items).map(id=>[id,{price:C.price(s,id),bag:K.food(id)?K.fresh(s,id,"bag").ratio:2,storage:K.food(id)?K.fresh(s,id,"storage").ratio:2}])));
 for(const side of ['bag','storage'])for(const filter of E.categories)for(const sort of ['name','count','value','fresh'])for(const search of ['','米','材料','种子','missing']){
  const ui={side,filter,sort,search};const context={E,C,D,K,ui};vm.createContext(context);vm.runInContext(fn+';result=itemIds(s);',Object.assign(context,{s}));
  rows.push({state:index,side,category:filter,sort,search,ids:context.result});
 }
}
fs.writeFileSync(process.argv[2],JSON.stringify({states,rows,values,metadata:Object.fromEntries(Object.keys(D.items).map(id=>[id,E.details(id)]))}));console.log('Inventory browse source rows: '+rows.length);
