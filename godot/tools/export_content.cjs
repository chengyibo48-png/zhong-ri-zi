// Rebuild Godot's data-only catalogs from the authoritative legacy modules.
const fs = require('node:fs');
const path = require('node:path');

global.window = globalThis;
const modules = [
  'data', 'content', 'landscape', 'core', 'systems', 'art', 'world', 'village',
  'farming', 'ranch', 'ranch-view', 'kitchen', 'kitchen-view', 'building', 'tools', 'economy', 'scenes',
  'environment', 'forage', 'interiors', 'fishing', 'npc-content', 'npc',
  'feedback', 'tiles', 'characters', 'item-icons', 'museum'
];
for (const name of modules) require(`../../src/${name}.js`);

function dataOnly(value, parents = new WeakSet()) {
  if (value === null || typeof value !== 'object') return typeof value === 'function' ? undefined : value;
  if (parents.has(value)) return null;
  parents.add(value);
  let result;
  if (Array.isArray(value)) {
    result = value.map(item => dataOnly(item, parents) ?? null);
  } else {
    result = {};
    for (const [key, child] of Object.entries(value)) {
      if (typeof child === 'function' || child === undefined) continue;
      const clean = dataOnly(child, parents);
      if (clean !== undefined) result[key] = clean;
    }
  }
  parents.delete(value);
  return result;
}

const outputs = {
  'content.json': global.ZRZData,
  'initial_state.json': global.ZRZCore.initial(),
  'world.json': {
    landscape: global.ZRZLandscape,
    village: {...global.ZRZVillage, regionDestinations: Object.fromEntries(Object.keys(global.ZRZVillage.offsets).map(id => [id, global.ZRZVillage.destination(global.ZRZCore.initial(), "region", id)]))},
    tiles: global.ZRZTiles
  },
  'systems.json': {
    art: {
      seasons: global.ZRZArt.seasons,
      characters: global.ZRZArt.styles
    },
    itemIcons: {
      size: global.ZRZItemIcons.size,
      categories: global.ZRZEconomy.categories,
      seedMap: global.ZRZItemIcons.seedMap,
      materials: global.ZRZItemIcons.materials,
      vegetables: global.ZRZItemIcons.vegetables,
      details: Object.fromEntries(Object.keys(global.ZRZData.items).map(id => [id, global.ZRZEconomy.details(id)]))
    },
    farming: global.ZRZFarming,
    ranch: global.ZRZRanch,
    kitchen: global.ZRZKitchen,
    building: global.ZRZBuild,
    tools: global.ZRZTools,
    economy: {
      ...global.ZRZEconomy,
      handover: global.ZRZEconomy.points(global.ZRZCore.initial())
    },
    scenes: global.ZRZScenes,
    environment: global.ZRZEnvironment,
    forage: global.ZRZForage,
    fishing: global.ZRZFishing,
    npc: global.ZRZNpc,
    feedback: global.ZRZFeedback,
    characters: global.ZRZCharacters,
    museum: global.ZRZMuseum,
    interiors: {
      ...global.ZRZInteriors,
      profiles: global.ZRZVillage.profiles
    }
  }
};
const data = global.ZRZData;
const npcScheduleState = global.ZRZCore.initial();
npcScheduleState.day = 1;
npcScheduleState.minutes = 600;
const npcWorkpoints = Object.fromEntries(data.npcs.map(person => {
  let plan = global.ZRZNpc.activity(npcScheduleState, person.id);
  if (plan.key !== 'work') {
    npcScheduleState.minutes = 930;
    plan = global.ZRZNpc.activity(npcScheduleState, person.id);
    npcScheduleState.minutes = 600;
  }
  return [person.id, { ...plan.target, label: global.ZRZNpc.profiles[person.id].work }];
}));
outputs['systems.json'].npc.workpoints = npcWorkpoints;
outputs['systems.json'].npc.historyLimit = global.ZRZNpc.historyLimit;
const inventoryOrder = Object.keys(data.items).sort((a, b) => data.items[a].name.localeCompare(data.items[b].name, 'zh-Hans'));
outputs['inventory_metadata.json'] = Object.fromEntries(inventoryOrder.map((id, rank) => [id, {rank, ...global.ZRZEconomy.details(id)}]));
outputs['atlas_catalog.json'] = require('./export_atlas_catalog.cjs')();
outputs['menu_expansion.json'] = require('./export_menu_expansion.cjs')();
for (const [filename, value] of Object.entries(outputs)) {
  const target = path.join(__dirname, '..', 'data', filename);
  const clean = dataOnly(value);
  if (filename === 'world.json' || filename === 'atlas_catalog.json') require('./export_world_precision.cjs')(clean);
  fs.writeFileSync(target, `${JSON.stringify(clean, null, 2)}\n`, 'utf8');
}
console.log(`Exported ${Object.keys(data.crops).length} crops, ${Object.keys(data.items).length} items, ${data.recipes.length} recipes, ${data.npcs.length} NPCs, and world/system catalogs.`);
