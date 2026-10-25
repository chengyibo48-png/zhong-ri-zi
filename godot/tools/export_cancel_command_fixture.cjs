const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const match=app.match(/  function cancelAction\(\)\{[^\n]*\}/);
if(!match)throw Error('cancelAction missing');
const rows=[];
for(const active of [false,true]){
 const calls=[],context={s:{day:7},sequence:{cancel(){calls.push('cancel');return active}},
 path:[{x:1,y:2}],pending:{id:'old'},queuedDestination:{id:'door'},farmQueue:[{}],ranchQueue:[{}],kitchenTask:{id:'cook'},buildTask:{id:'build'},keys:{clear(){calls.push('keys')}},
 Feedback:{note(s,note){calls.push({note})}},save(){calls.push('save')},toast(text){calls.push({toast:text})}};
 vm.createContext(context);vm.runInContext(match[0],context);context.cancelAction();
 rows.push({active,expected:{path:context.path,pending:context.pending,queuedDestination:context.queuedDestination,farmQueue:context.farmQueue,ranchQueue:context.ranchQueue,kitchenTask:context.kitchenTask,buildTask:context.buildTask,calls}});
}
const interaction=app.slice(app.indexOf('  function interact(p,performed=false){'),app.indexOf('  function nearest(){'));
if(!interaction.startsWith('  function interact'))throw Error('interact missing');
const direct={currentPanel:null,inputLocked:false,tool:'hand',window:{},Actions:{point(){return {kind:'bell'}}},path:[{}],pending:{id:'old'},farmQueue:[{}],ranchQueue:[{}],kitchenTask:{id:'cook'},buildTask:{id:'build'},started:false,startAction(){direct.started=true}};
vm.createContext(direct);vm.runInContext(interaction,direct);direct.interact({kind:'ambient',x:1,y:2});
const directExpected={started:direct.started,pathKept:direct.path.length===1,pendingKept:direct.pending!==null,farmKept:direct.farmQueue.length===1,ranchKept:direct.ranchQueue.length===1,kitchenKept:direct.kitchenTask!==null,buildKept:direct.buildTask!==null};
fs.writeFileSync(process.argv[2],JSON.stringify({rows,directExpected},null,2));console.log('2 original cancelAction branches and original direct interact exported');
