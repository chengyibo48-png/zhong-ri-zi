const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const text=fs.readFileSync(require('node:path').join(__dirname,'../../src/app.js'),'utf8');
const hover=text.slice(text.indexOf('function hoverInfo()'),text.indexOf('function coords(',text.indexOf('function hoverInfo()')));
const pos=text.slice(text.indexOf('function positionHover()'),text.indexOf("$('world').addEventListener('pointermove'",text.indexOf('function positionHover()')));
const run=new Function('hovered','currentPanel','inputLocked','s','tool','Feedback','escape','keyLabel','$',hover+";hoverInfo();");
const place=new Function('pointer','camera','$',pos+";positionHover();");
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const decode=s=>s.replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&quot;','"').replaceAll('&amp;','&');
const rows=[],positions=[],s=ZRZCore.initial();
const candidates=[...ZRZWorld.points(s),...ZRZTiles.points(s),...s.plots.map((p,index)=>({kind:"plot",index,...ZRZVillage.plotPosition(index)}))];
for(const point of candidates)for(const tool of ['hand','seed'])for(const key of ['E','Z']){
 const info=ZRZFeedback.describe(s,point,tool),box={hidden:true,innerHTML:''};
 run(point,null,false,s,tool,ZRZFeedback,escape,()=>key,()=>box);
 const match=/<strong>(.*?)<\/strong><small>(.*?)<\/small>/.exec(box.innerHTML);
 if(!match)throw Error('Unrecognized original hover markup');
 rows.push({info,key,expected:{hidden:box.hidden,name:decode(match[1]),body:decode(match[2].replaceAll('<br>','\n'))}});
}
const guards=[];
for(const hasTarget of [false,true])for(const menu of [false,true])for(const locked of [false,true]){
 const box={hidden:false,innerHTML:''};run(hasTarget?candidates[0]:null,menu?'menu':null,locked,s,'hand',ZRZFeedback,escape,()=> 'E',()=>box);
 guards.push({hasTarget,menu,locked,hidden:box.hidden});
}
for(const view of [{width:1280,height:800},{width:960,height:600},{width:640,height:360}])for(const width of [0,190,240])for(const height of [0,80,200])for(const pointer of [{x:-100,y:-100},{x:0,y:0},{x:300,y:200},{x:5000,y:5000}]){
 const box={offsetWidth:width,offsetHeight:height,style:{}};
 place(pointer,{view},()=>box);positions.push({view,width,height,pointer,x:parseFloat(box.style.left),y:parseFloat(box.style.top)});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows,guards,positions})));console.log('Exported '+rows.length+' hover texts, '+guards.length+' visibility cases, '+positions.length+' original positions');
