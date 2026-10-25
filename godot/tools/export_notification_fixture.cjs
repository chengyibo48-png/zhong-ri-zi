const fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'../../src/app.js'),'utf8');
const start=source.indexOf('  function toast(msg, error = false, important = false) {');
const end=source.indexOf('  function apply(',start);
if(start<0||end<0)throw Error('source toast missing');
class Element{
 constructor(tag){this.tag=tag;this.textContent='';this.children=[];this.dataset={};this.attributes={};this.parent=null;}
 appendChild(el){el.parent=this;this.children.push(el);}
 remove(){if(this.parent){this.parent.children=this.parent.children.filter(e=>e!==this);this.parent=null;}}
 setAttribute(k,v){this.attributes[k]=v;}
 get firstChild(){return this.children[0];}
}
const rows=[];
for(const seconds of [5,8,12])for(const quiet of [false,true])for(const modal of [false,true]){
 let now=0,timers=[],notes=[],saves=0;
 const stack=new Element('section'),body=new Element('section'),subtitle=new Element('p');
 body.querySelector=()=>body.children.find(e=>e.className?.includes('modal-toast'));
 body.prepend=el=>{el.parent=body;body.children.unshift(el);};
 subtitle.after=el=>body.appendChild(el);
 const ctx={s:{},currentPanel:modal?'menu':null,Feedback:{ensure:()=>({prefs:{seconds,quiet}}),note:(_,data)=>notes.push(data)},save:()=>saves++,
 document:{createElement:tag=>new Element(tag)},$:id=>id==='toasts'?stack:{querySelector:selector=>selector==='.subtitle'?subtitle:body.querySelector(selector),prepend:body.prepend},
 setTimeout:(fn,ms)=>timers.push({fn,at:now+ms/1000})};
 vm.createContext(ctx);vm.runInContext(source.slice(start,end),ctx);
 const ops=[
 ['add','普通收获',false,false],['add','重要回响',false,true],['add','操作未完成',true,false],['add','第四条',false,false],
 ['advance',2],['add','重要回响',false,true],['add','重要回响 · 查看回响 →',false,false],
 ['add','多行\n信息与 <物品> & “村民”',false,false],['add','长文字'.repeat(120),true,true],
 ['advance',4],['advance',2],['advance',5],
 ['add','同字不同错误',false,false],['add','同字不同错误',true,false],['advance',seconds]
 ];
 for(const op of ops){
  if(op[0]==='add')ctx.toast(op[1],op[2],op[3]);
  else {now+=op[1];for(const timer of timers.filter(t=>t.at<=now))timer.fn();timers=timers.filter(t=>t.at>now);}
  rows.push({seconds,quiet,modal,now,op,world:stack.children.map(e=>({text:e.textContent,error:e.className.includes('error'),important:e.tag==='button'})),inline:body.children.map(e=>({text:e.textContent,error:e.className.includes('error')})),notes:notes.length,saves});
 }
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source toast snapshots '+rows.length);
