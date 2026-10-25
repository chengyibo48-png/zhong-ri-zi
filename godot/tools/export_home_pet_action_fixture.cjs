const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
for(const type of ['cat','dog'])for(const bond of [0,98,100])for(const energy of [0,98,100])for(const already of [false,true]){
 const s=C.initial();s.pet.type=type;s.pet.name='禾溪小团';s.pet.bond=bond;s.pet.patted=already?s.day:-1;s.ranch.pet.energy=energy;const before=copy(s),result=C.pet(s);rows.push({op:'play',before,result,expected:{pet:s.pet,ranchPet:s.ranch.pet}});
}
const source=fs.readFileSync(require('node:path').join(__dirname,'../../src/panels.js'),'utf8'),start=source.indexOf("case'e-pet-name':")+"case'e-pet-name':".length,end=source.indexOf(';save();refresh();toast',start),apply=new Function('s','val',source.slice(start,end)+';');
for(const type of ['cat','dog'])for(const name of ['春团','','   ','  小白  ','abcdefghijklmnop','一二三四五六七八九十甲乙丙丁','小😀团']){
 const s=C.initial(),before=copy(s);apply(s,id=>id==='pet-name'?name:type);rows.push({op:'name',name,type,before,result:{ok:true,msg:'记住了这个名字。'},expected:{pet:s.pet,ranchPet:s.ranch.pet}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Home pet source cases: '+rows.length);
