const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
require('./source_navigation_runtime.cjs');
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const start=app.indexOf("    if(currentPanel||inputLocked||['INPUT','TEXTAREA','SELECT']"),end=app.indexOf('    if(e.repeat)return;',start);
if(start<0||end<0)throw Error('Original keyboard prefix missing');
const downSource='function down(e){'+app.slice(start,end)+'}',base=ZRZCore.initial().settings.bindings;
const variants=[base,{...base,up:base.bag,bag:base.up},{...base,up:'i',left:'k',down:'l',right:'o'}];
const keys=['w','a','s','d','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Shift','W','!','z','İ','K','ß','中'],rows=[];
for(const bindings of variants)for(const mode of ['play','button','input','textarea','select','panel','action','ctrl','meta','alt'])for(const seed of [[],['d','shift']])for(const key of keys){
 const context={s:{settings:{bindings}},keys:new Set(seed),currentPanel:mode==='panel'?'menu':null,inputLocked:mode==='action',path:[],pending:null,queuedDestination:null,farmQueue:[],ranchQueue:[],kitchenTask:null,buildTask:null,
 document:{activeElement:{tagName:mode==='input'?'INPUT':mode==='textarea'?'TEXTAREA':mode==='select'?'SELECT':'BUTTON',closest(){return mode==='button';}}}};
 vm.createContext(context);vm.runInContext(downSource,context);
 const samples=[];
 for(const operation of ['down','echo','up','down','clear','up','echo']){
  context.path=[{}];context.pending={};context.queuedDestination={};
  let interrupted=false;
  const e={key,repeat:operation==='echo',ctrlKey:mode==='ctrl',metaKey:mode==='meta',altKey:mode==='alt',preventDefault(){}};
  if(operation==='clear')context.keys.clear();
  else if(operation==='up')context.keys.delete(key.toLowerCase());
  else{context.down(e);interrupted=context.path.length===0;}
  const k=context.keys,b=bindings;
  const x=(k.has(b.right)||k.has('arrowright')?1:0)-(k.has(b.left)||k.has('arrowleft')?1:0),y=(k.has(b.down)||k.has('arrowdown')?1:0)-(k.has(b.up)||k.has('arrowup')?1:0);
  samples.push({operation,key,unicode:operation!=='up'&&key.length===1?key.codePointAt(0):0,ctrl:e.ctrlKey,meta:e.metaKey,alt:e.altKey,expected:{keys:[...k],x,y,fast:k.has('shift'),interrupted}});
 }
 rows.push({bindings,mode,seed,samples});
}
const captureStart=app.indexOf('    if(capturing){'),captureEnd=app.indexOf("    if(e.key==='Tab'&&currentPanel)",captureStart);
if(captureStart<0||captureEnd<0)throw Error('Original capture prefix missing');
const captureSource='function capture(e){'+app.slice(captureStart,captureEnd)+'}',captures=[];
for(const key of ['Escape','A','z','w','d','b','c','f','h','q','Shift','İ','K','ß','中'])for(const repeat of [false,true])for(const modifier of ['none','ctrl','meta','alt']){
 const before=structuredClone(base),context={capturing:'right',s:{settings:{bindings:structuredClone(before)}},C:ZRZCore,toast(){},renderPanel(){},save(){},update(){}};
 vm.createContext(context);vm.runInContext(captureSource,context);
 context.capture({key,repeat,ctrlKey:modifier==='ctrl',metaKey:modifier==='meta',altKey:modifier==='alt',preventDefault(){}});
 captures.push({before,key,repeat,modifier,expected:{bindings:context.s.settings.bindings,capturing:context.capturing}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows,captures}));console.log(JSON.stringify({cases:rows.length,events:rows.reduce((n,r)=>n+r.samples.length,0),captures:captures.length}));
