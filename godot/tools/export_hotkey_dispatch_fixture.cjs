const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
require('./source_navigation_runtime.cjs');
const app=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const start=app.indexOf("  document.addEventListener('keydown',e=>{"),end=app.indexOf("\n  });",start);
if(start<0||end<0)throw Error('Source key handler missing');
const code='function dispatch(e){'+app.slice(start+"  document.addEventListener('keydown',e=>{".length,end)+'}';
const tools=vm.runInNewContext(app.match(/const tools = (\[[^;]+\]);/)[1]);
const base=ZRZCore.initial().settings.bindings,variants=[base,{...base,up:'b',bag:'w',map:'p',journal:'n'},{...base,interact:'z',up:'i',left:'k',down:'l',right:'o'}];
const keys=['Escape','Tab',' ','[',']','1','2','3','4','5','6','7','8','9','b','w','m','j','p','n','e','z','c','q','f','h','W','C','İ','K','ß','中','F1','F5','F7','F9','Enter','Backspace','ArrowUp'];
const rows=[];
for(const bindings of variants)for(const mode of ['play','button','input','textarea','select','panel','action','panel_action','ctrl','meta','alt'])for(const repeat of [false,true])for(const key of keys){
 const commands=[],tag=mode==='input'?'INPUT':mode==='textarea'?'TEXTAREA':mode==='select'?'SELECT':'BUTTON';
 const context={s:{settings:{bindings}},C:{calendar(){return {season:0}}},tools,capturing:null,calSeason:0,
 document:{activeElement:{tagName:tag,closest(){return mode==='button'}}},$(){return {querySelectorAll(){return []}}},
 currentPanel:mode==='panel'||mode==='panel_action'?'menu':null,inputLocked:mode==='action'||mode==='panel_action',
 sequence:{active:mode==='action'||mode==='panel_action'},keys:new Set(),path:[],pending:null,queuedDestination:null,farmQueue:[],ranchQueue:[],kitchenTask:null,buildTask:null,
 cancelAction(){commands.push('cancel')},closePanel(){commands.push('close')},openPanel(name){commands.push(({bag:'bag',map:'map',journal:'journal',menu:'menu',calendar:'calendar',seeds:'seeds'})[name]||name)},
 cycleTarget(n){commands.push(n<0?'previous_target':'next_target')},setTool(id){commands.push('tool:'+String(tools.findIndex(t=>t.id===id)+1))},
 nearest(){return {}},interact(){commands.push('interact')},fullscreen(){commands.push('fullscreen')},toggleHud(){commands.push('hud')},toast(){}};
 vm.createContext(context);vm.runInContext(code,context);
 context.dispatch({key,repeat,ctrlKey:mode==='ctrl',metaKey:mode==='meta',altKey:mode==='alt',shiftKey:false,preventDefault(){}});
 rows.push({bindings,mode,repeat,key,expected:commands});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows,tools,menu:require("./export_menu_expansion.cjs")()}));console.log(JSON.stringify({cases:rows.length}));
