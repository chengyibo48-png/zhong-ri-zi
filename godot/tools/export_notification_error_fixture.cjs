const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback'])require('../../src/'+name+'.js');
const source=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8');
const start=source.indexOf('  function toast(msg, error = false, important = false) {'),end=source.indexOf('  function apply(',start);
const rows=[];
for(const quiet of [false,true])for(const mode of ['plain','merge','changed','nextday','capacity','maxcount','long','emoji-cut','emoji-long','failed']){
 const s=ZRZCore.initial();s.day=10;s.minutes=610.875;s.feedback={version:1,next:1,rows:[],days:[],seen:[],prefs:{pace:'normal',motion:'full',floating:'normal',seconds:5,quiet}};
 let msg=mode==='long'?'错误与物品 <青菜> & “邻居”\n'.repeat(160):'材料还没有备齐，慢慢来。';
 if(mode==='emoji-cut')msg='田'.repeat(99)+'🌾末';
 if(mode==='emoji-long')msg='田'.repeat(1799)+'🌾末';
 if(['merge','changed','nextday','maxcount'].includes(mode)){
  ZRZFeedback.note(s,{key:'error/'+msg.slice(0,100),title:'这一步还没完成',text:mode==='changed'?'旧提示':msg,type:'未完成',priority:1,merge:true});
  s.feedback.rows[0].read=true;s.minutes=629.75;
  if(mode==='nextday')s.day++;
  if(mode==='maxcount')s.feedback.rows[0].count=999999;
 }
 if(mode==='capacity')for(let i=0;i<80;i++)ZRZFeedback.note(s,{key:'old/'+i,title:'旧记录',text:'已有',priority:i===30?0:1});
 const before=structuredClone(s.feedback);let saves=[];
 const el={remove(){},setAttribute(){},textContent:''},stack={children:[],appendChild(n){this.children.push(n);},get firstChild(){return this.children[0];}};
 const ctx={s,currentPanel:'menu',Feedback:ZRZFeedback,save:()=>{saves.push(structuredClone(s.feedback));return mode!=='failed';},
 document:{createElement:()=>({...el})},$:id=>id==='toasts'?stack:{querySelector:()=>null,prepend(){}},setTimeout(){}};
 vm.createContext(ctx);vm.runInContext(source.slice(start,end),ctx);ctx.toast(msg,true,false);
 rows.push({mode,quiet,day:s.day,minute:s.minutes,message:msg,before,after:s.feedback,saves});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source toast error transactions '+rows.length);
