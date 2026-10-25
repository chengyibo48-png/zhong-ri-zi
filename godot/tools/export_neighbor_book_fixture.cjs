const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions','panels','npc-ui'])require('../../src/'+name+'.js');

const rows=[],unesc=s=>s.replaceAll('&quot;','"').replaceAll('&#39;',"'").replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&');
const A={head:(title,subtitle='')=>'<h2>'+title+'</h2><header>'+subtitle+'</header>',button:(text,action,id='')=>'<button data-action="'+action+'" data-id="'+id+'">'+text+'</button>'};
for(const status of ['none','offered','accepted','postponed','done'])for(const person of ZRZData.npcs){
 const s=ZRZCore.initial();s.day=10;s.minutes=600;ZRZNpc.ensure(s);
 s.neighbors.people[person.id].event=status==='none'?null:{status,day:10};
 const ctx={open(){},render(){}};
 ZRZPanels.dispatch('np-person',person.id,{},ctx);
 const html=ZRZPanels.render('neighbors','',s,A);
 const article=/<article>(.*?)<\/article>/s.exec(html)[1];
 const data={id:person.id,name:/<h3>(.*?)<\/h3>/.exec(article)[1],role:/<span>(.*?)<\/span>/.exec(article)[1],profile:/<p>(.*?)<\/p>/.exec(article)[1],location:unesc(/<p><strong>(.*?)<\/strong> · (.*?)<\/p>/.exec(article).slice(1).join(' · ')),reason:unesc(/<small>(.*?)<\/small>/.exec(article)[1]),schedule:/<details>.*?<p>(.*?)<\/p>/.exec(article)[1],promise:/class="np-promise">(.*?)<\/p>/.exec(article)?.[1]||''};
 rows.push({status,id:person.id,resident:s.village?.npc?.[person.id]||null,expected:data});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source neighbor book views '+rows.length);
