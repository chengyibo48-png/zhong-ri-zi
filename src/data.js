(function (root) {
  'use strict';
  const crops = {
    cabbage: { name: '小青菜', seed: 'cabbageSeed', days: 3, price: 22, cost: 8, group: '叶菜', seasons: [0, 1, 2, 3], color: '#71984a' },
    radish: { name: '白萝卜', seed: 'radishSeed', days: 4, price: 32, cost: 12, group: '根菜', seasons: [0, 2, 3], color: '#e4d9b5' },
    bean: { name: '毛豆', seed: 'beanSeed', days: 4, price: 30, cost: 10, group: '豆类', seasons: [0, 1], color: '#91b96a' },
    tomato: { name: '番茄', seed: 'tomatoSeed', days: 5, price: 45, cost: 16, group: '果实', seasons: [1, 2], color: '#c76847' },
    rice: { name: '稻米', seed: 'riceSeed', days: 6, price: 42, cost: 14, group: '谷物', seasons: [0, 1, 2], color: '#d3b459' },
    mustard: { name: '芥菜', seed: 'mustardSeed', days: 3, price: 26, cost: 9, group: '叶菜', seasons: [2, 3], color: '#658455' }
  };
  const items = {
    feed: { name: '草谷饲料', price: 3, cost: 4, icon: 'feed', kind: '材料' },
    wood: { name: '木料', price: 6, icon: 'wood', kind: '材料' },
    bamboo: { name: '竹材', price: 8, icon: 'bamboo', kind: '材料' },
    shoot: { name: '鲜竹笋', price: 16, icon: 'shoot', kind: '食材' },
    mushroom: { name: '菌菇', price: 18, icon: 'mushroom', kind: '食材' },
    berry: { name: '山果', price: 12, energy: 8, icon: 'berry', kind: '食材' },
    tea: { name: '山茶叶', price: 20, icon: 'tea', kind: '食材' },
    egg: { name: '鸡蛋', price: 16, icon: 'egg', kind: '食材' },
    duckEgg: { name: '鸭蛋', price: 20, icon: 'egg', kind: '食材' },
    milk: { name: '鲜牛奶', price: 26, energy: 15, icon: 'milk', kind: '食材' },
    fish: { name: '鲫鱼', price: 25, icon: 'fish', kind: '食材' },
    shrimp: { name: '河虾', price: 30, icon: 'fish', kind: '食材' },
    greens: { name: '清炒时蔬', price: 50, energy: 26, icon: 'dish', kind: '料理' },
    eggRice: { name: '蛋炒饭', price: 85, energy: 45, icon: 'riceBowl', kind: '料理' },
    bambooRice: { name: '竹笋焖饭', price: 95, energy: 48, icon: 'riceBowl', kind: '料理' },
    fishSoup: { name: '萝卜鲫鱼汤', price: 110, energy: 55, icon: 'soup', kind: '料理' },
    mushroomSoup: { name: '菌菇蛋花汤', price: 80, energy: 38, icon: 'soup', kind: '料理' },
    pickles: { name: '家常腌菜', price: 70, energy: 22, icon: 'jar', kind: '料理' }
  };
  Object.entries(crops).forEach(([id, c]) => {
    items[id] = { name: c.name, price: c.price, icon: id, kind: '食材' };
    items[c.seed] = { name: c.name + '种子', price: Math.floor(c.cost / 2), cost: c.cost, icon: 'seed', kind: '种子' };
  });
  const recipes = [
    { id: 'greens', ingredients: { cabbage: 2 }, station: '灶台', story: '阿婆教的第一道菜。留一盘送去，她会很开心。' },
    { id: 'eggRice', ingredients: { rice: 1, egg: 1 }, station: '灶台', story: '一碗热饭，也是一份田间便当。' },
    { id: 'bambooRice', ingredients: { rice: 1, shoot: 2 }, station: '灶台', story: '春笋的清甜，焖进刚出锅的米饭。' },
    { id: 'fishSoup', ingredients: { fish: 1, radish: 1 }, station: '灶台', story: '把河边的收获端上晚饭桌。' },
    { id: 'mushroomSoup', ingredients: { mushroom: 2, egg: 1 }, station: '灶台', story: '雨后的菌香，是山林的回礼。' },
    { id: 'pickles', ingredients: { mustard: 2 }, station: '腌菜坛', story: '需要修好厨房。等待一夜，就能尝到咸香。', upgrade: 'kitchen' }
  ];
  const npcs = [
    { id: 'granny', name: '林阿婆', role: '住在隔壁的老邻居', age: 68, color: '#877197', home: 'farm', likes: ['greens', 'bambooRice'], greeting: '院子里的青菜还长得好吧？你爷爷总说，地慢慢种，日子也慢慢过。', warm: '你常来坐坐，我这屋里也热闹多了。你爷爷留下的菜谱，我还记得几道，慢慢教给你。', closeNeedsBridge: true, close: '河埠边新添了长椅，以后端着饭碗也有地方坐了。你爷爷知道了，一定高兴。' },
    { id: 'qiao', name: '沈禾', role: '返乡的农技员', age: 28, color: '#557c69', home: 'bamboo', likes: ['bambooRice', 'greens'], greeting: '换着种一点豆子，地会更松软。不用着急，每块地都有自己的节奏。', close: '我想把这片小试验田留在村里。大家能用上的办法，才是好办法。' },
    { id: 'lin', name: '林溪', role: '乡村小学老师', age: 26, color: '#b98266', home: 'river', likes: ['eggRice', 'mushroomSoup'], greeting: '今天放学后，我带孩子们来认河边的植物。你也来坐坐？', warm: '孩子们知道你回来了，都想去认一认菜地里的作物。等你哪天有空，我们带着画本去。', closeNeedsBridge: true, close: '孩子们画了修好的河埠。他们说，长大以后也想给村里做点事。' },
    { id: 'chen', name: '陈木生', role: '村里的木匠', age: 45, color: '#657a98', home: 'town', likes: ['fishSoup', 'eggRice'], greeting: '河埠的木板该换了。我出手艺，大伙儿凑材料。你有空就搭把手。', warm: '上回你送来的饭，吃着格外香。河埠用的板子我已经量好了，材料齐了咱们就动手。', closeNeedsBridge: true, close: '新的木板结实。下回再下雨，老人孩子走这儿也放心。' },
    { id: 'xu', name: '许婶', role: '集镇杂货铺老板', age: 52, color: '#af765b', home: 'town', likes: ['pickles', 'greens'], greeting: '种子、米和饲料都在这儿。你家有多的收成，也可以送来代卖。', close: '大家最近总说起你的小院。好好过日子的人，走到哪儿都让人惦记。' },
    { id: 'zhou', name: '周远', role: '山间茶农', age: 30, color: '#778455', home: 'mountain', likes: ['bambooRice', 'fishSoup'], greeting: '春天采茶，秋天摘山果。走累了就歇会儿，山一直都在。', close: '明年我想试试让年轻人来学做茶。你的小院要不要也摆一张茶桌？' }
  ];
  const scenes = {
    farm: { name: '农家小院', subtitle: '一方小院，慢慢生长', icon: 'home' },
    town: { name: '隔壁集镇', subtitle: '人间烟火，都在街头', icon: 'shop' },
    bamboo: { name: '后院竹林', subtitle: '竹影摇风，拾一点时鲜', icon: 'leaf' },
    river: { name: '村口河流', subtitle: '水慢慢流，日子慢慢走', icon: 'water' },
    mountain: { name: '远处野山', subtitle: '翻过小坡，就是好风景', icon: 'mountain' }
  };
  const upgrades = {
    roof: { name: '修好老屋顶', cost: 120, materials: { wood: 6 }, description: '木生叔来换瓦。老屋添上新瓦与一盏温暖的灯。' },
    kitchen: { name: '整理厨房', cost: 160, materials: { bamboo: 6 }, description: '添一只腌菜坛，解锁家常腌菜，炊烟也热闹起来。' },
    coop: { name: '扩建棚舍', cost: 180, materials: { wood: 8 }, description: '加上草料储备。每天自动使用背包里的饲料照料动物。' }
  };
  const orders = [
    { id: 'firstDish', title: '给阿婆送一道家常菜', npc: 'granny', needs: { greens: 1 }, money: 60, reward: { beanSeed: 4 }, text: '用自己种的小青菜做一盘清炒时蔬，带给隔壁的林阿婆。没有期限。' },
    { id: 'schoolLunch', title: '孩子们的午饭', npc: 'lin', needs: { eggRice: 2 }, money: 140, reward: { riceSeed: 4 }, text: '林溪老师想给午间留校的孩子添两碗蛋炒饭。做好了随时送去。' },
    { id: 'carpenterLunch', title: '木生叔的田间便当', npc: 'chen', needs: { bambooRice: 1 }, money: 100, reward: { wood: 5 }, text: '木生叔忙着做木工，送一碗热腾腾的竹笋焖饭给他。' }
  ];
  const terms = ['立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至', '小寒', '大寒'];
  const data = { crops, items, recipes, npcs, scenes, upgrades, orders, terms, seasons: ['春', '夏', '秋', '冬'], festivals: ['春日邻里饭', '夏夜纳凉会', '秋收分享宴', '岁末团圆饭'] };
  root.ZRZData = data;
  if (typeof module !== 'undefined') module.exports = data;
})(typeof globalThis !== 'undefined' ? globalThis : window);
