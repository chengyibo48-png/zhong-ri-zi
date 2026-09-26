(function (root) {
  'use strict';
  const D = root.ZRZData || require('./data.js');
  if (typeof module !== 'undefined' && !D.expanded) require('./content.js');
  const L = root.ZRZLandscape || require('./landscape.js');
  const VERSION = 3;
  const defaultBindings = Object.freeze({ up: 'w', left: 'a', down: 's', right: 'd', interact: 'e', bag: 'b', map: 'm', journal: 'j' });
  const bindingKeyAllowed = key => typeof key === 'string' && /^[a-z]$/.test(key) && !['c','f','h','q'].includes(key);
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const ok = msg => ({ ok: true, msg });
  const fail = msg => ({ ok: false, msg });
  function calendar(s) {
    const d = s.day % 112;
    return { year: Math.floor(s.day / 112) + 1, season: Math.floor(d / 28), date: d % 28 + 1, term: D.terms[Math.floor(d * 24 / 112)] };
  }
  function weather(day) { return ['晴', '晴', '阴', '雨', '晴', '雾', '晴', '雨', '阴', '晴', '晴', '雨', '晴', '阴'][day % 14]; }
  function initial(name = '小满', gender = '不设定') {
    return { version: VERSION, name: name.trim().slice(0, 12) || '小满', gender, day: 0, minutes: 390, stamina: 100, money: 180,
      worldRevision: 2, scene: 'farm', player: { ...L.home }, seed: 'cabbage',
      bag: { cabbageSeed: 8, radishSeed: 4, rice: 4, egg: 2, feed: 9 },
      plots: Array.from({ length: 24 }, (_, i) => ({ tilled: i < 8, crop: i < 2 ? 'cabbage' : null, growth: i < 2 ? 3 : 0, watered: false, soil: 2, lastGroup: null, repeats: 0 })),
      animals: [{ id: 'hen', name: '点点', species: '鸡', personality: '爱跟着人', product: 'egg', bond: 0, fed: false, ready: 1 }, { id: 'duck', name: '小水', species: '鸭', personality: '喜欢散步', product: 'duckEgg', bond: 0, fed: false, ready: 0 }, { id: 'cow', name: '阿黄', species: '牛', personality: '慢悠悠', product: 'milk', bond: 0, fed: false, ready: 0 }],
      relations: Object.fromEntries(D.npcs.map(n => [n.id, { points: 0, talked: -1, gifted: -1, returnGift: false }])),
      flags: {}, upgrades: {}, collected: {}, processing: [], festivals: [], discovered: ['cabbageSeed', 'cabbage', 'rice', 'egg', 'feed'],
      stats: { harvested: 0, cooked: 0, fish: 0, earned: 0, gifts: 0, gathered: 0 },
      settings: { speed: 'relaxed', sound: true, volume: 0.2, zoom: 1, hints: true, bindings: { ...defaultBindings } }, journal: [{ day: 0, text: '带着爷爷的旧钥匙，回到了禾溪村。' }] };
  }
  function add(s, id, count = 1) { s.bag[id] = (s.bag[id] || 0) + count; if (count > 0 && !s.discovered.includes(id)) s.discovered.push(id); }
  function has(s, needs, n = 1) { return Object.entries(needs).every(([id, qty]) => (s.bag[id] || 0) >= qty * n); }
  function consume(s, needs, n = 1) { Object.entries(needs).forEach(([id, qty]) => { const q=s.quality?.[id]; if(q){const normal=Math.max(0,(s.bag[id]||0)-q[0]-q[1]),remaining=Math.max(0,qty*n-normal),good=Math.min(q[0],remaining);q[0]-=good;q[1]=Math.max(0,q[1]-(remaining-good));} s.bag[id] -= qty * n; if (!s.bag[id]) delete s.bag[id]; }); }
  function log(s, text) { s.journal.unshift({ day: s.day, text }); s.journal = s.journal.slice(0, 60); }
  function labor(s, cost, minutes = 8) { cost=Math.max(1,cost-(s.skills?.farming.choice==='gentle'?1:0)-(s.buffs?.laborDay===s.day?1:0)-(s._laborTool&&s.toolUpgrades?.[s._laborTool]?1:0)); if (s.stamina < cost) return false; s.stamina -= cost; s.minutes = Math.min(1320, s.minutes + minutes); return true; }
  function plotAction(s, index, tool) {
    const p = s.plots[index]; if (!p) return fail('这块地不在院子里。');
    if (tool === 'hoe') {
      if (p.tilled) return fail('已经松好土了，选种子来播种吧。');
      if (!labor(s, 3)) return fail('有点累了。吃点饭或在长椅上歇歇吧。');
      p.tilled = true; return ok('泥土松好了，等一颗种子。');
    }
    if (tool === 'seed') {
      const c = D.crops[s.seed];
      if (!p.tilled) return fail('先用锄头松一松土。');
      if (p.crop) return fail('这里已经种下作物了。');
      if (!c.seasons.includes(calendar(s).season) && !s.greenhouse) return fail(c.name + '不适合这个季节，去杂货铺看看时令种子吧。');
      if (!(s.bag[c.seed] > 0)) return fail(c.name + '种子用完了，可以到集镇买一些。');
      if (!labor(s, 2)) return fail('先歇歇或吃点东西吧。');
      consume(s, { [c.seed]: 1 }); p.crop = s.seed; p.growth = 0; p.watered = weather(s.day) === '雨';
      p.soil = c.group === '豆类' ? Math.min(2, p.soil + 1) : p.soil;
      return ok('种下' + c.name + '，照料 ' + c.days + ' 天就能收获。');
    }
    if (tool === 'water') {
      if (!p.tilled) return fail('这块地还没有开垦。');
      if (p.watered) return fail('土还是湿润的，今天不用再浇啦。');
      if (!labor(s, 2, 5)) return fail('先在长椅上歇歇吧。');
      p.watered = true; return ok('水浸进土里了。今天的照料完成。');
    }
    if (p.crop && p.growth >= D.crops[p.crop].days) {
      if (!labor(s, 2)) return fail('先补充一点体力吧。');
      const c = D.crops[p.crop], qty = p.soil === 2 ? 2 : 1;
      add(s, p.crop, qty); s.stats.harvested += qty; s.flags.firstHarvest = true;
      p.repeats = p.lastGroup === c.group ? p.repeats + 1 : 1;
      p.soil = c.group === '豆类' ? 2 : p.repeats >= 2 ? Math.max(0, p.soil - 1) : p.soil;
      p.lastGroup = c.group; p.crop = null; p.growth = 0;
      return ok('收获' + c.name + ' ×' + qty + (qty === 2 ? ' · 肥沃的土壤带来了好收成！' : '。轮作豆类能养护土壤。'));
    }
    if (p.crop) return fail(D.crops[p.crop].name + '还需要 ' + Math.ceil(D.crops[p.crop].days - p.growth) + ' 天。' + (p.watered ? '今天已经浇过水。' : '记得给它浇点水。'));
    return fail(p.tilled ? '空着的菜地。按 2 选择种子。' : '还没开垦的小块土地，按 1 选择锄头。');
  }
  function buy(s, id, qty = 1) {
    const item = D.items[id], cost = item && (item.cost || (id === 'rice' ? 24 : null));
    if (!cost || !Number.isInteger(qty) || qty < 1 || qty > 99) return fail('无法购买这件物品。');
    if (s.money < cost * qty) return fail('零钱不太够，可以卖一些收成或去竹林采集。');
    s.money -= cost * qty; add(s, id, qty); return ok('买到了' + item.name + ' ×' + qty + '。');
  }
  function sell(s, id, qty = 1) {
    if (!D.items[id] || !Number.isInteger(qty) || qty < 1 || !has(s, { [id]: qty })) return fail('背包里没有这么多。');
    const money = D.items[id].price * qty; consume(s, { [id]: qty }); s.money += money; s.stats.earned += money; s.flags.firstSale = true;
    return ok('售出' + D.items[id].name + ' ×' + qty + '，收到 ' + money + ' 元。');
  }
  function cook(s, id, qty = 1) {
    const r = D.recipes.find(r => r.id === id);
    if (!r || !Number.isInteger(qty) || qty < 1 || qty > 20) return fail('没有这份菜谱。');
    if (r.upgrade && !s.upgrades[r.upgrade]) return fail('先整理厨房，添置腌菜坛。');
    if (!has(s, r.ingredients, qty)) return fail('食材还不够，菜谱上标出了缺少的食材。');
    consume(s, r.ingredients, qty);
    if (id === 'pickles') { s.processing.push({ id, qty, readyDay: s.day + 1 }); return ok('腌菜已经入坛，明天就能尝到。'); }
    add(s, id, qty); s.stats.cooked += qty; s.flags.firstCook = true; log(s, '做了' + D.items[id].name + '。');
    return ok(D.items[id].name + '做好了 ×' + qty + '，去送给邻居，或留给自己。');
  }
  function eat(s, id) {
    const item = D.items[id]; if (!item || !item.energy || !has(s, { [id]: 1 })) return fail('这件物品不能直接食用。');
    if (s.stamina >= 100) return fail('现在精神很好，留着待会儿吃吧。');
    consume(s, { [id]: 1 }); s.stamina = Math.min(100, s.stamina + item.energy); return ok('吃了' + item.name + '，体力恢复 ' + item.energy + ' 点。');
  }
  function talk(s, id) {
    const n = D.npcs.find(n => n.id === id); if (!n) return fail('这位邻居还没来。');
    const r = s.relations[id];
    if (r.talked !== s.day) { r.points = Math.min(100, r.points + 5); r.talked = s.day; }
    let text = r.points >= 30 ? (!n.closeNeedsBridge || s.flags.bridge ? n.close : n.warm) : n.greeting;
    if (r.points >= 25 && !r.returnGift) { r.returnGift = true; add(s, 'rice', 2); text += ' 对了，这袋新米带回去。别光顾着忙，记得吃饭。〔收到稻米 ×2〕'; log(s, n.name + '送来了新米。'); }
    return ok(text);
  }
  function gift(s, npcId, id) {
    const n = D.npcs.find(n => n.id === npcId); if (!n || !D.items[id] || !has(s, { [id]: 1 })) return fail('背包里没有这份礼物。');
    const r = s.relations[npcId]; if (r.gifted === s.day) return fail('今天的心意已经收到啦，留一点给自己吧。');
    consume(s, { [id]: 1 }); const gain = n.likes.includes(id) ? 15 : D.items[id].kind === '料理' ? 10 : 5;
    r.points = Math.min(100, r.points + gain); r.gifted = s.day; s.stats.gifts++; log(s, '把' + D.items[id].name + '送给了' + n.name + '。');
    return ok(n.likes.includes(id) ? '“正是我喜欢的味道，谢谢你想着我。” 关系 +' + gain : '“谢谢你，改天来家里吃饭。” 关系 +' + gain);
  }
  function deliver(s, id) {
    const o = D.orders.find(o => o.id === id); if (!o || s.flags[id]) return fail('这份心意已经送到了。');
    if (!has(s, o.needs)) return fail('料理还没有备齐，慢慢来，没有期限。');
    consume(s, o.needs); Object.entries(o.reward).forEach(([k, v]) => add(s, k, v)); s.money += o.money; s.stats.earned += o.money;
    s.flags[id] = true; s.relations[o.npc].points = Math.min(100, s.relations[o.npc].points + 20); log(s, '完成邻里心愿：' + o.title + '。');
    return ok('心意送到了！收到 ' + o.money + ' 元和一份回礼，邻里关系 +20。');
  }
  function tend(s, id) {
    const a = s.animals.find(a => a.id === id); if (!a) return fail('没有这只动物。');
    if (a.ready > 0) { const qty = a.ready; add(s, a.product, qty); a.ready = 0; return ok('收到了' + a.name + '的' + D.items[a.product].name + ' ×' + qty + '。'); }
    if (a.fed) return fail(a.name + '今天吃饱了，正在悠闲地散步。');
    if (!has(s, { feed: 1 })) return fail('饲料用完了，到杂货铺买一些吧。');
    if (!labor(s, 2, 5)) return fail('先歇歇再来陪它吧。');
    consume(s, { feed: 1 }); a.fed = true; a.bond = Math.min(100, a.bond + 5); return ok('摸摸' + a.name + '，添好了饲料。明天会有新鲜产物。');
  }
  function gather(s, nodeId, id) {
    if (!['wood', 'bamboo', 'shoot', 'mushroom', 'berry', 'tea'].includes(id)) return fail('这里没有可采集的东西。');
    if (s.collected[nodeId] === s.day) return fail('今天已经采过了，给这里留一点生长的时间吧。');
    if (!labor(s, 3, 10)) return fail('有点累了，先找个地方歇歇。');
    s.collected[nodeId] = s.day; add(s, id, 2); s.stats.gathered += 2; return ok('采到了' + D.items[id].name + ' ×2。这里明天会恢复。');
  }
  function fish(s) {
    if (!labor(s, 6, 25)) return fail('先吃点东西，钓鱼也需要力气。');
    const id = (s.stats.fish + s.day) % 3 === 2 ? 'shrimp' : 'fish'; add(s, id); s.stats.fish++;
    return ok('水面轻轻一动……钓到了' + D.items[id].name + '！');
  }
  function upgrade(s, id) {
    const u = D.upgrades[id]; if (!u || s.upgrades[id]) return fail('这里已经修好了。');
    if (s.money < u.cost || !has(s, u.materials)) return fail('材料或零钱还没备齐。竹林和野山都有可用的材料。');
    s.money -= u.cost; consume(s, u.materials); s.upgrades[id] = true; log(s, '和邻居一起' + u.name + '。'); return ok(u.name + '完成了！院子有了新的变化。');
  }
  function repair(s) {
    if (s.flags.bridge) return fail('河埠已经修好了，去河边坐坐吧。');
    if (!s.flags.firstDish) return fail('先给林阿婆送一道家常菜。她会把你介绍给一起修河埠的乡亲。');
    if (!has(s, { wood: 8, bamboo: 6 })) return fail('还需要木料 ×8、竹材 ×6。木生叔负责手艺，乡亲们负责其他材料。');
    consume(s, { wood: 8, bamboo: 6 }); s.flags.bridge = true; s.relations.chen.points = Math.min(100, s.relations.chen.points + 20);
    log(s, '大家修好了河埠，岸边添了长椅和一张小茶桌。'); return ok('河埠修好了！木生叔换好木板，阿婆搬来长椅。去村口河流看看吧。');
  }
  function festival(s, id) {
    const c = calendar(s), key = c.year + '-' + c.season;
    if (c.date < 14) return fail('聚会在本季第 14 天开席。晚点来也没关系，邻里会为你留一桌。');
    if (s.festivals.includes(key)) return fail('这一季的饭桌已经留下了你的故事。下一季再聚。');
    if (!D.items[id] || D.items[id].kind !== '料理' || !has(s, { [id]: 1 })) return fail('带一道亲手做的料理来吧。');
    consume(s, { [id]: 1 }); s.festivals.push(key); Object.values(s.relations).forEach(r => r.points = Math.min(100, r.points + 10)); add(s, 'rice', 3);
    log(s, '参加了' + D.festivals[c.season] + '，把一年的味道留在饭桌上。'); return ok('一张桌，几家人，菜香里都是家常。大家的关系 +10，收到新米 ×3。');
  }
  function rest(s) { s.stamina = Math.min(100, s.stamina + 25); s.minutes = Math.min(1320, s.minutes + 45); return ok('坐了一会儿，听见风穿过树叶。体力恢复 25 点。'); }
  function nextDay(s) {
    const todayRain = weather(s.day) === '雨';
    s.plots.forEach(p => { if (p.crop) p.growth = Math.min(D.crops[p.crop].days, p.growth + (p.watered || todayRain ? 1 : 0.35)); else p.soil = Math.min(2, p.soil + 0.25); p.watered = weather(s.day + 1) === '雨'; });
    s.animals.forEach(a => { if (!a.fed && s.upgrades.coop && has(s, { feed: 1 })) { consume(s, { feed: 1 }); a.fed = true; } if (a.fed) a.ready = Math.min(7, a.ready + 1); a.fed = false; });
    s.day++; s.minutes = 390; s.stamina = 100; s.scene = 'farm'; s.player = { ...L.home };
    s.processing = s.processing.filter(p => { if (p.readyDay <= s.day) { add(s, p.id, p.qty); s.stats.cooked += p.qty; log(s, D.items[p.id].name + '腌好了。'); return false; } return true; });
    if (s.day % 112 === 0) { s.flags.yearReview = true; log(s, '走过四季，日子有了自己的模样。新的一年，继续慢慢过。'); }
    return ok('早安，' + s.name + '。今天' + weather(s.day) + '，又是新的一天。');
  }
  function npcScene(s, n) { return weather(s.day) === '雨' || s.minutes >= 1080 ? (n.id === 'granny' ? 'farm' : 'town') : n.home; }
  function stage(points) { return points >= 70 ? '信任' : points >= 30 ? '亲近' : points >= 10 ? '熟悉' : '初识'; }
  function load(raw) {
    let v; try { v = typeof raw === 'string' ? JSON.parse(raw) : structuredClone(raw); } catch (_) { throw new Error('存档无法解析，请使用备份。'); }
    if (!v || ![1, 2, 3].includes(v.version)) throw new Error('存档版本不兼容。');
    const finite = (n, min, max) => Number.isFinite(n) && n >= min && n <= max;
    if (!Number.isInteger(v.day) || !finite(v.day, 0, 100000) || !finite(v.money, 0, 1e9) || !finite(v.stamina, 0, 100) || !finite(v.minutes, 360, 1320) || !D.scenes[v.scene] || !Array.isArray(v.plots) || ![24,72].includes(v.plots.length) || !v.bag || typeof v.bag !== 'object') throw new Error('存档的日期、背包或农地数据不完整。');
    const s = initial(typeof v.name === 'string' ? v.name : '小满');
    s.day = v.day; s.money = v.money; s.stamina = v.stamina; s.minutes = v.minutes; s.scene = v.scene;
    s.gender = ['不设定', '女', '男'].includes(v.gender) ? v.gender : '不设定';
    s.bag = {}; for (const [id, qty] of Object.entries(v.bag)) { if (!D.items[id] || !Number.isInteger(qty) || !finite(qty, 0, 999999)) throw new Error('背包物品数据无效。'); if (qty > 0) s.bag[id] = qty; }
    s.plots = v.plots.map(p => { if (!p || (p.crop !== null && !D.crops[p.crop]) || !finite(p.growth, 0, 12) || !finite(p.soil, 0, 2)) throw new Error('农地数据无效。'); return { tilled: !!p.tilled, crop: p.crop, growth: p.growth, soil: p.soil, watered: !!p.watered, lastGroup: ['叶菜', '根菜', '豆类', '谷物', '果实'].includes(p.lastGroup) ? p.lastGroup : null, repeats: clamp(Number(p.repeats) || 0, 0, 1000) }; });
    if(v.worldRevision!==undefined&&![2,3].includes(v.worldRevision))throw new Error('地图版本不兼容。');
    const expanded=v.worldRevision>=2,continuous=v.worldRevision===3;
    if(v.player&&finite(v.player.x,expanded?24:16,continuous?5736:expanded?1896:944)&&finite(v.player.y,expanded?38:48,continuous?2280:expanded?1128:556))s.player={x:v.player.x+(expanded?0:480),y:v.player.y+(expanded?0:288),direction:['up','down','left','right'].includes(v.player.direction)?v.player.direction:'down'};
    s.worldRevision=2;
    if (D.crops[v.seed]) s.seed = v.seed;
    for (const a of s.animals) { const prev = Array.isArray(v.animals) && v.animals.find(x => x.id === a.id); if (prev) { a.bond = clamp(Number(prev.bond) || 0, 0, 100); a.fed = !!prev.fed; a.ready = clamp(Math.floor(Number(prev.ready) || 0), 0, 7); if(typeof prev.name==='string')a.name=prev.name.slice(0,12)||a.name; } }
    for (const [id, r] of Object.entries(s.relations)) { const prev = v.relations && v.relations[id]; if (prev) { r.points = clamp(Number(prev.points) || 0, 0, 100); for (const k of ['talked', 'gifted']) r[k] = Number.isInteger(prev[k]) ? Math.min(prev[k], s.day) : -1; r.returnGift = !!prev.returnGift; } }
    for (const k of ['firstHarvest', 'firstSale', 'firstCook', 'firstDish', 'schoolLunch', 'carpenterLunch', 'bridge', 'yearReview', 'introDone']) if (v.flags && v.flags[k]) s.flags[k] = true;
    for (const k of Object.keys(D.upgrades)) if (v.upgrades && v.upgrades[k]) s.upgrades[k] = true;
    for (const k of Object.keys(s.stats)) s.stats[k] = clamp(Number(v.stats && v.stats[k]) || 0, 0, 1e9);
    s.collected = {}; if (v.collected && typeof v.collected === 'object') for (const [k, day] of Object.entries(v.collected)) if ((/^(bamboo|mountain)-\d+$/.test(k)||Object.values(L.maps).some(m=>m.landmarks.some(p=>p.kind==='gather'&&p.id===k))) && Number.isInteger(day) && day <= s.day) s.collected[k] = day;
    s.discovered = Array.isArray(v.discovered) ? [...new Set(v.discovered.filter(id => !!D.items[id]))] : Object.keys(s.bag);
    s.processing = Array.isArray(v.processing) ? v.processing.filter(p => p && p.id === 'pickles' && Number.isInteger(p.qty) && p.qty > 0 && p.qty <= 20 && Number.isInteger(p.readyDay) && p.readyDay >= s.day && p.readyDay <= s.day + 1).map(p => ({ id: p.id, qty: p.qty, readyDay: p.readyDay })) : [];
    s.festivals = Array.isArray(v.festivals) ? [...new Set(v.festivals.filter(k => typeof k === 'string' && /^\d+-[0-3]$/.test(k)))].slice(0, 4000) : [];
    s.journal = Array.isArray(v.journal) ? v.journal.filter(e => e && Number.isInteger(e.day) && typeof e.text === 'string').slice(0, 60).map(e => ({ day: e.day, text: e.text.slice(0, 200) })) : s.journal;
    if (v.settings) {
      s.settings = { ...s.settings, speed: v.settings.speed === 'normal' ? 'normal' : 'relaxed', sound: v.settings.sound !== false, volume: finite(v.settings.volume, 0, 1) ? v.settings.volume : .2, zoom: [1, 1.2, 1.4].includes(v.settings.zoom) ? v.settings.zoom : 1, hints: v.settings.hints !== false };
      const candidate = Object.fromEntries(Object.keys(defaultBindings).map(k => [k, v.settings.bindings?.[k]]));
      if (Object.values(candidate).every(bindingKeyAllowed) && new Set(Object.values(candidate)).size === 8) s.settings.bindings = candidate;
    }
    return s;
  }
  const api = { VERSION, defaultBindings, bindingKeyAllowed, initial, calendar, weather, add, has, consume, log, labor, plotAction, buy, sell, cook, eat, talk, gift, deliver, tend, gather, fish, upgrade, repair, festival, rest, nextDay, npcScene, stage, load };
  root.ZRZCore = api; if (typeof module !== 'undefined') { module.exports = api; require('./systems.js'); }
})(typeof globalThis !== 'undefined' ? globalThis : window);
