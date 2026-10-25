const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
for(const skill of [...Object.keys(D.skillNames),'missing'])for(const choice of [...(D.skillChoices[skill]||[]).map(v=>v[0]),'missing'])for(const xp of [0,24,25,26,99999])for(const selected of [null,...(D.skillChoices[skill]||[]).map(v=>v[0])]){
 const s=C.initial();if(s.skills[skill])s.skills[skill]={xp,choice:selected};const before=copy(s),result=C.skill(s,skill,choice);
 rows.push({skill,choice,xp,selected,before,result,expected:copy(s.skills)});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Skill choice source cases: '+rows.length);
