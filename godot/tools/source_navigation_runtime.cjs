// Load collision-changing gameplay modules in the actual game page's order.
const fs=require('node:fs'),path=require('node:path');
global.window=globalThis;
const selected=new Set(['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','kitchen-view','building','tools','economy','scenes','actions','environment','forage','interiors','fishing','npc-content','npc','feedback','tiles','museum','museum-view']);
const html=fs.readFileSync(path.join(__dirname,'../../index.html'),'utf8'),loaded=[];
for(const match of html.matchAll(/<script\s+src="src\/([^"]+)\.js"/g)){
 const name=match[1];if(!selected.has(name))continue;
 require(path.join(__dirname,'../../src',name+'.js'));loaded.push(name);
}
for(const name of selected)if(!loaded.includes(name))throw Error('Missing authoritative module '+name);
module.exports=loaded;
