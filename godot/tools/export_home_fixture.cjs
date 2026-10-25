const fs = require('node:fs');
global.window = globalThis;
for (const name of ['data', 'content', 'landscape', 'core', 'systems']) require('../../src/' + name + '.js');
const C = global.ZRZCore, D = global.ZRZData;
const dish = D.recipes.find(r => r.source === 'known').id;
const npc = D.npcs.find(n => D.recipes.some(r => r.source === n.id)).id;
const rows = [];
for (const context of ['missing-room', 'town', 'farm', 'farm-interior', 'farm-host', 'pasture', 'pasture-interior']) {
  const s = C.initial();
  s.day = 10;
  s.scene = context === 'town' ? 'town' : 'farm';
  s.upgrades.room = context !== 'missing-room';
  s.bag[dish] = 2;
  s.relations[npc].points = 30;
  if (context === "farm-host") s.skills.cooking.choice = "host";
  const before = new Set(s.knownRecipes);
  const outcome = C.hostMeal(s, npc, dish);
  rows.push({context, dish, npc, ok: outcome.ok, quantity: s.bag[dish] || 0, points: s.relations[npc].points, xp: s.skills.social.xp, learned: s.knownRecipes.filter(id => !before.has(id))});
}
const shared = [];
for (const activity of ['meal', 'visit', 'objects', 'plan']) {
  const s = C.initial();
  s.day = 10;
  s.marriage = {spouse: 'qiao', day: 5, weekly: {}, memories: Array.from({length: 79}, () => ({day: 5, activity: 'visit'}))};
  s.relations.qiao.points = 70;
  s.bag[dish] = 2;
  const first = C.sharedLife(s, activity, dish);
  const second = C.sharedLife(s, activity, dish);
  shared.push({activity, dish, ok: first.ok, repeated: second.ok, quantity: s.bag[dish], points: s.relations.qiao.points, marriage: s.marriage, message: first.msg});
}
if (!process.argv[2]) throw new Error('Pass a temporary output path.');
fs.writeFileSync(process.argv[2], JSON.stringify({hosts: rows, shared}, null, 2));
console.log('Exported 7 browser home-meal and 4 shared-life fixtures');
