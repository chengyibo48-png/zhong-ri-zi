const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const poll=app.slice(app.indexOf('  function pollGamepad(now){'),app.indexOf('  function move(dt)',app.indexOf('  function pollGamepad(now){')));
const listeners=app.match(/  document\.addEventListener\('keydown',\(\)=>inputMode='keyboard'\);\$\('world'\)\.addEventListener\('pointerdown',[^\n]+/)[0];
const prompt=app.match(/inputMode==='pad'\?'A':inputMode==='touch'\?'点按':keyLabel\('interact'\)/)[0];
const cancel=app.match(/inputMode==='pad'\?'B':inputMode==='touch'\?'点按':'Esc'/)[0];
const cycle=app.match(/inputMode==='pad'\?'L3':inputMode==='touch'\?'点按':'\[ \/ \]'/)[0];
const rows=[];
for(const initial of ['keyboard','pad','touch'])for(const mode of ['play','panel','action','disabled','hidden','disconnected'])for(const binding of ['e','z']){
 const hooks={},world={addEventListener(name,fn){hooks.pointerdown=fn},querySelectorAll(){return []}};
 const ctx={inputMode:initial,s:{settings:{gamepad:mode!=='disabled'}},inputLocked:mode==='action',currentPanel:mode==='panel'?'menu':null,
 padX:0,padY:0,padPrevious:[],padMenuAt:0,document:{hidden:mode==='hidden',activeElement:null,addEventListener(name,fn){hooks.keydown=fn}},
 navigator:{getGamepads(){return mode==='disconnected'?[]:[{connected:true,buttons:ctx.sample.buttons.map(pressed=>({pressed})),axes:ctx.sample.axes}]}},
 $(){return world},keyLabel(){return binding.toUpperCase()},path:[],pending:null,queuedDestination:null,farmQueue:[],ranchQueue:[],kitchenTask:null,buildTask:null,
 cancelAction(){},closePanel(){},nearest(){return null},cycleTarget(){},openPanel(){},tool:'0',tools:Array.from({length:8},(_,i)=>({id:String(i)})),setTool(){},Event:class{}};
 vm.createContext(ctx);vm.runInContext(poll+'\n'+listeners,ctx);
 const samples=[];
 const steps=[{kind:'pad',indices:[13]},{kind:'pad',indices:[]},{kind:'pad',indices:[4]},{kind:'pad',indices:[]},{kind:'pad',axes:[.2,0]},
 {kind:'pad',axes:[.200000001,0]},{kind:'key',pressed:false},{kind:'key',pressed:true},{kind:'pointer',pointerType:'touch'},
 {kind:'pad',indices:[]},{kind:'pad',indices:[0]},{kind:'pad',indices:[0]},{kind:'pointer',pointerType:'mouse'},
 {kind:'pad',indices:[]},{kind:'pad',indices:[1]},{kind:'pad',indices:[]},{kind:'pad',indices:[10]},{kind:'pointer',pointerType:'pen'},
 {kind:'pad',indices:[]},{kind:'pad',indices:[9]}];
 for(const [i,step]of steps.entries()){
  const buttons=Array(17).fill(false);for(const index of step.indices||[])buttons[index]=true;
  const sample={connected:mode!=='disconnected',buttons,axes:step.axes||[0,0]};
  if(step.kind==='pad'){ctx.sample=sample;ctx.pollGamepad(200+i*201);}
  else if(step.kind==='key'){if(step.pressed)hooks.keydown({});}
  else hooks.pointerdown({pointerType:step.pointerType});
  samples.push({step,sample,now:200+i*201,expected:{mode:ctx.inputMode,prompt:vm.runInContext(prompt,ctx),cancel:vm.runInContext(cancel,ctx),cycle:vm.runInContext(cycle,ctx)}});
 }
 rows.push({initial,mode,binding,samples});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));console.log(JSON.stringify({cases:rows.length,steps:rows.reduce((n,r)=>n+r.samples.length,0)}));
