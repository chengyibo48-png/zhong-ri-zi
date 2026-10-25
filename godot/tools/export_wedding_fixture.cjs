const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions','panels','npc-ui'])require('../../src/'+name+'.js');
const esc=s=>String(s??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;'),unesc=s=>s.replaceAll('&quot;','"').replaceAll('&#39;',"'").replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&');
const rows=[];
const A={head:(title,subtitle='')=>'<h2>'+esc(title)+'</h2><header>'+esc(subtitle)+'</header>',button:(label,action)=>'<button data-action="'+action+'">'+esc(label)+'</button>',escape:esc};
for(const id of [...ZRZData.npcs.map(n=>n.id),'missing']){
 const html=ZRZPanels.render('wedding',id,ZRZCore.initial(),A);
 rows.push({id,expected:{title:unesc(/<h2>([^<]*)<\/h2>/.exec(html)[1]),subtitle:unesc(/<header>([^<]*)<\/header>/.exec(html)[1]),quote:unesc(/class="dialogue-quote">([^<]*)/.exec(html)[1]),needs:unesc(/class="paper-note">([^<]*)/.exec(html)[1]),confirm:unesc(/data-action="e-marry">([^<]*)/.exec(html)[1]),cancel:unesc(/data-action="close">([^<]*)/.exec(html)[1])}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({rows}));console.log('Wedding source windows: '+rows.length);
