const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','kitchen','building','tools','economy','scenes','environment','forage','interiors','fishing','npc-content','npc','feedback','ranch-view','tiles','museum','actions'])require('../../src/'+name+'.js');
const rows=[],copy=x=>JSON.parse(JSON.stringify(x));
const points=[...['enter','exit','tools','storage','economy','build','rest','tea','bed-visit','egg','chore','ambient'].map(kind=>({kind,name:'测试物件'})),...['','rest','water','storage'].map(service=>({kind:'build-piece',service,name:'测试设施'})),...['stove','steam','preserve'].map(station=>({kind:'kitchen-station',station,name:'测试工位'})),{kind:'fish',name:'测试钓点'}];
for(let variant=0;variant<12;variant++){
 const s=ZRZCore.initial();s.stamina=[0,1,2,10][variant%4];s.money=variant%3===0?0:variant%3===1?5:10000;
 s.farm.water=variant%2?120:60;s.toolkit.tools.rod.level=variant%3;
 s.fishing.bait=variant%2?'plain':'grain';s.fishing.mode=variant%2?'standard':'relaxed';s.fishing.release=variant%3===0;
 s.storage={wood:variant,bamboo:variant+3};s.bag.wood=variant%2?999:0;s.bag.bamboo=variant%2?999:0;s.bag.rice=variant%2?10:0;
 if(variant>=4){s.kitchen.jobs=[{station:'stove',ready:variant%2?500:400},{station:'stove',ready:520},{station:'steam',ready:700}];s.economy.jobs=[{ready:400,price:53},{ready:500,price:42}];}
 if(variant>=8)s.building.jobs=[{id:variant%2?'house':'well',level:1,readyDay:1}];
 if(variant===10){s.skills.farming.choice='gentle';s.buffs.laborDay=s.day;s.kitchen.buff={kind:'暖胃',until:2000};}
 const before=copy(s),samples=points.map(p=>({p,expected:ZRZFeedback.describe(s,p,'hand')}));
 rows.push({variant,before,samples});
}
fs.writeFileSync(process.argv[2],JSON.stringify(require('./export_world_precision.cjs')({rows})));
console.log('Exported '+rows.length+' states, '+rows.reduce((n,r)=>n+r.samples.length,0)+' complete original descriptions');
