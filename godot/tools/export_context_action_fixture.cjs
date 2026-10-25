const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const source=fs.readFileSync(require('node:path').join(__dirname,'../../src/app.js'),'utf8');
const body=source.slice(source.indexOf('function updateContext(near)'),source.indexOf('const journey=document.createElement',source.indexOf('function updateContext(near)')));
if(!body.includes("walk-progress"))throw Error('Source context function missing');
const fn=new Function('near','s','currentPanel','inputLocked','path','selection','inputMode','tool','pending','queuedDestination','Feedback','V','button','escape','$','walk',"let contextKey='',contextual={};"+body+";updateContext(near);return {hidden:contextual.hidden,html:contextual.innerHTML,progress:walk.textContent||''};");
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const button=(label,action,id='',cls='',extra='')=>'<button data-action="'+action+'" data-id="'+id+'" '+extra+'>'+escape(label)+'</button>';
const targets=[null,{kind:'plot',index:7},{kind:'animal',id:ZRZCore.initial().animals[0].id,name:'伙伴'},{kind:'fish',id:'river',name:'钓点'},{kind:'gather',id:'berry-1',item:'berry',event:'',name:'野果'},{kind:'tools',id:'tools',name:'工具台'},...ZRZData.npcs.map(n=>({kind:'npc',id:n.id,name:n.name}))];
const rows=[];
for(const near of targets)for(const room of [null,'home-granny'])for(const riding of [false,true])for(const walking of [false,true])for(const choices of [0,1,2])for(const mode of ['keyboard','pad','touch'])for(const guard of ['free','menu','locked']){
 const s=ZRZCore.initial();s.village.interior=room;s.village.riding=riding;s.player.x=100;s.player.y=100;
 const path=walking?[{x:295,y:100},{x:295,y:295}]:[],pending=walking?{name:'前往菜地'}:null;
 let walk={};const exiting=walking&&room!==null;
 const output=fn(near,s,guard==='menu'?'bag':null,guard==='locked',path,{options:Array(choices)},mode,'hand',pending,exiting?{}:null,ZRZFeedback,ZRZVillage,button,escape,()=>walk,walk);
 const buttons=[...output.html.matchAll(/<button([^>]*)>([^<]*)<\/button>/g)].map(m=>({label:m[2].replaceAll('&amp;','&'),action:/data-action="([^"]*)"/.exec(m[1])?.[1]||'',id:/data-id="([^"]*)"/.exec(m[1])?.[1]||'',op:/data-op="([^"]*)"/.exec(m[1])?.[1]||''}));
 rows.push({near,room:room||'',riding,walking,choices,mode,menu:guard==='menu',locked:guard==='locked',verb:near?ZRZFeedback.describe(s,near,'hand').verb:'',house:near?.kind==='npc'?ZRZVillage.homeOf(near.id).id:'',path,exiting,pending:pending?.name||'',expected:{hidden:output.hidden,buttons,progress:output.progress}});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));console.log('Exported '+rows.length+' actual source updateContext outputs');
