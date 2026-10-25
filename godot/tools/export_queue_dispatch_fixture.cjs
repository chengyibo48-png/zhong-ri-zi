const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const exact=require('./export_world_precision.cjs'),app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const start=app.indexOf('  function move(dt)'),end=app.indexOf("if(['npc','animal'].includes(pending?.kind)",start);
if(start<0||end<0)throw Error('Original queue prefix missing');
const prefix=app.slice(start,end)+'}';
const rows=[];
for(let mask=0;mask<16;mask++)for(const blocked of ['idle','route','pending','exit','panel','hidden','action'])for(const at of [0,.849999999,.85,.850000001,1.099999999,1.1,1.100000001,5])for(const fail of [false,true]){
 const log=[];
 const context={buildTask:mask&1?{id:'probe'}:null,kitchenTask:mask&2?{id:'probe'}:null,ranchQueue:mask&4?[{}]:[],farmQueue:mask&8?[{}]:[],ranchNextAt:1.1,farmNextAt:.85,frameTime:at,path:blocked==='route'?[{x:1,y:1}]:[],pending:blocked==='pending'?{}:null,queuedDestination:blocked==='exit'?{}:null};
 for(const [name,kind] of [['advanceBuild','build'],['advanceKitchen','kitchen'],['advanceRanch','ranch'],['advanceFarm','farm']])context[name]=()=>{log.push(kind);if(!fail)context.pending={kind};};
 vm.createContext(context);vm.runInContext(prefix,context);
 if(!['panel','hidden','action'].includes(blocked))context.move(.05);
 rows.push({mask,blocked,at,fail,expected:log});
}
const a=app.indexOf("    if(p.kind==='ranch-task')"),b=app.indexOf("    if(p.kind==='npc')",a);
if(a<0||b<0)throw Error('Original completion markers missing');
const commitSource='function commit(p){'+app.slice(a,b)+'}',commits=[];
for(const kind of ['farm','ranch'])for(const at of [-1,.0000001,.85,1.1,123456.987654321,1e15])for(const ok of [false,true]){
 const result={ok,msg:'probe'},context={s:{plots:[{crop:'cabbage'}],animals:[],player:{x:0,y:0}},frameTime:at,farmNextAt:0,ranchNextAt:0,farmCompleted:2,ranchCompleted:2,farmQueue:[{}],ranchQueue:[{}],kitchenTask:null,buildTask:null,R:{perform(){return result;}},F:{perform(){return result;}},V:{feedback(){}},save(){},update(){},sound(){},toast(){}};
 vm.createContext(context);vm.runInContext(commitSource,context);context.commit({kind:kind+'-task',index:0,action:'water',pet:true});
 commits.push({kind,at,ok,nextAt:kind==='farm'?context.farmNextAt:context.ranchNextAt,completed:kind==='farm'?context.farmCompleted:context.ranchCompleted,remaining:kind==='farm'?context.farmQueue.length:context.ranchQueue.length});
}
fs.writeFileSync(process.argv[2],JSON.stringify(exact({rows,commits})));console.log('Exported '+rows.length+' original dispatch and '+commits.length+' completion cases');
