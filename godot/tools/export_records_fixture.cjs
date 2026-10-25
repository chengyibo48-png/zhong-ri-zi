// Compare native annual summaries against the authoritative browser rules.
const fs = require('node:fs');
const path = require('node:path');
global.window = globalThis;
for (const name of ['data', 'content', 'landscape', 'core', 'systems']) require('../../src/' + name + '.js');
const C = global.ZRZCore, D = global.ZRZData;
const fixtures = [];
for (let index = 0; index < 3; index++) {
  const s = C.initial();
  s.day = 112 * (index + 1);
  s.stats.harvested = [30, 4, 0][index];
  s.stats.cooked = [4, 18, 0][index];
  s.upgrades = index === 1 ? {roof: true, kitchen: true, storage: false} : {};
  s.projects = index === 1 ? {bridge: true, stage: true, tea: false} : {bridge: false};
  s.archives = index === 1 ? D.archives.map(a => a.id) : ['key'];
  if (index === 1) {
    s.marriage.spouse = D.npcs.find(n => n.tier === 'romance').id;
    D.npcs.slice(0, 4).forEach(n => s.stories[n.id].step = 1);
  }
  fixtures.push({day: s.day, stats: s.stats, upgrades: s.upgrades, projects: s.projects, archives: s.archives, stories: s.stories, marriage: s.marriage, expected: C.yearSummary(s)});
}
const destination = process.argv[2];
if (!destination) throw new Error('Pass a temporary output filename.');
fs.writeFileSync(destination, JSON.stringify(fixtures, null, 2));
console.log('Exported 3 annual-summary browser fixtures');
