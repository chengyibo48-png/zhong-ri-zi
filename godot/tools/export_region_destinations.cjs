const fs=require('node:fs');global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const path=require('node:path'),file=process.argv[2]||path.join(__dirname,'../data/world.json'),world=JSON.parse(fs.readFileSync(file,'utf8'));
world.village.regionDestinations=Object.fromEntries(Object.keys(ZRZVillage.offsets).map(id=>[id,ZRZVillage.destination(ZRZCore.initial(),'region',id)]));
fs.writeFileSync(file,JSON.stringify(world,null,2)+'\n');console.log('Exported canonical region destinations: '+Object.keys(world.village.regionDestinations).length);
