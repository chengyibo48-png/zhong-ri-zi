const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions','panels','npc-ui'])require('../../src/'+name+'.js');
const esc=s=>String(s??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;'),unesc=s=>s.replaceAll('&quot;','"').replaceAll('&#39;',"'").replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&');
const rows=[];
for(const n of ZRZData.npcs)for(let step=0;step<=ZRZData.arcs[n.id].length;step++)for(const mode of ['ready','far','low','missing','cooldown','married','otherSpouse','dating']){
 const s=ZRZCore.initial();s.day=10;s.minutes=600;ZRZNpc.ensure(s);
 s.stories[n.id]={step,choices:Array.from({length:step},(_,i)=>i%2),lastDay:mode==='cooldown'?10:-1};
 s.relations[n.id].points=mode==='low'?0:100;
 if(mode==='married')s.marriage.spouse=n.id;
 if(mode==='otherSpouse')s.marriage.spouse=n.id==='granny'?'lin':'granny';
 if(mode==='dating')s.partners[n.id]='dating';
 const event=ZRZData.arcs[n.id][step];
 if(event?.needs)for(const [id,count] of Object.entries(event.needs))s.bag[id]=mode==='missing'?0:count+2;
 s.player.x=2831;s.player.y=1652;s.village.interior=null;s.village.npc[n.id]={x:2831+(mode==='far'?81:0),y:1652,room:null};
 const A={head:(title,subtitle='')=>'<h2>'+esc(title)+'</h2><header>'+esc(subtitle)+'</header>',button:(label,action,id='',cls='',extra='')=>'<button data-action="'+action+'" '+extra+'>'+esc(label)+'</button>',escape:esc,ingredients:needs=>'<div class="ingredients">'+Object.entries(needs).map(([id,count])=>'<span class="'+((s.bag[id]||0)<count?'missing':'')+'">'+ZRZData.items[id].name+' '+(s.bag[id]||0)+' / '+count+'</span>').join('')+'</div>'};
 const html=ZRZPanels.render('story',n.id,s,A);
 const buttons=[...html.matchAll(/<button data-action="([^"]*)"[^>]*>([^<]*)<\/button>/g)].map(m=>({action:m[1],text:unesc(m[2])}));
 const memories=[...html.matchAll(/<details class="memory-page"><summary>([^<]*)<\/summary><p>([^<]*)<\/p><p>([^<]*)<\/p><p>([^<]*)<\/p><\/details>/g)].map(m=>({title:unesc(m[1]),text:unesc(m[2]),choice:unesc(m[3]),reply:unesc(m[4])}));
 const expected={title:unesc(/<h2>([^<]*)<\/h2>/.exec(html)[1]),subtitle:unesc(/<header>([^<]*)<\/header>/.exec(html)[1]),text:unesc(/class="dialogue-quote typed-text">([^<]*)/.exec(html)?.[1]||''),needs:[...html.matchAll(/<span class="(missing|)">([^<]*)<\/span>/g)].map(m=>({text:unesc(m[2]),missing:m[1]==='missing'})),ready:unesc(/<div class="paper-note">([^<]*)<\/div>/.exec(html)?.[1]||''),choices:buttons.filter(b=>b.action==='e-story-choice').map(b=>b.text),find:buttons.some(b=>b.action==='find-npc'),memories,relationship:buttons.find(b=>['e-date','e-wedding-open'].includes(b.action))?.text||''};
 rows.push({id:n.id,step,mode,story:s.stories[n.id],points:s.relations[n.id].points,spouse:s.marriage.spouse||'',partner:s.partners[n.id]||'',bag:s.bag,expected});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Actual source story views: '+rows.length);
