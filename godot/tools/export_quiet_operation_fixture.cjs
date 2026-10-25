const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const setTool=source.split('\n').find(line=>line.includes('function setTool(id)'));
const bike=source.slice(source.indexOf("if(a==='v-bike')"),source.indexOf("if(a==='v-stop')"));
const start=source.indexOf("if(a==='v-stop')"),stop=source.slice(start,source.indexOf('\n',start));
const rows=[];
for(const op of [...['hoe','seed','water','hand','rod','axe','sickle','build'].map(id=>({kind:'tool',id})),{kind:'bike',room:null,riding:false},{kind:'bike',room:null,riding:true},{kind:'bike',room:'home-granny',riding:false},{kind:'stop'}]){
 const ctx={a:op.kind==='bike'?'v-bike':'v-stop',s:{village:{interior:op.room||null,riding:op.riding||false}},toasts:[],sounds:[],selection:{clear(){}},T:{},update(){},sound(kind="action"){ctx.sounds.push(kind);},openPanel(){},toast(msg){ctx.toasts.push(msg);},path:[1],pending:{},queuedDestination:{},farmQueue:[1],ranchQueue:[1],kitchenTask:{},buildTask:{}};
 vm.createContext(ctx);
 if(op.kind==='tool'){vm.runInContext(setTool,ctx);ctx.setTool(op.id);}
 else vm.runInContext('(function(){'+(op.kind==='bike'?bike:stop)+'})()',ctx);
 rows.push({...op,toasts:ctx.toasts,sounds:ctx.sounds,tool:ctx.tool||null,riding:ctx.s.village.riding});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source operation notification cases '+rows.length);
