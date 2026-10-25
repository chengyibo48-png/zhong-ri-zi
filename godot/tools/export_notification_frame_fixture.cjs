const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../src/app.js'),'utf8'),a=source.indexOf('if(frameTime>feedbackPollAt&&!document.hidden)'),b=source.indexOf('\n    if(pointer',a);
if(a<0||b<0)throw Error('source poll frame missing');
const rows=[];
for(const added of [false,true]){
 const ctx={frameTime:0,feedbackPollAt:0,document:{hidden:false},s:{},calls:[],Feedback:{poll(){ctx.calls.push('poll');return added?[{title:'提醒',text:'内容',priority:1},{title:'照料',text:'需要关注',priority:2}]:[];}},save(){ctx.calls.push('save');},update(){ctx.calls.push('update');},toast(text,error,important){ctx.calls.push(['toast',text,error,important]);}};
 vm.createContext(ctx);
 for(const [at,hidden] of [[0,false],[.001,false],[1,true],[4.001,false],[4.002,true],[20,true],[20.1,false],[24.1,false],[24.101,false],[50,false],[54,false],[54.01,false]]){
  ctx.frameTime=at;ctx.document.hidden=hidden;ctx.calls=[];
  const before=ctx.feedbackPollAt;vm.runInContext(source.slice(a,b),ctx);
  rows.push({added,at,hidden,before,after:ctx.feedbackPollAt,calls:ctx.calls});
 }
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source poll frame snapshots '+rows.length);
