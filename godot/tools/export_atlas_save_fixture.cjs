const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const C=ZRZCore,S=ZRZScenes,V=ZRZVillage,copy=x=>structuredClone(x),exact=require('./export_world_precision.cjs'),seed=C.initial(),rows=[];
function row(label,edit){const s=copy(seed);edit(s);let expected=null,error=null,scope=null;try{const loaded=C.load(copy(s));expected=copy(loaded.atlas);scope=copy(S.scope(loaded));}catch(e){error=e.message;}rows.push({label,before:s,ok:!error,expected,scope,error});}
row('baseline',()=>{});
for(const value of [null,false,0,'',true,1,'map',[],{},[1]])row('atlas-'+JSON.stringify(value),s=>s.atlas=value);
row('atlas missing',s=>delete s.atlas);
const values=[null,false,true,0,1,1.5,-1,1000000000,1000000001,'1',[],{}];
for(const key of ['version','nextId','minimap','layer','visited','pins']) {
 row('missing '+key,s=>delete s.atlas[key]);
 for(const value of values)row(key+'='+JSON.stringify(value),s=>s.atlas[key]=value);
}
for(const layer of S.layers)row('layer '+layer,s=>s.atlas.layer=layer);
for(const visited of [[],Object.keys(V.offsets),['farm','farm'],['unknown'],['constructor'],['__proto__'],['toString'],['farm',null],[1],Object.keys(V.offsets).concat('farm')])row('visited '+JSON.stringify(visited),s=>s.atlas.visited=visited);
const pin={id:'pin-1',x:2831.125,y:1652.75,label:'  小路  ',extra:{note:'保留'}};
function one(label,edit){row(label,s=>{s.atlas.pins=[copy(pin)];s.atlas.nextId=3;edit(s.atlas.pins[0],s.atlas,s);});}
for(const key of ['id','x','y','label']) {
 one('pin missing '+key,p=>delete p[key]);
 for(const value of [null,false,true,-1,0,24,38,3816,3816.000000001,'24',[],{}])one('pin '+key+'='+JSON.stringify(value),p=>p[key]=value);
}
for(const id of ['pin-0','pin-00','pin-01','pin-2','pin-3','pin--1','pin-1.5','pin-1x','pin-','pin-0000000000000000000000000001','pin-'+'9'.repeat(400),'pin-1\n','pin-1\r','pin-1\r\n','pin-1\u2028','pin-1\u2029'])one('id '+JSON.stringify(id),p=>p.id=id);
for(const label of ['', ' '.repeat(18),'中'.repeat(18),'中'.repeat(19),'😀'.repeat(9),'😀'.repeat(10),'a'.repeat(16)+'😀','a'.repeat(17)+'😀'])one('label length '+label.length,p=>p.label=label);
for(const n of [0,1,12,13])row('pin count '+n,s=>{s.atlas.pins=Array.from({length:n},(_,i)=>({...pin,id:'pin-'+i}));s.atlas.nextId=20;});
row('duplicate pins',s=>{s.atlas.pins=[pin,pin];s.atlas.nextId=3;});
for(const tracking of [null,false,0,'',true,1,[],{}, {id:null,x:2831.125,y:1652.75,name:''},{id:null,x:2831,y:1652,name:'  '},{id:'gone',x:2831,y:1652,name:'old'},{id:'home-granny',x:2831,y:1652,name:'cached'}])row('tracking '+JSON.stringify(tracking),s=>s.atlas.tracking=tracking);
for(const key of ['id','x','y','name']) {
 row('tracking missing '+key,s=>{s.atlas.tracking={id:null,x:2831,y:1652,name:'路线'};delete s.atlas.tracking[key];});
 for(const value of [null,false,true,0,24,38,3816,3816.000000001,'24',[],{},'😀'.repeat(50),'😀'.repeat(51)])row('tracking '+key+'='+JSON.stringify(value),s=>{s.atlas.tracking={id:null,x:2831,y:1652,name:'路线'};s.atlas.tracking[key]=value;});
}
row('extras preserved',s=>{s.atlas.extra={future:true};s.atlas.pins=[copy(pin)];s.atlas.nextId=3;s.atlas.tracking={id:null,x:2831.125,y:1652.75,name:'',extra:['note']};});
for(const h of V.houses)row('scope '+h.id,s=>{s.village.interior=h.id;s.atlas.visited=[];s.player={x:480,y:570,direction:'down'};});
for(const [id,offset] of Object.entries(V.offsets))row('region '+id,s=>{s.village.interior=null;s.player={x:offset.x+500,y:offset.y+700,direction:'down'};s.atlas.visited=[];});
for(const label of ['\ud800','\udc00','\0','a'.repeat(17)+'\ud800','a'.repeat(18)+'\ud800','😀'.repeat(8)+'a\ud800','\ud800'.repeat(18),'\ud800'.repeat(19),'  \ud800  '])one('raw UTF16 label length '+label.length,p=>p.label=label);
for(const name of ['\ud800','\udc00','\0','a'.repeat(99)+'\ud800','a'.repeat(100)+'\ud800','\ud800'.repeat(100),'\ud800'.repeat(101)])row('raw UTF16 tracking length '+name.length,s=>s.atlas.tracking={id:null,x:2831.125,y:1652.75,name});
for(const id of ['\ud800','\0'])row('raw UTF16 tracking id',s=>s.atlas.tracking={id,x:2831,y:1652,name:'旧目标'});
fs.writeFileSync(process.argv[2],'');
for(const row of rows)fs.appendFileSync(process.argv[2],JSON.stringify(exact(row))+'\n');
const counts={cases:rows.length,accepted:rows.filter(r=>r.ok).length,rejected:rows.filter(r=>!r.ok).length};
fs.writeFileSync(process.argv[2]+'.counts.json',JSON.stringify(counts));console.log(JSON.stringify(counts));
