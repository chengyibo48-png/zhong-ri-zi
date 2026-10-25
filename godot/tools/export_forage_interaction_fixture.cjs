const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[];
for(let day=0;day<112;day++)for(const item of Object.keys(ZRZForage.defs))for(const variant of ['base','full','rest','season-weather','experienced','buffs','collected']){
 const s=ZRZCore.initial();s.day=day;s.minutes=450;
 const p={id:'status-'+item,kind:'gather',item,name:ZRZForage.defs[item].name,event:''};
 s.stamina=[0,1,2,3,10][day%5];
 if(variant==='collected')s.collected[p.id]=day;
 if(variant==='full')s.forage.mode='full';
 if(variant==='rest')s.forage.patches[p.id]={lastDay:day,readyDay:day+2,pressure:5};
 if(variant==='season-weather')p.event=day%3===0?'storm':day%3===1?'rain':'mist';
 if(variant==='experienced'){s.forage.xp=20;s.toolkit.tools.axe.level=2;s.toolkit.tools.axe.branch='broad';}
 if(variant==='buffs'){s.skills.farming.choice='gentle';s.buffs.laborDay=day;s.kitchen.buff={kind:'暖胃',until:day*1440+500};s.toolUpgrades.gather=true;}
 rows.push({day,variant,p,stamina:s.stamina,forage:s.forage,toolkit:s.toolkit,skills:s.skills,buffs:s.buffs,toolUpgrades:s.toolUpgrades,kitchen:s.kitchen,collected:s.collected,expected:ZRZFeedback.describe(s,p,'hand')});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));console.log('Exported '+rows.length+' original forage interaction descriptions');
