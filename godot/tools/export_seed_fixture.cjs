const fs = require('node:fs');
global.window = globalThis;
for (const name of ['data', 'content', 'landscape', 'core', 'systems']) require('../../src/' + name + '.js');
const C = global.ZRZCore, D = global.ZRZData;
const fixtures = [0, 28, 56, 84].map(day => {
  const s = C.initial(); s.day = day;
  const season = C.calendar(s).season;
  const rows = Object.entries(D.crops).map(([id, crop], i) => {
    s.bag[crop.seed] = i % 3;
    return {id, name: crop.name, days: crop.days, group: crop.group, seed: crop.seed,
      seasons: crop.seasons, quantity: s.bag[crop.seed], enabled: crop.seasons.includes(season)};
  });
  return {day, bag: s.bag, rows};
});
if (!process.argv[2]) throw new Error('Pass a temporary output filename.');
fs.writeFileSync(process.argv[2], JSON.stringify(fixtures, null, 2));
console.log('Exported 4 original seed-picker seasons');
