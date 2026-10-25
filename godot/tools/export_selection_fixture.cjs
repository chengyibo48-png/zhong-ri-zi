const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback']) require('../../src/'+name+'.js');
const C=global.ZRZCore, F=global.ZRZFeedback;
const rows=[];
const selector=new F.Selection();
const s=C.initial(); s.player.x=100; s.player.y=100;
const point=(id,x,y,kind='tea')=>({id,x,y,kind,name:id});
function choose(label,points,{face='down',tool='hand',hover=null,room=null}={}){
 s.player.direction=face;s.village.interior=room;
 const chosen=selector.choose(s,points,hover,tool);
 rows.push({label,points:points.map(p=>({...p,ready:F.describe(s,p,tool).ready})),face,tool,hover,room,expected:F.targetKey(chosen),order:selector.options.map(F.targetKey)});
}
choose('面对前方',[point('near',100,90),point('front',100,125)]);
choose('保留相近目标',[point('near',100,90),point('front',100,121)]);
let cycled=selector.cycle(1);rows.push({cycle:1,expected:F.targetKey(cycled)});
choose('手动目标优先于鼠标',[point('near',100,90),point('front',100,120)],{hover:point('front',100,120)});
choose('目标远离后失效',[point('front',100,120)]);
choose('鼠标优先',[point('left',80,100),point('right',120,100)],{hover:point('right',120,100),face:'left'});
choose('53 像素边界',[point('edge',153,100),point('inside',152.99,100)],{room:'a'});
choose('房间切换清空',[point('a',99,100),point('b',100,120)],{room:'b'});
choose('重复键后者覆盖',[point('dup',100,101),point('dup',100,130),point('other',100,110)],{room:'c'});
const plot={kind:'plot',index:2,x:100,y:120,name:'田块'};
choose('工具匹配与可操作性',[plot,point('tea',100,119)],{tool:'hoe',room:'d'});
selector.clear();rows.push({clear:true});
choose('清空后不保留选择',[point('a',80,100),point('b',120,100)],{face:'right',room:'d'});
for(let i=0;i<3;i++){let p=selector.cycle(-1);rows.push({cycle:-1,expected:F.targetKey(p)});}
if(!process.argv[2])throw Error('Pass a temporary output filename');
fs.writeFileSync(process.argv[2],JSON.stringify(rows,null,2));
console.log('Exported '+rows.length+' original target-selection steps');
