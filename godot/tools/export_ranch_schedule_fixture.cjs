const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,R=ZRZRanch,K=ZRZKitchen,copy=x=>JSON.parse(JSON.stringify(x)),rows=[];
const snapshot=s=>Object.fromEntries(['day','minutes','stamina','money','kitchen','skills','stats','journal','eventLog','discovered','flags','bag','quality','knownRecipes','ranch','animals','pet','processing','toolkit','storage','storageQuality','upgrades','farm','plots','freeRange'].map(k=>[k,s[k]]));


require('../../src/panels.js');require('../../src/ranch-ui.js');
const days=[];for(let day=0;day<112;day++)if(!days.some(d=>C.weather(d)===C.weather(day)))days.push(day);
for(const day of days)for(const policy of ['safe','day','inside'])for(const zone of [0,1])for(const feed of ['feed','hay','grainFeed','healthFeed'])for(const initialRange of [true,false]){
 let s=C.initial();s.day=day;s.minutes=600.25;s.freeRange=initialRange;s.ranch.grass=[40.25,79.75];s.ranch.stores.feed=10;s.ranch.barns.poultry.autoFeed=s.ranch.barns.poultry.autoFeedBuilt=true;
 for(const a of s.animals){a.hunger=40.25;a.care.feed=-1;}K.ensure(s);s=C.load(copy(s));
 const before=copy(s),events=[];global.document={getElementById:id=>({value:{'ranch-policy':policy,'ranch-zone':String(zone),'ranch-feed':feed}[id]})};
 ZRZPanels.dispatch('r-policy','',{}, {s,apply(){},open(){},render(){events.push('refresh')},save(){events.push('save')},update(){events.push('update')},toast(msg){events.push(msg)},queueRanch(){}});
 const expected=copy(snapshot(s)),steps=[];for(let i=0;i<2;i++){const result=C.nextDay(s);steps.push({result,expected:copy(snapshot(s))});}
 rows.push({op:'schedule',id:policy,policy,zone,feed,day,variant:String(initialRange),before,expected,result:{ok:true,msg:events.at(-1)},steps});
}
const sample=C.initial();sample.ranch.notices=[{day:0,text:'台风来临，先照料屋舍。'},{day:27,text:'粮仓 <风 & 雨> [b]原样文字[/b]。'}];
ZRZPanels.dispatch('r-tab','guide',{}, {s:sample,render(){},save(){},update(){},toast(){},apply(){},open(){}});
const html=ZRZPanels.render('animals',null,sample,{head(){return''}});
const start=html.indexOf('<h3>不必把每一天过成清单');
const guide=html.slice(start);
const decode=t=>t.replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/&amp;/g,'&');
const blocks=[...guide.matchAll(/<(h3|p)(?: class="ranch-log")?>([^<]+)<\/\1>/g)].map(m=>({kind:m[1]==='h3'?'heading':'paragraph',text:decode(m[2])}));
fs.writeFileSync(process.argv[2]+'.guide.json',JSON.stringify({blocks,notices:sample.ranch.notices}));
console.log('Ranch schedule weather days: '+days.length);
function exact(row){const entries=[];function visit(value,path){if(typeof value==='number'&&!Number.isInteger(value)){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);entries.push({path,bytes:bytes.toString('base64')});}else if(Array.isArray(value))value.forEach((v,i)=>visit(v,[...path,i]));else if(value&&typeof value==='object')for(const[k,v]of Object.entries(value))visit(v,[...path,k]);}visit(row,[]);if(entries.length)row._float64_roundtrip={version:1,entries};return row;}
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(exact(r))).join('\n')+'\n');console.log('Ranch schedule cases: '+rows.length);
