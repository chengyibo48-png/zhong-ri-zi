// Supplemental touch adapter for the agent-browser session; only the specified test page.
const fs = require('node:fs');
const path = require('node:path');
const artifactsRoot = path.resolve(__dirname, '../artifacts');
const downloadDirectory = path.resolve(process.env.ZRZ_BROWSER_QA_DIR || path.join(artifactsRoot,'quality-20261014/browser-downloads'));
const relativeDownload = path.relative(artifactsRoot,downloadDirectory);
if (relativeDownload.startsWith('..') || path.isAbsolute(relativeDownload)) throw new Error('QA downloads must stay inside project artifacts');
fs.mkdirSync(downloadDirectory,{recursive:true});
const [socketURL, origin, action = 'enable', rawX, rawY] = process.argv.slice(2);
if (!/^ws:\/\/127\.0\.0\.1:\d+\/devtools\/browser\//.test(socketURL) || !/^http:\/\/127\.0\.0\.1:417[45]$/.test(origin)) throw new Error('Only local owned QA sessions are allowed');
(async () => {
  const socket = new WebSocket(socketURL);
  await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject});
  let serial=0;const waiting=new Map();let finishDownload,finishChooser;
  const downloaded=new Promise(resolve=>{finishDownload=resolve});
  const chosen=new Promise(resolve=>{finishChooser=resolve});
  socket.onmessage=event=>{const message=JSON.parse(event.data);if(message.id){const entry=waiting.get(message.id);waiting.delete(message.id);message.error?entry.reject(new Error(message.error.message)):entry.resolve(message.result)}else if(message.method==='Browser.downloadProgress' && message.params.state==='completed')finishDownload(message.params);else if(message.method==='Page.fileChooserOpened'){
    const directory=downloadDirectory;
    const filename=fs.readdirSync(directory).find(name=>name.endsWith('.json'));
    if(!filename)throw new Error('QA save download not found');
    send('DOM.setFileInputFiles',{backendNodeId:message.params.backendNodeId,files:[require('node:path').join(directory,filename)]},message.sessionId).then(finishChooser);
  }};
  function send(method,params={},sessionId){return new Promise((resolve,reject)=>{const id=++serial;waiting.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}));})}
  const {targetInfos}=await send('Target.getTargets');
  const target=targetInfos.find(row=>row.type==='page' && row.url.startsWith(origin+'/'));
  if (!target) throw new Error('QA page not found');
  const {sessionId}=await send('Target.attachToTarget',{targetId:target.targetId,flatten:true});
  const cdp=(method,params)=>send(method,params,sessionId);
  if(action==='enable'){
    await cdp('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:5});
    await cdp('Emulation.setEmitTouchEventsForMouse',{enabled:true,configuration:'mobile'});
    await cdp('Page.reload',{ignoreCache:true});
  }else if(action==='start') {
    await cdp('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:110,y:260,id:17,force:1,radiusX:8,radiusY:8}]});
    await new Promise(resolve=>setTimeout(resolve,1000));
    await cdp('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  }
  else if(action==='tap' || action==='export' || action==='import') {
    const x=Number(rawX),y=Number(rawY);
    if(!Number.isFinite(x)||!Number.isFinite(y)||x<0||y<0||x>1000||y>1000)throw new Error('Invalid local touch coordinates');
    if(action==='export')await send('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloadDirectory,eventsEnabled:true});
    if(action==='import'){await cdp('Page.enable');await cdp('Page.setInterceptFileChooserDialog',{enabled:true});}
    await cdp('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:17,force:1,radiusX:8,radiusY:8}]});
    await new Promise(resolve=>setTimeout(resolve,120));
    await cdp('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    if(action==='export')await Promise.race([downloaded,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Save download did not finish')),8000))]);
    if(action==='import'){await Promise.race([chosen,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Save picker did not open')),8000))]);await new Promise(resolve=>setTimeout(resolve,1000));}
  }
  else if(action==='end') await cdp('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  else throw new Error('Unknown action');
  console.log(JSON.stringify({origin,action,target:target.targetId}));socket.close();
})().catch(error=>{console.error(error.message);process.exit(1)});
