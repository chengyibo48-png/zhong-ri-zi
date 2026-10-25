const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions','panels','npc-ui'])require('../../src/'+name+'.js');
const A={head:(t,s='')=>'<h2>'+t+'</h2><header>'+s+'</header>',button:(t,a,id='')=>'<button data-action="'+a+'" data-id="'+id+'">'+t+'</button>'};
const unesc=s=>s.replaceAll('&quot;','"').replaceAll('&#39;',"'").replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&');
const cases=[];
for(let scenario=0;scenario<3;scenario++){
 const s=ZRZCore.initial();s.day=10;s.minutes=600;ZRZNpc.ensure(s);
 if(scenario){for(const [i,n]of ZRZData.npcs.entries()){s.relations[n.id].points=[0,10,30,70,100][i%5];s.stories[n.id].step=Math.min(scenario===2?99:i%5,ZRZData.arcs[n.id].length);s.stories[n.id].choices=Array.from({length:s.stories[n.id].step},(_,k)=>k%2);s.stories[n.id].lastDay=i%2?10:-1;}const romance=ZRZData.npcs.filter(n=>n.tier==='romance');s.partners[romance[0].id]='dating';s.partners[romance[1].id]='dating';s.stories[romance[1].id]={step:4,choices:[0,1,0,1],lastDay:-1};s.marriage.spouse=romance[1].id;}
 for(const filter of ['全部','画像册','成年候选人','主要邻居','孩子们']){
  ZRZPanels.dispatch('e-npc-filter',filter,{}, {s,render(){},open(){}});
  const html=ZRZPanels.render('relations','',s,A);
  const cards=[...html.matchAll(/<article(?: class="row-card")?>(.*?)<\/article>/gs)].map(match=>{
   const t=match[1],id=/data-npc="(.*?)"/.exec(t)[1],name=ZRZData.npcs.find(n=>n.id===id).name;
   if(filter==='画像册')return{id,name,role:unesc(/<p>(.*?)<\/p>/s.exec(t)[1])};
   const ps=[...t.matchAll(/<p>(.*?)<\/p>/gs)].map(m=>unesc(m[1]).replaceAll('<br>','\n'));
   return{id,name,profile:ps[0],story:ps[1],stage:unesc(/class="tag">(.*?)<\/span>/s.exec(t)[1]),points:s.relations[id].points};
  });
  cases.push({scenario,filter,state:s,expected:cards});
 }
}
fs.writeFileSync(process.argv[2],JSON.stringify({cases}));console.log('Actual source relations views '+cases.length);
