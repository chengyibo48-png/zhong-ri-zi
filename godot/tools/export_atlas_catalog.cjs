const fs=require('node:fs');
function atlasCatalog(){
 const s=global.ZRZCore.initial(),V=global.ZRZVillage,S=global.ZRZScenes;
 const rows=S.targets(s);
 return {version:1,foragePoints:V.points(s,true).filter(p=>p.kind==='gather'),sceneryPoints:global.ZRZTiles.points(s),regions:rows.filter(p=>p.id.startsWith('region-'))};
}
module.exports=atlasCatalog;
if(require.main===module){
 global.window=globalThis;
 for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
 const value=require('./export_world_precision.cjs')(atlasCatalog());
 fs.writeFileSync(process.argv[2],JSON.stringify(value,null,2)+'\n');
 console.log(JSON.stringify({forage:value.foragePoints.length,scenery:value.sceneryPoints.length,regions:value.regions.length}));
}
