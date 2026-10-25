const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
require('../../src/characters.js');
const C=ZRZCore,copy=x=>JSON.parse(JSON.stringify(x)),rows=[],source=fs.readFileSync(require('node:path').join(__dirname,'../../src/panels.js'),'utf8');
const start=source.indexOf("case'e-appearance':")+"case'e-appearance':".length,end=source.indexOf(';save();update();toast',start),apply=new Function('s','val','document','root',source.slice(start,end)+';');
for(let shirt=0;shirt<4;shirt++)for(let hair=0;hair<4;hair++)for(let skin=0;skin<3;skin++)for(const name of ['新名字','','   ','  禾溪新邻居  ','一二三四五六七八九十甲乙丙丁戊己','小😀满']){
 const s=C.initial(),index=shirt*12+hair*3+skin,form={name,gender:['不设定','女','男'][index%3],shirt,hair,skin,hat:index%2===0,hairColor:index%4,outfit:['field','apron','traveler','festival'][Math.floor(index/3)%4],bag:Math.floor(index/2)%2===0,weatherDress:Math.floor(index/4)%2===0},before=copy(s);
 apply(s,id=>form[id.slice('appearance-'.length)],{getElementById:id=>({checked:form[id.slice('appearance-'.length)]})},globalThis);
 rows.push({form,before,expected:{name:s.name,gender:s.gender,appearance:s.appearance}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Appearance source forms: '+rows.length);
