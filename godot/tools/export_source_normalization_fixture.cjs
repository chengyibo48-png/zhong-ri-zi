const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','building','tools','economy','scenes','actions','environment','forage','interiors','fishing','npc-content','npc','feedback','characters','ui-art','visual-fx','museum'])require('../../src/'+name+'.js');
function rawLife(s){return Object.fromEntries(['storage','quality','storageQuality','knownRecipes','stories','partners','marriage','projects','chapters','letters','mailRead','furniture','skills','archives','achievements','pet','yearPlans'].map(k=>[k,s[k]]));}
const rows=[];
function add(label,setup){const before=ZRZCore.initial();setup(before);let expected=null,error='';try{const s=ZRZCore.load(before);expected={memories:s.village.memories,chores:s.village.chores,neighbors:s.neighbors,life:rawLife(s)};}catch(e){error=e.message;}rows.push({label,before,expected,error});}
add('village/filtered',s=>{s.day=5;s.village.memories={valid:5,negative:-1,future:6,fraction:.5,numeric:'1',[ '🌾'.repeat(45) ]:3,[ '🌾'.repeat(44) ]:2};s.village.chores={valid:0,numeric:'2',future:6};});
add('village/arrays',s=>{s.village.memories=[0,1,-1,0];s.village.chores=[0,-1,0];});
add('neighbor/repeated',s=>{s.neighbors.people.he.recent=['seen','seen','other'];});
add('neighbor/utf16',s=>{s.neighbors.people.he.recent=['🌾'.repeat(50),'old','old'];});
for(const version of [1,2]){add('version/'+version+'/valid',s=>s.version=version);
for(const [key,value]of [['minutes',359],['day',.5],['money',-1]])add('version/'+version+'/'+key,s=>{s.version=version;s[key]=value;});
add('version/'+version+'/plot',s=>{s.version=version;s.plots[0].growth=-1;});
add('version/'+version+'/bag',s=>{s.version=version;s.bag.bad=1;});}
for(const version of [1,2])add('version/'+version+'/ignored-life',s=>{s.version=version;s.day=5;s.storage={wood:123};s.quality={cabbage:[1,0]};s.knownRecipes=[];s.letters=[{id:'bad',day:5,title:'wrong',from:'wrong',text:'wrong'}];s.archives=[];s.furniture={bench:99};s.pet.name='wrong';s.pet.bond=80;s.skills.farming.xp=99;s.yearPlans={'0':2};s.plots[0].care=25;s.plots[0].pest=true;});
fs.writeFileSync(process.argv[2],rows.map(r=>JSON.stringify(r)).join('\n')+'\n');console.log('Source normalization cases: '+rows.length);
