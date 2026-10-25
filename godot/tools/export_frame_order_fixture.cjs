const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
require('./source_navigation_runtime.cjs');
const exact=require('./export_world_precision.cjs'),app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const start=app.indexOf('  function frame(now)'),end=app.indexOf('    camera.update(s,dt);',start);
if(start<0||end<0)throw Error('Original frame markers missing');
const frameSource=app.slice(start,end)+'\n  }';
const fd=fs.openSync(process.argv[2],'w');let cases=0,frames=0;
for(const speed of ['normal','relaxed'])for(const arrival of ['none','action','ui','action-ui'])for(const initial of ['none','action','ui'])for(const pattern of [[.016,.05,.033,0,.125],[.05],[.01]]){
 const s={minutes:1319.99,settings:{speed}},sequence=new ZRZActions.Sequence(),record={moves:0,worldClock:0,commits:0,sounds:0,notices:0};
 const context={s,sequence,currentPanel:initial==='ui'?'menu':null,inputLocked:false,document:{hidden:false},lastTime:1000,frameTime:1,tick:0,walking:false,sceneFade:.3,diagnostics:{frames:0,sceneChanges:0},frameIndex:0,arrival,
 pollGamepad(){},V:{update(s,dt){record.worldClock+=dt;return false;}},
 update(){},ambient(){},sound(){record.sounds++;},openPanel(){if(context.inputLocked)return;context.currentPanel='sleep';record.notices++;},
 window:{ZRZFishing:{tick(){}}},
 move(){record.moves++;if(context.frameIndex===2){if(arrival.includes('action'))begin();if(arrival.includes('ui'))context.currentPanel='menu';}return true;}
 };
 function begin(){context.inputLocked=true;sequence.start({kind:'read',label:'probe',duration:.12},()=>{context.inputLocked=false;record.commits++;});}
 if(initial==='action')begin();
 vm.createContext(context);vm.runInContext(frameSource,context);
 const samples=[];let now=1000;
 for(let i=0;i<140;i++){
  context.frameIndex=i;
  const panel=i===5||i===25?'close':i===20?'open':'keep';
  if(panel==='close')context.currentPanel=null;if(panel==='open')context.currentPanel='menu';
  const delta=pattern[i%pattern.length],previous=now;now+=delta*1000;context.frame(now);
  samples.push({delta:(now-previous)/1000,panel,expected:{minutes:s.minutes,tick:context.tick,elapsed:sequence.active?.elapsed??null,worldClock:record.worldClock,moves:record.moves,commits:record.commits,sounds:record.sounds,notices:record.notices,ui:!!context.currentPanel,fade:context.sceneFade}});
  frames++;
 }
 fs.writeSync(fd,JSON.stringify(exact({speed,arrival,initial,samples}))+'\n');cases++;
}
fs.closeSync(fd);console.log(JSON.stringify({cases,frames}));
