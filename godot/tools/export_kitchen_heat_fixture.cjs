const fs=require('node:fs');
global.window=globalThis;
for(const name of ['data','content','landscape','core','systems','art','world','village','farming','ranch','ranch-view','kitchen','kitchen-view','building','tools','interiors'])require('../../src/'+name+'.js');
const text=fs.readFileSync(require.resolve('../../src/kitchen-ui.js'),'utf8');
const expression=text.match(/const value=(.*?);needle.style/)[1].replace('(performance.now()-ui.heat.started)','elapsed');
const sample=Function('elapsed','return '+expression);
const samples=[0,250,750,1100,1727.875959,2200,3455.751918,4400,6911.503836].map(ms=>({ms,value:sample(ms)}));
const cases=[null,0,34.999,35,50,75,75.001,100].map(heat=>{
 const s=ZRZCore.initial();s.bag.cabbage=4;
 const result=ZRZKitchen.make(s,'greens',1,false,heat);
 return {heat,result,cabbage:s.bag.cabbage,greens:s.bag.greens,quality:s.quality.greens||[0,0,0],stamina:s.stamina,minutes:s.minutes};
});
const seasonal=[0,1].map(manual=>{
 const s=ZRZCore.initial();s.bag.wildHerb=1;s.bag.shoot=1;s.quality.wildHerb=[1,0,0];s.quality.shoot=[1,0,0];
 const r=ZRZData.recipes.find(r=>r.id==='springBowl');
 return {manual,grade:ZRZKitchen.quality(s,r,r.ingredients,1,manual)};
});
fs.writeFileSync(process.argv[2],JSON.stringify({samples,cases,seasonal},null,2));
console.log('Exported original heat waveform and 8 cooking boundary cases');
