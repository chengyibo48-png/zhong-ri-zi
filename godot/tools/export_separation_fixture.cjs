const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions','panels','npc-ui'])require('../../src/'+name+'.js');
const C=ZRZCore,D=ZRZData,copy=x=>JSON.parse(JSON.stringify(x)),adults=D.npcs.filter(n=>n.tier==='romance'&&n.age>=18);
const esc=s=>String(s??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;'),unesc=s=>s.replaceAll('&quot;','"').replaceAll('&#39;',"'").replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&');
const A={head:(title,subtitle='')=>'<h2>'+esc(title)+'</h2><header>'+esc(subtitle)+'</header>',button:(label,action)=>'<button data-action="'+action+'">'+esc(label)+'</button>',escape:esc};
const html=ZRZPanels.render('separation','',C.initial(),A);
const view={title:unesc(/<h2>([^<]*)<\/h2>/.exec(html)[1]),subtitle:unesc(/<header>([^<]*)<\/header>/.exec(html)[1]),quote:unesc(/<p>([^<]*)<\/p>/.exec(html)[1]),confirm:unesc(/data-action="e-separate">([^<]*)/.exec(html)[1]),cancel:unesc(/data-action="home">([^<]*)/.exec(html)[1])};
const rows=[];
for(const n of adults)for(const mode of ['normal','low','swap','day','none']){
 const s=C.initial();s.day=10;s.minutes=600;s.partners[n.id]='dating';s.stories[n.id]={step:4,choices:[0,0,0,0],lastDay:5};s.relations[n.id].points=70;s.marriage={spouse:n.id,day:5,weekly:{'1-visit':true},memories:[{day:5,activity:'visit'}]};
 const before=copy(s);
 if(mode==='low')s.relations[n.id].points=0;
 if(mode==='swap'){const other=adults.find(a=>a.id!==n.id).id;s.partners[other]='dating';s.marriage.spouse=other;}
 if(mode==='day')s.day++;
 if(mode==='none')s.marriage={spouse:null,day:-1,weekly:{},memories:[]};
 const mutation={day:s.day,marriage:copy(s.marriage),partners:copy(s.partners),relations:copy(s.relations)};
 let result=null,opened=null;
 ZRZPanels.dispatch('e-separate','',{}, {s,apply:r=>{result=copy(r);return r.ok;},open:name=>{opened=name;},render:()=>{},save:()=>{},update:()=>{},toast:()=>{}});
 rows.push({id:n.id,mode,before,mutation,result,opened,expected:{marriage:s.marriage,partners:s.partners,relations:s.relations,stories:s.stories,bag:s.bag,journal:s.journal,eventLog:s.eventLog}});
}
fs.writeFileSync(process.argv[2],JSON.stringify({view,rows}));console.log('Separation source dispatch cases: '+rows.length);
