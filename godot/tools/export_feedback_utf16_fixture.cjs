const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback'])require('../../src/'+name+'.js');
const rows=[],samples=['普通文字','🌾'.repeat(100),'田'.repeat(139)+'🌾末','田'.repeat(119)+'🌾末','田'.repeat(1799)+'🌾末','😀'.repeat(910),'a\0b\ud800c\udfff','\ud800'.repeat(150),'\udfff'.repeat(150),null,true,12.75,{},['田',null,'🌾']];
for(const [i,value] of samples.entries())for(const merge of [false,true]){
 const s=ZRZCore.initial();s.day=10;s.minutes=610.75;
 const data={key:value,title:value,text:value,priority:1,type:'提醒',link:'feedback',merge};
 const before=structuredClone(s.feedback),first=structuredClone(ZRZFeedback.note(s,data));
 s.feedback.rows[0].read=true;s.minutes=629.25;
 const next={...data,text:typeof value==='string'?value+'另一个🌾':'修改'};
 const second=structuredClone(ZRZFeedback.note(s,next));
 rows.push({mode:'note',i,merge,day:s.day,minute:610.75,before,data,next,first,second,after:structuredClone(s.feedback)});
}
for(const size of [49,50,51,52,65,66,67,68,69,70,90]){
 const s=ZRZCore.initial();s.day=10;s.minutes=600.75;ZRZNpc.ensure(s);
 for(const a of s.animals){a.hunger=100;a.illness=0;}
 for(const p of Object.values(s.neighbors.people))p.event=null;
 s.economy.jobs=[];s.kitchen.jobs=[{key:'🌾'.repeat(size)+'尾',id:'pickles',station:'pickle',qty:1,grade:0,ready:0}];
 const before=structuredClone(s),added=ZRZFeedback.poll(s),after=structuredClone(s.feedback);
 const repeatAdded=ZRZFeedback.poll(s);
 rows.push({mode:'poll',size,before,after,repeatAfter:structuredClone(s.feedback),count:added.length,repeatCount:repeatAdded.length});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source UTF-16 feedback transactions '+rows.length);
