const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions','panels','npc-ui'])require('../../src/'+name+'.js');
const rows=[],esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;'),unesc=s=>s.replaceAll('&quot;','"').replaceAll('&#39;',"'").replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&');
const A={head:(title,subtitle='')=>'<h2>'+esc(title)+'</h2><p>'+esc(subtitle)+'</p>',button:(text,action,id='')=>'<button data-action="'+action+'" data-id="'+id+'">'+esc(text)+'</button>'};
for(const n of ZRZData.npcs)for(const status of ['none','offered','accepted','postponed','done'])for(const latest of [false,true]){
 const s=ZRZCore.initial();s.day=10;s.minutes=600;ZRZNpc.ensure(s);
 s.neighbors.people[n.id].event=status==='none'?null:{day:10,status,method:'join',completed:10};
 s.neighbors.people[n.id].last=latest?{text:'当前台词 '+n.id,emotion:'thought',category:'记忆'}:null;
 const html=ZRZPanels.render('npc',n.id,s,A);
 const buttons=[...html.matchAll(/<button[^>]*>([^<]*)<\/button>/g)].map(m=>unesc(m[1]));
 const quote=unesc(/class="dialogue-quote typed-text">([^<]*)/.exec(html)[1]);
 rows.push({id:n.id,status,latest,buttons,quote});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('NPC source dialogue rows '+rows.length);
