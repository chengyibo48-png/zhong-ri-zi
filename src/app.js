(function () {
  'use strict';
  const D = window.ZRZData, C = window.ZRZCore, W = window.ZRZWorld, X = window.ZRZPanels;
  const $ = id => document.getElementById(id);
  const escape = v => String(v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const icons = {
    menu: '<path d="M4 5h16M4 12h16M4 19h16"/>',
    expand: '<path d="M3 9V3h6M15 3h6v6M21 15v6h-6M9 21H3v-6"/>',
    eye: '<path d="M1 12S5 5 12 5s11 7 11 7-4 7-11 7S1 12 1 12Z"/><circle cx="12" cy="12" r="3"/>',
    sprout: '<path d="M12 21V11M12 14C3 15 2 7 3 5c6-1 10 3 9 9ZM12 10c0-6 4-9 9-9 1 7-2 10-9 10M4 22h16"/>',
    home: '<path d="m3 11 9-8 9 8M5 10v11h14V10M9 21v-7h6v7M2 11h20"/>',
    shop: '<path d="M4 10v11h16V10M3 4h18l1 6c-1 3-4 3-5 0-1 3-4 3-5 0-1 3-4 3-5 0-1 3-4 3-5 0ZM9 21v-6h6v6M6 4l-1 6M10 4v6M14 4v6M18 4l1 6"/>',
    leaf: '<path d="M5 19C0 6 10 3 21 3c0 13-5 19-15 15M3 22 16 9M8 17l-1-5M12 13l5 1"/>',
    water: '<path d="M2 8c4-4 6 4 10 0s6 4 10 0M2 14c4-4 6 4 10 0s6 4 10 0M2 20c4-4 6 4 10 0s6 4 10 0M12 2v2"/>',
    mountain: '<path d="m1 21 8-16 6 11 3-7 5 12ZM6 11l3 2 2-3M14 21l-3-6"/>',
    save: '<path d="M4 3h13l4 4v14H3V3ZM7 3v7h10V3M7 21v-7h10v7M14 5v3"/>',
    sound: '<path d="m3 9 4 0 5-5v16l-5-5H3ZM16 7a7 7 0 0 1 0 10M19 4a11 11 0 0 1 0 16"/>',
    mute: '<path d="m3 9 4 0 5-5v16l-5-5H3ZM16 9l6 6M22 9l-6 6"/>',
    settings: '<path d="m10 2-1 3-3 1-3-1-2 4 3 2v3l-2 2 2 4 3-1 3 1 1 3h4l1-3 3-1 2-4-2-2v-3l2-2-2-4-3 1-3-1-1-3Z"/><circle cx="12" cy="12" r="3"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 2v6M17 2v6M3 11h18M7 15h2M12 15h2M7 18h2M16 15h2"/>',
    note: '<path d="M5 3h14v18H5ZM8 7h8M8 11h8M8 15h5M2 6h4M2 11h4M2 16h4"/>',
    bag: '<path d="M6 7h12l3 14H3ZM8 7V5a4 4 0 0 1 8 0v2M7 12h10v6H7Z"/>',
    bowl: '<path d="M2 12h20c-1 6-4 9-10 9S3 18 2 12ZM7 8c-3-3 2-3 0-6M13 8c-3-3 2-3 0-6M19 8c-3-3 2-3 0-6M6 22h12"/>',
    people: '<circle cx="9" cy="7" r="4"/><path d="M1 21v-3a8 8 0 0 1 16 0v3M17 3a4 4 0 0 1 0 8M19 14a6 6 0 0 1 4 7"/>',
    book: '<path d="M12 5C8 2 4 3 2 4v16c4-2 7-2 10 0 3-2 6-2 10 0V4c-4-2-7-2-10 1v15M5 8h4M15 8h4M5 12h4M15 12h4"/>',
    hammer: '<path d="m4 21 10-12-3-3-3 1 1-4 7-1 6 6-3 3-3-2L7 22ZM9 14l4 3"/>',
    help: '<circle cx="12" cy="12" r="10"/><path d="M9 8c0-4 8-4 7 1 0 2-4 2-4 5M12 18v.1"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 1v3M12 20v3M1 12h3M20 12h3M4 4l2 2M18 18l2 2M4 20l2-2M18 6l2-2"/>',
    rain: '<path d="M5 14a5 5 0 0 1 0-10 7 7 0 0 1 13 2 4 4 0 0 1 0 8ZM7 18l-1 3M13 18l-1 3M19 18l-1 3"/>',
    cloud: '<path d="M5 17a5 5 0 0 1 0-10 7 7 0 0 1 13 2 4 4 0 0 1 0 8Z"/>',
    coin: '<circle cx="12" cy="12" r="9"/><path d="M9 9h6v6H9Z"/>'
  };
  const svg = id => '<svg viewBox="0 0 24 24" aria-hidden="true">' + (icons[id] || icons.leaf) + '</svg>';
  document.querySelectorAll('[data-icon]').forEach(el => el.innerHTML = svg(el.dataset.icon));
  const SAVE = 'zhong-ri-zi-v2';
  let storageAvailable = true, startupNotice = '', s;
  const diagnostics={saves:0,lastSaveMs:0,maxSaveMs:0,errors:[],sceneChanges:0,frames:0};
  function readSave(key) { try { return localStorage.getItem(key); } catch (_) { storageAvailable = false; return null; } }
  const raw = readSave(SAVE + '-auto');
  if (raw) { try { s = C.load(raw); } catch (_) { try { s = C.load(readSave(SAVE + '-backup')); startupNotice = '自动存档损坏，已恢复上一份备份。'; } catch (_) { startupNotice = '自动档和备份无法读取。原文件保留，请在存档面板导入可用备份。'; } } }
  s ||= C.initial();
  let tool = 'hand', hovered = null, path = [], pending = null, effect = null, currentPanel = null, panelArg = null, lastFocus = null, walking = false, tick = 0, lastTime = 0, frameTime = 0, inputLocked = false;
  let fishTimer = null, soundContext = null, melodyAt = 0, inventoryFilter = '全部', calSeason = C.calendar(s).season;
  const keys = new Set();
  const camera = new window.ZRZCamera.Camera($('world'));
  let pointer = null, arrivalTimer = null, capturing = null, hudVisible = true, questExpanded = true;
  const bindingNames = { up:'向上移动', left:'向左移动', down:'向下移动', right:'向右移动', interact:'场景交互', bag:'打开背包', map:'村庄地图', journal:'生活手记' };
  const keyLabel = action => s.settings.bindings[action].toUpperCase();
  const bookPages = [['menu','总览','home'],['bag','背包','bag'],['map','地图','mountain'],['calendar','日历','calendar'],['orders','心愿','note'],['recipes','菜谱','bowl'],['relations','邻里','people'],['journal','手记','book'],['build','修缮','hammer'],['stories','故事','book'],['home','家','home'],['settings','设置','settings']];
  const tools = [{ id: 'hoe', name: '锄头', key: 1, desc: '松土' }, { id: 'seed', name: '种子', key: 2, desc: '播种' }, { id: 'water', name: '水壶', key: 3, desc: '浇水' }, { id: 'hand', name: '双手', key: 4, desc: '收获 / 交互' }, { id: 'rod', name: '鱼竿', key: 5, desc: '河边钓鱼' },{id:'axe',name:'斧头',key:6,desc:'整理木料'},{id:'sickle',name:'采集镰刀',key:7,desc:'采集时鲜'},{id:'build',name:'布置工具',key:8,desc:'布置庭院'}];
  function sound(type = 'action') {
    if (!s.settings.sound) return;
    try {
      soundContext ||= new (window.AudioContext || window.webkitAudioContext)();
      if (soundContext.state === 'suspended') soundContext.resume();
      if(s.settings.effects<=0||s.settings.volume<=0)return;
      const now = soundContext.currentTime, osc = soundContext.createOscillator(), gain = soundContext.createGain();
      osc.type = 'sine';osc.frequency.setValueAtTime(type === 'good' ? 660 : type === 'soft' ? 392 : 510, now);osc.frequency.exponentialRampToValueAtTime(type === 'good' ? 880 : 350, now + .12);
      gain.gain.setValueAtTime(0, now);gain.gain.linearRampToValueAtTime(s.settings.volume * s.settings.effects * .22, now + .02);gain.gain.exponentialRampToValueAtTime(.0001, now + .3);osc.connect(gain);gain.connect(soundContext.destination);osc.start(now);osc.stop(now + .32);
    } catch (_) { /* Sound is optional and never blocks play. */ }
  }
  function ambient(t) {
    if (!soundContext || !s.settings.sound || document.hidden || currentPanel || t < melodyAt) return;
    melodyAt = t + 8;
    const frequencies = [[261.63,293.66,329.63,392,440],[293.66,329.63,392,440,523.25],[220,261.63,293.66,329.63,392],[196,220,261.63,293.66,329.63]][C.calendar(s).season], now = soundContext.currentTime;
    if(s.settings.music>0&&s.settings.volume>0)[0, 1, 2].forEach((j) => { const osc = soundContext.createOscillator(), gain = soundContext.createGain();osc.type = 'sine';osc.frequency.value = frequencies[(Math.floor(t / 8) + j * 2) % 5];gain.gain.setValueAtTime(.0001, now + j * .65);gain.gain.exponentialRampToValueAtTime(Math.max(.0002, s.settings.volume * s.settings.music * .09), now + j * .65 + .04);gain.gain.exponentialRampToValueAtTime(.0001, now + j * .65 + 1.5);osc.connect(gain);gain.connect(soundContext.destination);osc.start(now + j * .65);osc.stop(now + j * .65 + 1.6); });
    if(s.settings.ambient>0){
      const wet=['雨','台风'].includes(C.weather(s.day))||s.scene==='river',night=s.minutes>1140;
      const len=soundContext.sampleRate*2,buffer=soundContext.createBuffer(1,len,soundContext.sampleRate),samples=buffer.getChannelData(0);
      for(let i=0;i<len;i++)samples[i]=(Math.random()*2-1)*.2;
      const source=soundContext.createBufferSource(),filter=soundContext.createBiquadFilter(),gain=soundContext.createGain();source.buffer=buffer;filter.type='lowpass';filter.frequency.value=wet?650:300;gain.gain.setValueAtTime(.0001,now);gain.gain.linearRampToValueAtTime(s.settings.volume*s.settings.ambient*(wet?.32:.15),now+.4);gain.gain.exponentialRampToValueAtTime(.0001,now+2);source.connect(filter);filter.connect(gain);gain.connect(soundContext.destination);source.start(now);source.stop(now+2);
      if(!wet){const bird=soundContext.createOscillator(),g=soundContext.createGain();bird.frequency.setValueAtTime(night?650:s.scene==='town'?250:1150,now+.3);bird.frequency.exponentialRampToValueAtTime(night?720:s.scene==='town'?320:1450,now+.5);g.gain.setValueAtTime(.0001,now);g.gain.linearRampToValueAtTime(s.settings.volume*s.settings.ambient*.035,now+.35);g.gain.exponentialRampToValueAtTime(.0001,now+.8);bird.connect(g);g.connect(soundContext.destination);bird.start(now+.3);bird.stop(now+.82);}
    }
  }
  function save(slot = 'auto', silent = true) {
    const started=performance.now();
    try {
      const valid = C.load(s), key = SAVE + '-' + slot;
      if (slot === 'auto') { const previous = localStorage.getItem(key); if (previous) { try { C.load(previous); localStorage.setItem(SAVE + '-backup', previous); } catch (_) {} } }
      localStorage.setItem(key, JSON.stringify(valid));diagnostics.saves++;diagnostics.lastSaveMs=performance.now()-started;diagnostics.maxSaveMs=Math.max(diagnostics.maxSaveMs,diagnostics.lastSaveMs);storageAvailable = true;$('save-status').textContent = slot === 'auto' ? '已自动保存 · 安心生活' : '已保存到手动档 ' + slot;
      if (!silent) toast('已经好好记下今天的日子。'); return true;
    } catch (error) { diagnostics.errors.push({kind:'save',message:String(error.message).slice(0,160)});diagnostics.errors=diagnostics.errors.slice(-30);storageAvailable = false;$('save-status').textContent = '本地保存不可用 · 请导出存档';if (!silent) toast('浏览器无法保存，请点“导出存档”保留进度。', true);return false; }
  }
  function toast(msg, error = false) {
    if (currentPanel) { const existing = $('modal-body').querySelector('.modal-toast');if (existing) existing.remove();const el = document.createElement('div');el.className = 'modal-toast' + (error ? ' error' : '');el.setAttribute('role','status');el.textContent = msg;const title = $('modal-body').querySelector('.subtitle');if (title) title.after(el);else $('modal-body').prepend(el); }
    else { const el = document.createElement('div');el.className = 'toast' + (error ? ' error' : '');el.textContent = msg;$('toasts').appendChild(el);while ($('toasts').children.length > 3) $('toasts').firstChild.remove();setTimeout(() => el.remove(), 4500); }
  }
  function apply(result, refresh = false) { if (result.ok) { sound('good');if(s.settings.vibration){try{const pad=[...(navigator.getGamepads?.()||[])].find(Boolean);pad?.vibrationActuator?.playEffect('dual-rumble',{duration:60,weakMagnitude:.12,strongMagnitude:0})?.catch(()=>{});}catch(_){}}save();update();if (refresh && currentPanel) renderPanel(currentPanel,panelArg); } toast(result.msg,!result.ok);return result.ok; }
  function update() {
    $('game-root').style.setProperty('--reading-scale',s.settings.textScale);$('game-root').classList.toggle('high-contrast',s.settings.contrast);
    const c = C.calendar(s), hr = Math.floor(s.minutes / 60), minute = Math.floor(s.minutes % 60 / 10) * 10;
    $('year-label').textContent = '在禾溪的第 ' + c.year + ' 年';
    $('season-date').innerHTML = D.seasons[c.season] + ' <b>' + String(c.date).padStart(2,'0') + '</b><small>日</small>';
    $('solar-term').textContent = c.term;$('weather-today').innerHTML = svg(C.weather(s.day)==='晴'?'sun':C.weather(s.day)==='雨'?'rain':'cloud') + C.weather(s.day);
    $('clock-label').textContent = String(hr).padStart(2,'0')+':'+String(minute).padStart(2,'0')+' · '+(hr<8?'清晨':hr<12?'上午':hr<17?'午后':hr<20?'傍晚':'夜间');
    $('forecast').textContent = '明日 '+C.weather(s.day+1)+' · '+C.weatherAdvice(s.day+1);
    $('player-name').textContent = s.name;$('money').innerHTML = svg('coin') + s.money;$('energy-text').textContent = Math.floor(s.stamina)+' / 100';$('energy-fill').style.width = s.stamina+'%';
    $('scene-title').innerHTML = D.scenes[s.scene].name+' <span>'+D.scenes[s.scene].subtitle+'</span>';$('location-pill').textContent='禾溪村 · '+D.scenes[s.scene].name;
    $('sound-btn').innerHTML=svg(s.settings.sound?'sound':'mute');$('sound-btn').setAttribute('aria-pressed',String(s.settings.sound));
    if($('toolbelt').dataset.active!==tool){$('toolbelt').innerHTML=tools.map(t=>'<button class="tool '+(t.id===tool?'active':'')+'" title="'+t.name+' · '+t.key+' · '+t.desc+'" aria-label="'+t.name+'" aria-pressed="'+(t.id===tool)+'" data-action="tool" data-id="'+t.id+'"><span>'+t.key+'</span><canvas width="32" height="32" data-item="'+t.id+'"></canvas></button>').join('');$('toolbelt').dataset.active=tool;}
    const selected=tools.find(t=>t.id===tool);$('tool-name').textContent=selected.name+' · '+selected.desc;
    $('seed-label').innerHTML=D.crops[s.seed].name+'种子 <small>剩余 '+(s.bag[D.crops[s.seed].seed]||0)+' 份 · 点击更换</small>';
    $('bag-count').textContent=Object.values(s.bag).reduce((a,b)=>a+b,0)+' 件物品';
    $('time-pill').textContent=currentPanel?'翻阅手记中 · 时间暂停':s.settings.speed==='relaxed'?'舒缓时光 · 慢慢来':'常规时光 · 好好生活';
    const phases=[s.flags.firstHarvest,s.flags.firstCook,s.flags.firstDish,s.flags.bridge];const stage=phases.findIndex(x=>!x);
    const objectives=[['收下第一份青菜','菜地左上角有阿婆照料好的青菜。选双手，点击收获。'],['为邻居做一道菜','走到小厨房，用 2 份小青菜做一盘清炒时蔬。'],['给阿婆送一份心意','翻开邻里手记，把清炒时蔬送给阿婆，开始认识邻居。'],['一起修好河埠','去竹林采集木料 ×8、竹材 ×6，再到河边一起动工。'],['小小的村庄，有了变化','去修好的河埠坐坐吧。继续种菜、拜访，或为聚会做道菜。']];
    const o=stage<0?['这一年，继续慢慢过',D.weekHints[Math.floor(s.day%112/7)]+'。生活簿里有新的故事与安排。']:objectives[stage];$('objective').innerHTML='<h3>'+o[0]+'</h3><p>'+o[1]+'</p><div class="progress-line">'+phases.map(f=>'<span class="'+(f?'done':'')+'"></span>').join('')+'</div>';
    $('wish-card').hidden=!s.settings.hints;$('controls-hint').hidden=!s.settings.hints;
    $('controls-hint').innerHTML='<kbd>'+['up','left','down','right'].map(keyLabel).join(' ')+'</kbd> 移动 <i></i><kbd>'+keyLabel('interact')+'</kbd> 交互 <i></i><kbd>1–8</kbd> 工具 <i></i><kbd>Tab</kbd> 菜单';
    document.querySelector('.bag-button kbd').textContent=keyLabel('bag');
    document.querySelector('.energy-track').classList.toggle('low',s.stamina<25);
    $('fullscreen-btn').setAttribute('aria-label',document.fullscreenElement?'退出全屏':'进入全屏');
    $('fullscreen-btn').setAttribute('aria-pressed',String(!!document.fullscreenElement));
    const pctx=$('portrait').getContext('2d');pctx.clearRect(0,0,32,36);W.character(pctx,16,34,['#829773','#768fa7','#ad8070','#b4a579'][s.appearance.shirt],0,false,s.appearance.hat,'down',s.appearance);
    const seedCtx=$('seed-icon').getContext('2d');seedCtx.clearRect(0,0,24,24);W.item(seedCtx,s.seed,0,0,.75);
    drawIcons();
  }
  function drawIcons(){document.querySelectorAll('canvas[data-item]').forEach(el=>{const c=el.getContext('2d');c.clearRect(0,0,el.width,el.height);W.item(c,el.dataset.item,0,0,el.width/32);});document.querySelectorAll('canvas[data-npc]').forEach(el=>{const n=D.npcs.find(n=>n.id===el.dataset.npc);if(n){const c=el.getContext('2d');c.clearRect(0,0,32,40);W.character(c,16,38,n.color,0,false,n.appearance?.hat,'down',n.appearance);}});}
  function head(title,subtitle='在这里，时间会等你。'){return '<h2 id="modal-title">'+title+'</h2><p class="subtitle">'+subtitle+'</p>';}
  const button=(label,action,id='',cls='primary',extra='')=>'<button class="'+cls+'" data-action="'+action+'"'+(id?' data-id="'+id+'"':'')+' '+extra+'>'+label+'</button>';
  const itemCanvas=id=>'<canvas width="32" height="32" data-item="'+id+'"></canvas>';
  const ingredients=needs=>'<div class="ingredients">'+Object.entries(needs).map(([id,n])=>'<span class="'+((s.bag[id]||0)<n?'missing':'')+'">'+D.items[id].name+' '+(s.bag[id]||0)+' / '+n+'</span>').join('')+'</div>';
  function openPanel(name,arg=null){if(inputLocked)return;path=[];pending=null;hovered=null;capturing=null;keys.clear();if(!currentPanel)lastFocus=document.activeElement;currentPanel=name;panelArg=arg;$('modal-overlay').hidden=false;$('game-root').classList.add('menu-open');$('hover-card').hidden=true;renderPanel(name,arg);$('modal-body').scrollTop=0;const focus=$('modal-body').querySelector('input,button,select');if(focus)focus.focus();else document.querySelector('.modal-close').focus();update();}
  function closePanel(){if(inputLocked)return;if(currentPanel==='welcome'&&!s.flags.introDone){startGame();return;}currentPanel=null;panelArg=null;capturing=null;$('modal-overlay').hidden=true;$('game-root').classList.remove('menu-open');keys.clear();(lastFocus?.isConnected?lastFocus:$('world')).focus();update();}
  function renderPanel(name,arg){
    let html='', extra=name==='debug'&&window.ZRZ_DEV?window.ZRZDebug?.render(s):X.render(name,arg,s,{head,button,itemCanvas,ingredients,escape,dialogue:lastDialogue});
    if(extra!==null)html=extra;
    else if(name==='menu'){
      html=head('在禾溪，好好生活。','一方菜地，一碗热饭。想做什么，就从这里翻开。');
      const entries=[['bag','随身背包','看看今天的收获','bag',keyLabel('bag')],['map','村庄地图','找一条想走的小路','mountain',keyLabel('map')],['calendar','节气日历','看看时令和聚会','calendar','C'],['orders','邻里心愿','送饭、搭把手、修河埠','note',''],['recipes','家常菜谱','把收成做成家常','bowl',''],['relations','乡里乡亲','找到你惦记的人','people',''],['journal','生活手记','收下每一点变化','book',keyLabel('journal')],['build','修缮小院','添一点家的模样','hammer',''],['save','保存与读档','把日子好好记住','save',''],['settings','生活设置','画面、声音与按键','settings',''],['help','生活指南','农事和邻里的小窍门','help',''],['close','回到村庄','继续今天的生活','leaf','Esc']];
      html+='<div class="menu-grid">'+entries.map(([a,title,desc,icon,key])=>'<button class="menu-card" data-action="'+a+'">'+svg(icon)+'<span><strong>'+title+'</strong><small>'+desc+'</small></span>'+(key?'<kbd>'+key+'</kbd>':'')+'</button>').join('')+'</div>';
    } else if(name==='welcome'){
      html='<div class="welcome"><div class="letter-mark">一封留给你的信 · 春日</div>'+head('回来就好。','')+'<p>院门的钥匙，还放在老地方。<br>地里的菜慢慢种，日子也慢慢过。<br>饭做多了，就给隔壁阿婆送一碗。</p><p class="sign">—— 爷爷留下的便条</p><div class="field-row"><label>怎么称呼你？<input id="new-name" type="text" value="小满" maxlength="12" autocomplete="off"></label><label>主角性别<select id="new-gender"><option>不设定</option><option>女</option><option>男</option></select></label></div>'+button('推开院门，开始种日子','start')+'<p class="subtitle">阿婆帮你留了两块成熟的青菜地。先收下它们，做一道家常菜吧。<br>点击场景自动走近并互动，也可以用 WASD 移动、E 交互。</p><div class="mode-tag">内容扩展版：24 位村民、8 条成年关系线、5 个区域与完整四季日历。可在生活设置调整外观。</div></div>';
    } else if(name==='bag'||name==='sell'){
      html=head(name==='bag'?'随身的东西':'把收成带去集镇',name==='bag'?'食材不会腐坏。好东西可以自己吃，也可以留给邻居。':'价格稳定，慢慢卖，不用着急。种子和材料也能按基础价出售。');
      html+='<div class="tabs">'+['全部','食材','种子','料理','材料'].map(f=>button(f,'filter',f,inventoryFilter===f?'active':'')).join('')+'</div><div class="inventory-grid">';
      const bag=Object.entries(s.bag).filter(([id,q])=>q>0&&(inventoryFilter==='全部'||D.items[id].kind===inventoryFilter));
      html+=bag.map(([id,q])=>'<article class="item-card"><div class="item-head">'+itemCanvas(id)+'<div><strong>'+D.items[id].name+'</strong><small>'+D.items[id].kind+' · '+D.items[id].price+' 元</small></div><span class="qty">'+q+'</span></div><div class="button-row">'+(name==='sell'?button('出售 1 份','sell-item',id,'mini-btn')+button('全部出售','sell-all',id,'mini-btn'):D.items[id].energy?button('吃一份 · 体力 +'+D.items[id].energy,'eat',id,'mini-btn'):D.items[id].kind==='种子'?button('选为播种','choose-seed',Object.keys(D.crops).find(k=>D.crops[k].seed===id),'mini-btn'):'<span class="tag">'+(D.items[id].kind==='料理'?'可以送给邻居':'可以用于料理或交易')+'</span>')+'</div></article>').join('');
      html+='</div>'+(!bag.length?'<div class="empty-state">这里还空着。去种点菜、采点时鲜吧。</div>':'');
      if(name==='bag')html+='<div class="button-row">'+button('去集镇买卖','go-shop','','secondary')+button('看看家常菜谱','recipes','','secondary')+'</div>';
    } else if(name==='shop'){
      const season=C.calendar(s).season;html=head('许婶的杂货铺','应季的种子、家常的米粮，还有几句街坊闲话。你有 '+s.money+' 元。');
      html+='<div class="tabs">'+button('买点东西','shop','','active')+button('卖出收成','sell-panel')+'</div>';
      const ids=[...Object.values(D.crops).filter(c=>c.seasons.includes(season)).map(c=>c.seed),'feed','rice'];
      html+=ids.map(id=>{const it=D.items[id],crop=Object.values(D.crops).find(c=>c.seed===id),cost=it.cost||24;return '<div class="row-card">'+itemCanvas(id)+'<div class="row-text"><h3>'+it.name+' <span class="tag">'+cost+' 元 / 份</span></h3><p>'+(crop?crop.days+' 天收获 · '+crop.group+' · 售价 '+crop.price+' 元 / 份':id==='feed'?'鸡、鸭、牛都喜欢的草谷饲料。':'做一碗热饭，或为家常菜备点主食。')+'</p></div><div class="row-actions">'+button('买 1 份','buy',id,'mini-btn','data-qty="1"')+button('买 5 份','buy',id,'mini-btn','data-qty="5"')+'</div></div>';}).join('');
    } else if(name==='seeds'){
      html=head('播下这一季的期待','土壤轮作可以提高收成。豆类能养地，休耕也会慢慢恢复。');
      html+=Object.entries(D.crops).map(([id,c])=>'<div class="row-card">'+itemCanvas(id)+'<div class="row-text"><h3>'+c.name+' <span class="tag">'+c.days+' 天 · '+c.group+'</span></h3><p>适种：'+c.seasons.map(v=>D.seasons[v]).join('、')+' · 背包种子 '+(s.bag[c.seed]||0)+' 份</p></div>'+button(id===s.seed?'已选好':'选这颗种子','choose-seed',id,'mini-btn',!c.seasons.includes(C.calendar(s).season)?'disabled':'')+'</div>').join('');
    } else if(name==='recipes'||name==='cook'){
      html=head(name==='cook'?'把日子煮成家常':'爷爷的家常菜谱',name==='cook'?'灶火很暖。备好食材，选一道菜，想想要与谁分享。':'菜谱随时可以翻看；到农家小院的灶台前，才能开始做饭。');
      html+=D.recipes.map(r=>'<div class="row-card">'+itemCanvas(r.id)+'<div class="row-text"><h3>'+D.items[r.id].name+' <span class="tag">体力 +'+D.items[r.id].energy+'</span></h3><p>'+r.story+'</p>'+ingredients(r.ingredients)+'</div><div class="row-actions">'+(name==='cook'?button(r.upgrade&&!s.upgrades[r.upgrade]?'需整理厨房':'做 1 份','cook-item',r.id,'mini-btn','data-qty="1" '+(!C.has(s,r.ingredients)||(r.upgrade&&!s.upgrades[r.upgrade])?'disabled':''))+button('做 3 份','cook-item',r.id,'mini-btn','data-qty="3" '+(!C.has(s,r.ingredients,3)||(r.upgrade&&!s.upgrades[r.upgrade])?'disabled':'')):button('去小厨房','go-kitchen','','mini-btn'))+'</div></div>').join('');
      if(s.processing.length)html+='<div class="paper-note">腌菜坛里：'+s.processing.map(p=>D.items[p.id].name+' ×'+p.qty+' · 明早出坛').join('，')+'</div>';
    } else if(name==='relations'){
      html=head('乡里乡亲','不用每天送礼。聊聊天、一起做事、一碗家常菜，都能让彼此熟悉。关系不会随时间减少。');
      html+=D.npcs.map(n=>{const r=s.relations[n.id],scene=C.npcScene(s,n);return '<div class="row-card"><canvas class="npc-portrait" width="32" height="40" data-npc="'+n.id+'"></canvas><div class="row-text"><h3>'+n.name+' <span class="tag">'+C.stage(r.points)+'</span></h3><p>'+n.role+' · '+n.age+' 岁<br>此刻在'+D.scenes[scene].name+' · 喜欢'+n.likes.map(id=>D.items[id].name).join('、')+'</p><div class="relationship-bar"><span style="width:'+r.points+'%"></span></div></div>'+button('去找对方','find-npc',n.id,'mini-btn')+'</div>';}).join('');
    } else if(name==='npc'){
      const n=D.npcs.find(n=>n.id===arg),r=s.relations[arg];html=head(n.name,n.role+' · '+C.stage(r.points));
      html+='<p class="dialogue-quote">'+escape(lastDialogue||n.greeting)+'</p><p>对方喜欢：'+n.likes.map(id=>D.items[id].name).join('、')+'</p><div class="button-row">'+button('送一道菜','gift-list',n.id,'secondary')+button('看看邻里心愿','orders','','secondary')+button('下回再聊','close')+'</div>';
    } else if(name==='gifts'){
      const n=D.npcs.find(n=>n.id===arg);html=head('给'+n.name+'的一份心意','每天收一份礼物就足够。送来喜欢的菜，能让对方多开心一点。');
      const dishes=Object.entries(s.bag).filter(([id,q])=>q>0&&D.items[id].kind==='料理');
      html+=dishes.length?dishes.map(([id,q])=>'<div class="row-card">'+itemCanvas(id)+'<div class="row-text"><h3>'+D.items[id].name+' ×'+q+'</h3><p>'+(n.likes.includes(id)?'是对方喜欢的口味。':'亲手做的菜，就是好心意。')+'</p></div>'+button('送一份','gift-item',id,'mini-btn','data-npc="'+n.id+'"')+'</div>').join(''):'<div class="empty-state">还没有做好的料理。先去小厨房点起灶火吧。</div>';
    } else if(name==='orders'){
      html=head('邻里手记','一点力所能及的帮助，一份有来有往的心意。这里的委托没有截止日期。');
      html+=D.orders.map(o=>'<div class="row-card"><div class="row-text"><h3>'+o.title+' '+(s.flags[o.id]?'<span class="tag">已经送达</span>':'')+'</h3><p>'+o.text+'</p>'+(!s.flags[o.id]?ingredients(o.needs):'')+'<p>回礼：'+o.money+' 元 · '+Object.entries(o.reward).map(([id,n])=>D.items[id].name+' ×'+n).join('、')+'</p></div>'+button(s.flags[o.id]?'已完成':'送去料理','deliver',o.id,'mini-btn',s.flags[o.id]||!C.has(s,o.needs)?'disabled':'')+'</div>').join('');
      html+='<div class="section-divider">大家一起做的事</div>'+projectCard();
      if(s.flags.bridge)html+='<div class="paper-note">从一把青菜到一顿家常饭，再到一座修好的河埠，你已经完成了基础版的主体验。继续认识邻居，试试下一季的菜吧。</div>';
    } else if(name==='project'){
      html=head('让村庄多一点好','你出一点材料，木生叔出手艺，乡亲们一起搭把手。')+projectCard();
    } else if(name==='build'){
      html=head('一点点，修好老院','不是必须赶完的工程。等材料备齐、手头宽裕了，再慢慢动工。');
      html+=Object.entries(D.upgrades).map(([id,u])=>'<div class="row-card"><div class="row-text"><h3>'+u.name+'</h3><p>'+u.description+'</p>'+ingredients(u.materials)+'<p>工钱 '+u.cost+' 元 · 现有 '+s.money+' 元</p></div>'+button(s.upgrades[id]?'已经修好':'一起动工','upgrade',id,'mini-btn',s.upgrades[id]?'disabled':'')+'</div>').join('');
    } else if(name==='calendar'){
      const c=C.calendar(s);html=head('禾溪节气历','每季 28 天，一年 112 天。节气是农事提示；错过的聚会，乡亲们会为你留一桌。');
      html+='<div class="tabs">'+D.seasons.map((v,i)=>button(v+'日历','cal-season',String(i),calSeason===i?'active':'')).join('')+'</div><div class="calendar-grid">';
      for(let d=1;d<=28;d++){const abs=(c.year-1)*112+calSeason*28+d-1,term=D.terms[Math.floor((calSeason*28+d-1)*24/112)],prev=d===1?'':D.terms[Math.floor((calSeason*28+d-2)*24/112)];html+='<div class="calendar-day '+(c.season===calSeason&&c.date===d?'today ':'')+(d===14?'festival':'')+'">'+String(d).padStart(2,'0')+'<small>'+(d===14?'邻里开席':term!==prev?term:C.weather(abs))+'</small></div>';}
      html+='</div><div class="paper-note">第 14 天起 · '+D.festivals[calSeason]+'<br>带一道料理去隔壁集镇的小饭桌，每季都可以参加。适种：'+Object.values(D.crops).filter(c=>c.seasons.includes(calSeason)).map(c=>c.name).join('、')+'。</div>';
    } else if(name==='festival'){
      const c=C.calendar(s);html=head(D.festivals[c.season],'集镇的小饭桌，从本季第 14 天起一直等你。带一道料理，坐下来聊聊这一季。');
      if(s.festivals.includes(c.year+'-'+c.season))html+='<p class="dialogue-quote">饭吃完了，话还没说完。下回再聚时，记得说说你的新故事。</p>';
      else if(c.date<14)html+='<div class="paper-note">还有 '+(14-c.date)+' 天开席。现在可以先备一点菜，认识几位邻居。</div>';
      else {const dishes=Object.entries(s.bag).filter(([id,q])=>q>0&&D.items[id].kind==='料理');html+=dishes.length?dishes.map(([id,q])=>'<div class="row-card">'+itemCanvas(id)+'<div class="row-text"><h3>'+D.items[id].name+' ×'+q+'</h3></div>'+button('端上饭桌','join-festival',id,'mini-btn')+'</div>').join(''):'<p>先回家做一道料理吧，大家会等你。</p>';}
    } else if(name==='journal'){
      html=head('把平常的日子记下来','菜长了一点，人熟了一点。小小的变化，也值得记住。');
      html+='<div class="stats-grid"><div class="stat"><strong>'+s.stats.harvested+'</strong><small>份亲手收成</small></div><div class="stat"><strong>'+s.stats.cooked+'</strong><small>份家常料理</small></div><div class="stat"><strong>'+s.discovered.length+'</strong><small>种认识的物产</small></div></div>';
      html+=s.journal.map(e=>{const c=C.calendar({day:e.day});return '<div class="journal-entry"><time>'+D.seasons[c.season]+' '+c.date+' 日</time><span>'+escape(e.text)+'</span></div>';}).join('');
      html+='<div class="section-divider">物产小图鉴 · 已认识 '+s.discovered.length+' / '+Object.keys(D.items).length+'</div><div class="inventory-grid">'+s.discovered.map(id=>'<div class="item-card"><div class="item-head">'+itemCanvas(id)+'<strong>'+D.items[id].name+'</strong></div><span class="tag">'+D.items[id].kind+'</span></div>').join('')+'</div>';
    } else if(name==='sleep'){
      const c=C.calendar(s);html=head('今天，就到这里吧。',D.seasons[c.season]+' '+c.date+' 日 · 明天'+C.weather(s.day+1)+'，又是新的日子。');
      html+='<p class="dialogue-quote">把工具放好，给自己留一盏灯。<br>好好睡一觉，明早再看看地里的新变化。</p><div class="paper-note">休息后恢复全部体力，作物和动物会推进一天，进度自动保存。<br>忘记浇水或喂食也没关系，不会失去作物和动物。</div><div class="button-row">'+button('熄灯，迎接明天','next-day')+button('再走走','close','','secondary')+'</div>';
    } else if(name==='year'){
      html=head('一年，把心安顿下来。','四季转了一圈，回乡的钥匙早已用得顺手。');
      html+='<p class="dialogue-quote">这一年，你收下 '+s.stats.harvested+' 份农产，做了 '+s.stats.cooked+' 份热饭。<br>'+ (s.flags.bridge?'河埠换上了新木板，老人孩子多了一个歇脚的地方。':'河边的风还在，邻居们仍等着与你一起修好河埠。')+'<br>'+ (Object.values(s.relations).some(r=>r.points>=30)?'有人开始惦记你的口味，也有人把新米留给了你。':'村里还有许多人，等着与你慢慢熟悉。')+'<br>日子没有标准答案。明年，继续按喜欢的方式生活。</p><div class="paper-note">这是基础版的年度回顾，完整的四季故事与关系结局仍在后续制作范围内。</div>'+button('来年，也好好生活','close');
    } else if(name==='save'){
      html=head('把日子好好收起来','每日和关键操作自动保存。另有 3 个手动档，以及可带走的 JSON 存档。');
      if(!storageAvailable)html+='<div class="paper-note">当前浏览器不能使用本地存储。请使用下方导出功能，避免丢失进度。</div>';
      for(const slot of ['auto','1','2','3','backup']){const raw=readSave(SAVE+'-'+slot);let meta='还没有留下记录。',valid=false;if(raw){try{const v=C.load(raw),c=C.calendar(v);meta=escape(v.name)+' · 第 '+c.year+' 年 '+D.seasons[c.season]+' '+c.date+' 日 · '+v.money+' 元';valid=true;}catch(_){meta='此存档损坏，原数据保留。';}}html+='<div class="save-row"><div><h3>'+({auto:'每日自动档',backup:'上一份自动备份'}[slot]||'手动存档 '+slot)+'</h3><p>'+meta+'</p></div>'+(!['auto','backup'].includes(slot)?button('保存到此处','save-slot',slot,'mini-btn'):'')+button('读取','load-slot',slot,'mini-btn',valid?'':'disabled')+'</div>';}
      html+='<div class="button-row">'+button('导出存档','export','','secondary')+button('导入存档','import','','secondary')+'</div><p class="mode-tag">浏览器清理数据或更换游戏路径可能影响本地存档。导出一份 JSON，就能在另一台电脑继续生活。</p>';
    } else if(name==='settings'){
      html=head('按自己的节奏生活','画面、声音与操作，都由你来决定。设置随存档保存。');
      html+='<div class="settings-row"><label>画面全屏<small>游戏始终铺满窗口；点击还可隐藏浏览器边框。</small></label>'+button(document.fullscreenElement?'退出原生全屏':'进入原生全屏','fullscreen','','secondary')+'</div>';
      html+='<div class="settings-row"><label>镜头距离<small>保持像素比例，镜头跟随角色，不拉伸场景。</small></label><select id="zoom-setting"><option value="1" '+(s.settings.zoom===1?'selected':'')+'>开阔 · 100%</option><option value="1.2" '+(s.settings.zoom===1.2?'selected':'')+'>舒适 · 120%</option><option value="1.4" '+(s.settings.zoom===1.4?'selected':'')+'>近景 · 140%</option></select></div>';
      html+='<div class="settings-row"><label>时间速度<small>常规约 10 分钟一天，舒缓约 15 分钟；劳动另计少量时间。</small></label><select id="speed-setting"><option value="relaxed" '+(s.settings.speed==='relaxed'?'selected':'')+'>舒缓 · 慢慢来</option><option value="normal" '+(s.settings.speed==='normal'?'selected':'')+'>常规 · 日常节奏</option></select></div>';
      html+='<div class="settings-row"><label>琴音与交互音</label>'+button(s.settings.sound?'已开启':'已关闭','sound','','secondary')+'</div><div class="settings-row"><label>音量</label><input id="volume-setting" type="range" min="0" max="1" step=".05" value="'+s.settings.volume+'" aria-label="音量"></div>';
      html+='<div class="settings-row"><label>生活提示<small>显示画面里的心愿便条与操作提示；H 可临时收起全部界面。</small></label>'+button(s.settings.hints?'已开启':'已关闭','toggle-hints','','secondary')+'</div>';
      html+='<div class="settings-row"><label>自定义按键<small>方向键、空格和 Esc 始终保留，也可以更换 8 个字母快捷键。</small></label>'+button('修改按键','controls','','secondary')+'</div>';
      html+='<div class="button-row">'+button('保存与读档','save','','secondary')+button('生活指南','help','','secondary')+button('重新开始','new-confirm','','secondary danger')+'</div><div class="mode-tag">种日子 v0.3.0 · 四季与邻里<br>24 位村民、28 种作物、30 道菜、8 条成年关系线。</div>';
    } else if(name==='controls'){
      html=head('把操作换成顺手的样子','点击一个按键，再按想使用的字母。重复按键会交换位置。Esc 取消修改。');
      html+='<div class="key-grid">'+Object.entries(bindingNames).map(([id,name])=>'<div class="key-row"><span>'+name+'</span>'+button(keyLabel(id),'bind-key',id,'key-button')+'</div>').join('')+'</div>';
      html+='<div class="paper-note">固定快捷键：方向键移动 · 空格交互 · 1–8 工具<br>Tab 生活菜单 · C 日历 · Q 种子 · F 全屏 · H 收起界面 · Esc 返回<br>这些固定按键不会被覆盖，方便随时找回操作。</div><div class="button-row">'+button('恢复默认按键','reset-bindings','','secondary')+button('回到设置','settings')+'</div>';
    } else if(name==='new-confirm'){
      html=head('重新推开院门','建议先导出当前存档，或保存到手动档。');html+='<p>新生活会替换每日自动存档，手动档仍会保留。</p><div class="button-row">'+button('先导出当前存档','export','','secondary')+button('开始新的生活','new-game')+button('留在现在的日子','close','','secondary')+'</div>';
    } else if(name==='help'){
      html=head('日子可以慢慢学','先试着收菜、做饭、送给邻居。其他的事，随时都来得及。');
      const help=[['走动与交互','WASD 或方向键移动，E 互动。点击地面会自动行走；点击菜地、人物或设施会走近再操作。数字 1–8 切换锄头、种子、水壶、双手、鱼竿。'],['第一次农事','菜地左上角有两株成熟青菜，用 4 双手收获。选 1 耕地，2 播种，3 浇水；睡觉后生长。雨天自然浇水，漏浇只会长慢一点。'],['从菜地到饭桌','2 份小青菜能做一份清炒时蔬。走到小厨房烹饪，再在“邻里手记”交给阿婆。做好的饭也能从背包食用来恢复体力。'],['看得见的村庄变化','给阿婆送菜后，去竹林采集木料和竹材。攒齐木料 8、竹材 6，在河埠动工，会看到新木板、长椅和茶桌。'],['动物、钓鱼和采集','靠近动物按 E，先收产物，再喂食。一份饲料照料一天，次日出产。到河边的小埠互动即可轻松钓鱼，没有反应速度要求。竹林、野山每日恢复。'],['买卖与时令','集镇能买种子、米和饲料，也能卖收成。换季后购买当季种子；跨季已有的作物会继续长。毛豆轮作养地，休耕也会恢复土壤。'],['休息与保存','井边和长椅可以恢复体力。老屋互动可以睡觉进入次日。B 背包，M 地图，J 手记，Tab 生活菜单，C 日历，Q 种子，F 全屏，H 收起界面，Esc 返回；可在设置中修改常用字母键。设置里管理自动档、3 个手动档和导入导出。'],['基础版的范围','5 个场景、24 位村民、28 种作物、3 种动物、30 道菜，112 天日历、4 季节庆和4项公共事务。8位成年候选人各有五章关系故事，完成关系确认后可商量婚礼。']];
      html+='<div class="help-grid">'+help.map(([a,b])=>'<div><h3>'+a+'</h3><p>'+b+'</p></div>').join('')+'</div>';
    } else if(name==='map'){
      html=head('禾溪村的小路','选一个地方出发。也可以沿着场景中的路标走过去。');
      const positions={mountain:[17,18],bamboo:[31,45],farm:[46,79],town:[79,28],river:[81,77]};
      html+='<div class="village-map"><div class="map-river"></div><svg class="map-trails" viewBox="0 0 700 324" preserveAspectRatio="none"><path d="M119 58 217 146 322 256 553 91M322 256 567 250" fill="none"/></svg>'+Object.entries(D.scenes).map(([id,v])=>'<button class="map-place '+(id===s.scene?'current':'')+'" data-action="travel" data-id="'+id+'" style="left:'+positions[id][0]+'%;top:'+positions[id][1]+'%">'+svg(v.icon)+'<strong>'+v.name+'</strong><small>'+({farm:'种菜 · 做饭 · 歇息',town:'买卖 · 邻里 · 聚会',bamboo:'竹材 · 菌菇 · 散步',river:'钓鱼 · 纳凉 · 修河埠',mountain:'采茶 · 山果 · 观景'}[id])+'</small></button>').join('')+'</div>';
      html+='<div class="paper-note">此刻在'+D.scenes[s.scene].name+'。'+D.npcs.filter(n=>C.npcScene(s,n)===s.scene).map(n=>n.name).join('、')+'也在附近。<br>换区域会用掉一点时间，菜单打开时，日子会等你。</div>';
    } else if(name==='fishing'){
      html=head('听，水面的动静。','轻松垂钓 · 不需要抢时机，坐稳等一小会儿。')+'<p class="dialogue-quote">鱼漂轻轻晃动，风从河面吹来……</p><div class="paper-note">等浮漂稳定，约两秒后收竿。设置可打开自动收竿，跳过等待。</div>';
    }
    html+=X.after(name,s,{button});$('modal-body').innerHTML=html;X.mount(s);
    const focused=['welcome','npc','gifts','fishing','sleep','year','new-confirm','story','wedding','separation'].includes(name);$('modal').classList.toggle('focused',focused);
    const active={cook:'recipes',sell:'bag',seeds:'bag',save:'settings',help:'settings',project:'orders',festival:'calendar',controls:'settings'}[name]||name;
    $('book-nav').innerHTML=bookPages.map(([id,title,icon])=>'<button data-action="'+id+'" class="'+(id===active?'active':'')+'" '+(id===active?'aria-current="page"':'')+'>'+svg(icon)+title+'</button>').join('');
    drawIcons();
  }
  function projectCard(){return '<div class="row-card"><div class="row-text"><h3>一起修缮村口河埠 '+(s.flags.bridge?'<span class="tag">已经完成</span>':'')+'</h3><p>换下旧木板，添一张长椅。让老人孩子都能安心在河边歇脚。</p>'+(!s.flags.firstDish?'<p>先给林阿婆送一道家常菜，她会把你介绍给大家。</p>':'')+ingredients({wood:8,bamboo:6})+'</div>'+button(s.flags.bridge?'去河边看看':'和乡亲们动工',s.flags.bridge?'travel':'repair',s.flags.bridge?'river':'','mini-btn',!s.flags.bridge&&(!s.flags.firstDish||!C.has(s,{wood:8,bamboo:6}))?'disabled':'')+'</div>';}
  function startGame(){const name=$('new-name')?.value||s.name,gender=$('new-gender')?.value||'不设定';s.name=name.trim().slice(0,12)||'小满';s.gender=gender;s.flags.introDone=true;currentPanel=null;$('modal-overlay').hidden=true;$('game-root').classList.remove('menu-open');save();update();camera.update(s,0,true);$('world').focus();sound('soft');toast('欢迎回家，'+s.name+'。先用双手收下菜地左上角的青菜吧。');}
  function announceScene(){const el=$('scene-arrival');clearTimeout(arrivalTimer);el.hidden=true;void el.offsetWidth;el.innerHTML=D.scenes[s.scene].name+'<small>'+D.scenes[s.scene].subtitle+'</small>';el.hidden=false;arrivalTimer=setTimeout(()=>el.hidden=true,2700);}
  function travel(id){if(!D.scenes[id]||inputLocked)return;closePanel();if(id!==s.scene){diagnostics.sceneChanges++;s.scene=id;s.player={x:429,y:490,direction:'up'};if(id==='river')s.player={x:130,y:188,direction:'right'};s.minutes=Math.min(1320,s.minutes+10);announceScene();}path=[];pending=null;hovered=null;pointer=null;keys.clear();camera.update(s,0,true);save();update();sound('soft');}
  function walkTo(point){path=W.route(s,point.x,point.y+5);pending=path.length?point:null;if(!path.length)toast('从旁边的小路走近一些吧。',true);}
  function goToPoint(scene,kind,id){travel(scene);const point=W.points(s).find(p=>id?p.id===id:p.kind===kind);if(point)walkTo(point);}
  function guide(){
    if(!s.flags.firstHarvest){travel('farm');setTool('hand');const i=s.plots.findIndex(p=>p.crop&&p.growth>=D.crops[p.crop].days);if(i>=0)walkTo({kind:'plot',index:i,x:310+i%6*42,y:291+Math.floor(i/6)*36,name:'成熟的菜地'});else toast('这一轮作物还在长。选水壶照料，明早再来看看。');}
    else if(!s.flags.firstCook)goToPoint('farm','cook');
    else if(!s.flags.firstDish)openPanel('orders');
    else if(!s.flags.bridge){if(C.has(s,{wood:8,bamboo:6}))goToPoint('river','project');else{travel('bamboo');const needed=(s.bag.wood||0)<8?'wood':'bamboo',point=W.points(s).find(p=>p.kind==='gather'&&p.item===needed&&s.collected[p.id]!==s.day);if(point)walkTo(point);else toast('这一处今天已经采过了。野山也有木料，或者明天再来。');}}
    else openPanel('stories');
  }
  function toggleHud(){hudVisible=!hudVisible;$('game-root').classList.toggle('hud-hidden',!hudVisible);$('hud-restore').hidden=hudVisible;}
  async function fullscreen(){try{if(document.fullscreenElement)await document.exitFullscreen();else if($('game-root').requestFullscreen)await $('game-root').requestFullscreen();else throw new Error('unsupported');}catch(_){toast('画面已铺满当前窗口。此浏览器不支持原生全屏，可以用 Edge 或 Chrome 打开。',true);}camera.update(s,0,true);update();}
  let lastDialogue='';
  function interact(p){
    if(!p||currentPanel||inputLocked)return;
    if(p.kind==='plot'){const result=C.plotAction(s,p.index,tool);if(result.ok)effect={x:p.x,y:p.y,t:frameTime,color:tool==='water'?'#c2e0d3':'#ecda98'};apply(result);return;}
    if(p.kind==='npc'){lastDialogue=C.talk(s,p.id).msg;save();openPanel('npc',p.id);sound('soft');}
    else if(p.kind==='travel')travel(p.id);
    else if(p.kind==='animal')apply(C.tend(s,p.id));
    else if(p.kind==='gather'){const result=C.gather(s,p.id,p.item);if(result.ok)effect={x:p.x,y:p.y,t:frameTime};apply(result);}
    else if(p.kind==='rest')apply(C.rest(s));
    else if(p.kind==='fish'){
      if(s.stamina<2){toast('先休息或吃点东西，再来钓鱼。',true);return;}
      if(s.settings.fishAssist){apply(C.fish(s));return;}
      openPanel('fishing');inputLocked=true;$('modal').querySelector('.modal-close').hidden=true;
      fishTimer=setTimeout(()=>{fishTimer=null;inputLocked=false;$('modal').querySelector('.modal-close').hidden=false;closePanel();apply(C.fish(s));},2100);
    }else if(p.kind==='story')openPanel('stories');else if(p.kind==='pet')apply(C.pet(s));else openPanel(p.kind);
  }
  function nearest(){
    const p=s.player,pts=W.points(s);
    if(s.scene==='farm'){const index=W.plotAt(p.x,p.y+9);if(index>=0)pts.push({kind:'plot',index,x:310+index%6*42,y:291+Math.floor(index/6)*36,name:'照料菜地'});for(let i=0;i<24;i++)pts.push({kind:'plot',index:i,x:310+i%6*42,y:291+Math.floor(i/6)*36,name:'照料菜地'});}
    const sorted=pts.map(v=>({...v,dist:Math.hypot(v.x-p.x,v.y-p.y)})).filter(v=>v.dist<49).sort((a,b)=>a.dist-b.dist);
    if(hovered&&Math.hypot(hovered.x-p.x,hovered.y-p.y)<53)return hovered;
    return sorted[0];
  }
  function setTool(id){tool=id;update();sound();if(id==='build')openPanel('decor');}
  document.addEventListener('click',e=>{
    const b=e.target.closest('[data-action]');if(!b||b.disabled||inputLocked)return;const a=b.dataset.action,id=b.dataset.id;
    if(window.ZRZ_DEV&&a==='debug'){openPanel('debug');return;}
    if(X.dispatch(a,id,b.dataset,{s,apply,open:openPanel,render:()=>renderPanel(currentPanel,panelArg),save,update,toast,close:closePanel}))return;
    if(['menu','controls','bag','shop','recipes','relations','orders','build','journal','settings','save','help','seeds','map','project','sleep'].includes(a)){openPanel(a);return;}
    if(a==='calendar'){calSeason=C.calendar(s).season;openPanel(a);return;}
    if(a==='close'){closePanel();return;}if(a==='start'){startGame();return;}if(a==='tool'){setTool(id);return;}if(a==='travel'){travel(id);return;}
    if(a==='sound'){s.settings.sound=!s.settings.sound;if(!s.settings.sound&&soundContext)soundContext.suspend();else sound();save();update();if(currentPanel==='settings')renderPanel('settings');return;}
    if(a==='guide'){guide();return;}
    if(a==='toggle-hud'){toggleHud();return;}
    if(a==='toggle-quest'){questExpanded=!questExpanded;$('quest-content').hidden=!questExpanded;b.setAttribute('aria-expanded',String(questExpanded));$('quest-chevron').textContent=questExpanded?'−':'+';return;}
    if(a==='toggle-hints'){s.settings.hints=!s.settings.hints;save();update();renderPanel('settings');return;}
    if(a==='bind-key'){capturing=id;document.querySelectorAll('[data-action="bind-key"]').forEach(el=>{el.classList.remove('binding');el.textContent=keyLabel(el.dataset.id);});b.textContent='请按键…';b.classList.add('binding');return;}
    if(a==='reset-bindings'){s.settings.bindings={...C.defaultBindings};capturing=null;save();update();renderPanel('controls');toast('常用快捷键已恢复为初始设置。');return;}
    if(a==='filter'){inventoryFilter=id;renderPanel(currentPanel,panelArg);return;}
    if(a==='go-shop'){goToPoint('town','shop');return;}if(a==='go-kitchen'){goToPoint('farm','cook');return;}
    if(a==='find-npc'){const n=D.npcs.find(n=>n.id===id);goToPoint(C.npcScene(s,n),'npc',id);return;}
    if(a==='sell-panel'){inventoryFilter='全部';openPanel('sell');return;}
    if(a==='buy')apply(C.buy(s,id,Number(b.dataset.qty)),true);
    if(a==='sell-item')apply(C.sell(s,id,1),true);if(a==='sell-all')apply(C.sell(s,id,s.bag[id]||0),true);
    if(a==='eat')apply(C.eat(s,id),true);
    if(a==='choose-seed'){s.seed=id;setTool('seed');closePanel();save();toast('选好了'+D.crops[id].name+'种子。点击松好的菜地播种。');}
    if(a==='cook-item')apply(C.cook(s,id,Number(b.dataset.qty)),true);
    if(a==='gift-list')openPanel('gifts',id);
    if(a==='gift-item')apply(C.gift(s,b.dataset.npc,id),true);
    if(a==='deliver')apply(C.deliver(s,id),true);
    if(a==='repair')apply(C.repair(s),true);
    if(a==='upgrade')apply(C.upgrade(s,id),true);
    if(a==='join-festival')apply(C.festival(s,id),true);
    if(a==='cal-season'){calSeason=Number(id);renderPanel('calendar');}
    if(a==='next-day'){closePanel();apply(C.nextDay(s));path=[];pending=null;hovered=null;camera.update(s,0,true);if(s.day%112===0)openPanel('year');else announceScene();}
    if(a==='save-slot'){const yes=save(id,false);if(yes){renderPanel('save');toast('已保存到手动档 '+id+'。');}}
    if(a==='load-slot'){try{s=C.load(readSave(SAVE+'-'+id));closePanel();path=[];pending=null;hovered=null;camera.update(s,0,true);save();update();toast('回到了上次记下的日子。');}catch(err){toast(err.message,true);}}
    if(a==='export'){const blob=new Blob([JSON.stringify(C.load(s),null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download='种日子-第'+C.calendar(s).year+'年-'+D.seasons[C.calendar(s).season]+C.calendar(s).date+'日.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),2000);toast('存档已交给浏览器下载。');}
    if(a==='import')$('import-file').click();
    if(a==='fullscreen')fullscreen();
    if(a==='new-confirm')openPanel('new-confirm');
    if(a==='new-game'){save('backup');s=C.initial();path=[];pending=null;hovered=null;tool='hand';openPanel('welcome');update();}
  });
  document.addEventListener('change',e=>{if(e.target.dataset.extraSetting){const key=e.target.dataset.extraSetting;s.settings[key]=['textScale','music','ambient','effects'].includes(key)?Number(e.target.value):e.target.value;save();update();return;}if(e.target.id==='speed-setting'){s.settings.speed=e.target.value;save();update();}if(e.target.id==='volume-setting'){s.settings.volume=Number(e.target.value);save();sound();}if(e.target.id==='zoom-setting'){s.settings.zoom=Number(e.target.value);camera.update(s,0,true);save();update();}});
  $('import-file').addEventListener('change',async e=>{const file=e.target.files[0];if(!file)return;try{if(file.size>2e6)throw new Error('存档文件过大，请选择本游戏导出的 JSON。');const next=C.load(await file.text());save('backup');s=next;path=[];pending=null;hovered=null;closePanel();save();update();toast('存档已经带回来了，欢迎继续生活。');}catch(err){toast(err.message||'无法读取这份存档。',true);}finally{e.target.value='';}});
  $('modal-overlay').addEventListener('click',e=>{if(e.target===$('modal-overlay'))closePanel();});
  function hoverInfo(){const box=$('hover-card');if(!hovered||currentPanel){box.hidden=true;return;}if(hovered.kind==='plot'){const p=s.plots[hovered.index],name=p.crop?D.crops[p.crop].name:p.tilled?'松好的菜地':'未开垦的土地',soil=p.soil>=1.75?'肥沃':p.soil>=.75?'稳定':'需要养护';box.innerHTML='<strong>'+name+'</strong>'+(p.crop?(p.growth>=D.crops[p.crop].days?'已经成熟 · 用双手收获':'预计 '+Math.ceil(D.crops[p.crop].days-p.growth)+' 天后收获'):'适合种植：'+(p.lastGroup==='叶菜'?'豆类 / 根菜轮作':'当季作物'))+'<small>土壤：'+soil+' · '+(p.watered?'湿润':'待浇水')+(p.pest?' · 少量小虫，农田照料页可处理':'')+'<br>适合：'+(p.lastGroup==='叶菜'?'豆类、根菜轮作':'当季作物轮作')+'</small>';}else{box.innerHTML='<strong>'+hovered.name+'</strong><small>点击走近互动 · 靠近后按 E</small>';}box.hidden=false;}
  function coords(e){const r=$('world').getBoundingClientRect();return camera.toWorld(e.clientX-r.left,e.clientY-r.top);}
  function positionHover(){if(!pointer)return;const box=$('hover-card'),v=camera.view;box.style.left=Math.max(8,Math.min(v.width-box.offsetWidth-12,pointer.x+20))+'px';box.style.top=Math.max(8,Math.min(v.height-box.offsetHeight-150,pointer.y+23))+'px';}
  $('world').addEventListener('pointermove',e=>{const r=$('world').getBoundingClientRect();pointer={x:e.clientX-r.left,y:e.clientY-r.top};const p=coords(e);hovered=W.hit(s,p.x,p.y);hoverInfo();positionHover();});
  $('world').addEventListener('pointerleave',()=>{hovered=null;pointer=null;hoverInfo();});
  $('world').addEventListener('pointerdown',e=>{if(currentPanel||inputLocked)return;e.preventDefault();$('world').focus();sound('soft');const p=coords(e),hit=W.hit(s,p.x,p.y);if(hit&&Math.hypot(hit.x-s.player.x,hit.y-s.player.y)<53){path=[];pending=null;interact(hit);return;}const target=hit?{x:hit.x,y:hit.y+5}:p;path=W.route(s,target.x,target.y);pending=path.length?hit:null;if(!path.length)toast('这里走不过去，试试旁边的小路。');});
  document.addEventListener('keydown',e=>{
    if(capturing){e.preventDefault();if(e.key==='Escape'){capturing=null;renderPanel('controls');return;}const key=e.key.toLowerCase();if(!C.bindingKeyAllowed(key)){toast('请选择字母键；C、F、H、Q 是固定功能键。',true);return;}const old=s.settings.bindings[capturing],other=Object.keys(s.settings.bindings).find(k=>s.settings.bindings[k]===key);if(other)s.settings.bindings[other]=old;s.settings.bindings[capturing]=key;capturing=null;save();update();renderPanel('controls');toast('按键已经换好了，下次打开也会记住。');return;}
    if(e.key==='Tab'&&currentPanel){const focusable=[...$('modal').querySelectorAll('button:not([disabled]):not([hidden]),input,select')].filter(el=>el.offsetParent!==null);if(!focusable.length)return;const first=focusable[0],last=focusable.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}return;}
    if(e.key==='Escape'){e.preventDefault();currentPanel?closePanel():openPanel('menu');return;}
    if(currentPanel||inputLocked||['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName))return;
    if(e.ctrlKey||e.metaKey||e.altKey)return;
    const key=e.key.toLowerCase(),bindings=s.settings.bindings;
    if([...Object.values(bindings),'arrowup','arrowdown','arrowleft','arrowright',' ','1','2','3','4','5','6','7','8','tab','c','q','f','h'].includes(key))e.preventDefault();
    if([bindings.up,bindings.left,bindings.down,bindings.right,'arrowup','arrowdown','arrowleft','arrowright'].includes(key)){keys.add(key);path=[];pending=null;}
    if(e.repeat)return;
    if('12345678'.includes(key)&&key.length===1)setTool(tools[Number(key)-1].id);
    if(key===bindings.interact||key===' '){const point=nearest();if(point)interact(point);else toast('走近菜地、村民或设施，就能互动。');}
    if(key===bindings.bag)openPanel('bag');if(key===bindings.map)openPanel('map');if(key===bindings.journal)openPanel('journal');
    if(key==='tab')openPanel('menu');if(key==='c'){calSeason=C.calendar(s).season;openPanel('calendar');}if(key==='q')openPanel('seeds');if(key==='f')fullscreen();if(key==='h')toggleHud();
  });
  document.addEventListener('keyup',e=>keys.delete(e.key.toLowerCase()));
  window.addEventListener('blur',()=>keys.clear());document.addEventListener('visibilitychange',()=>{keys.clear();lastTime=performance.now();if(document.hidden)save();});window.addEventListener('pagehide',()=>save());
  window.addEventListener('resize',()=>camera.update(s,0,true));document.addEventListener('fullscreenchange',()=>{camera.update(s,0,true);update();if(currentPanel==='settings')renderPanel('settings');});
  let padX=0,padY=0,padPrevious=[],padMenuAt=0;
  function pollGamepad(now){
    padX=0;padY=0;if(!s.settings.gamepad||document.hidden||inputLocked)return;
    const pad=[...(navigator.getGamepads?.()||[])].find(p=>p?.connected);if(!pad){padPrevious=[];return;}
    const down=i=>!!pad.buttons[i]?.pressed,press=i=>down(i)&&!padPrevious[i];
    if(currentPanel){
      if(press(1)||press(9)){closePanel();}
      else{const focus=document.activeElement,horizontal=press(15)?1:press(14)?-1:0;if(horizontal&&focus?.tagName==='SELECT'){focus.selectedIndex=(focus.selectedIndex+horizontal+focus.options.length)%focus.options.length;focus.dispatchEvent(new Event('change',{bubbles:true}));}else if(horizontal&&focus?.matches('input[type=range],input[type=number]')){const step=Number(focus.step)||1;focus.value=String(Math.max(Number(focus.min)||0,Math.min(Number(focus.max)||999999,Number(focus.value)+horizontal*step)));focus.dispatchEvent(new Event('change',{bubbles:true}));}
        const direction=down(13)?1:down(12)?-1:Math.abs(pad.axes[1]||0)>.5?Math.sign(pad.axes[1]):0;
        if(direction&&now>padMenuAt){padMenuAt=now+190;const list=[...$('modal').querySelectorAll('button:not([disabled]),input,select')].filter(el=>el.offsetParent!==null),i=list.indexOf(document.activeElement);if(list.length){const next=list[(i+direction+list.length)%list.length];next.focus();next.scrollIntoView({block:'nearest'});}}
        if(press(0)&&document.activeElement?.matches('button:not([disabled]),input[type=checkbox]'))document.activeElement.click();
      }
    }else{
      padX=(Math.abs(pad.axes[0]||0)>.2?pad.axes[0]:0)+(down(15)?1:0)-(down(14)?1:0);padY=(Math.abs(pad.axes[1]||0)>.2?pad.axes[1]:0)+(down(13)?1:0)-(down(12)?1:0);
      if(padX||padY){path=[];pending=null;}
      if(press(0)){const point=nearest();if(point)interact(point);}
      if(press(2))openPanel('bag');if(press(3))openPanel('map');if(press(9)||press(1))openPanel('menu');
      if(press(4)||press(5)){const i=tools.findIndex(t=>t.id===tool),next=(i+(press(5)?1:-1)+tools.length)%tools.length;setTool(tools[next].id);}
    }
    padPrevious=pad.buttons.map(b=>b.pressed);
  }
  function move(dt){const bindings=s.settings.bindings;let dx=(keys.has(bindings.right)||keys.has('arrowright')?1:0)-(keys.has(bindings.left)||keys.has('arrowleft')?1:0),dy=(keys.has(bindings.down)||keys.has('arrowdown')?1:0)-(keys.has(bindings.up)||keys.has('arrowup')?1:0);const speed=138*dt;
    dx+=padX;dy+=padY;
    if(path.length&&!dx&&!dy){const n=path[0],dist=Math.hypot(n.x-s.player.x,n.y-s.player.y);if(dist<=speed){s.player.x=n.x;s.player.y=n.y;path.shift();if(!path.length&&pending){const p=pending;pending=null;interact(p);}return true;}dx=(n.x-s.player.x)/dist;dy=(n.y-s.player.y)/dist;}
    const norm=Math.hypot(dx,dy);if(!norm)return false;dx=dx/norm*speed;dy=dy/norm*speed;const p=s.player;
    if(Math.abs(dx)>Math.abs(dy))p.direction=dx>0?'right':'left';else p.direction=dy>0?'down':'up';
    if(!W.blocked(s,p.x+dx,p.y))p.x+=dx;if(!W.blocked(s,p.x,p.y+dy))p.y+=dy;return true;
  }
  function frame(now){diagnostics.frames++;pollGamepad(now);const dt=Math.min(.05,(now-(lastTime||now))/1000);lastTime=now;frameTime=now/1000;
    if(!currentPanel&&!document.hidden&&!inputLocked){walking=move(dt);s.minutes=Math.min(1320,s.minutes+dt*(s.settings.speed==='normal'?1.55:1.04));tick+=dt;if(tick>1){tick=0;update();if(s.minutes>=1320)openPanel('sleep');}ambient(frameTime);}else walking=false;
    camera.update(s,dt);
    if(pointer&&!currentPanel){const point=camera.toWorld(pointer.x,pointer.y);hovered=W.hit(s,point.x,point.y);hoverInfo();positionHover();}
    W.draw(camera.buffer,s,frameTime,hovered,walking,effect);
    if(path.length){const c=camera.buffer.getContext('2d');c.save();c.fillStyle='#fff3b8a0';path.forEach((p,i)=>{if(i%2===0)c.fillRect(Math.round(p.x)-1,Math.round(p.y)-1,2,2);});const dest=path[path.length-1],radius=7+Math.sin(frameTime*5)*2;c.strokeStyle='#fff0ab';c.lineWidth=1.5;c.beginPath();c.ellipse(dest.x,dest.y,radius,radius*.5,0,0,Math.PI*2);c.stroke();c.restore();}
    camera.paint();
    const near=!currentPanel?nearest():null;$('interaction-prompt').hidden=!near;if(near){let label=near.name;if(near.kind==='plot'){const p=s.plots[near.index];label=p.crop&&p.growth>=D.crops[p.crop].days?'成熟了 · 用双手收获':tools.find(v=>v.id===tool).desc+' · '+(p.crop?D.crops[p.crop].name:'菜地');}const point=camera.toScreen(s.player.x,s.player.y-43);$('interaction-prompt').style.left=Math.max(110,Math.min(camera.view.width-110,point.x))+'px';$('interaction-prompt').style.top=Math.max(60,Math.min(camera.view.height-145,point.y))+'px';$('interaction-prompt').innerHTML='<kbd>'+keyLabel('interact')+'</kbd>'+label;}
    requestAnimationFrame(frame);
  }
  camera.update(s,0,true);update();requestAnimationFrame(frame);
  if(!s.flags.introDone)openPanel('welcome');else if(startupNotice)toast(startupNotice,true);
  // Read-only snapshot for diagnostics; state mutations stay inside the game.
  window.ZRZSnapshot=()=>JSON.parse(JSON.stringify(s));
  window.ZRZView=()=>({...camera.view});
  window.ZRZDiagnostics=()=>JSON.parse(JSON.stringify(diagnostics));
  if(window.ZRZ_DEV)window.ZRZDeveloper={replace(next){s=C.load(next);save();update();camera.update(s,0,true);openPanel('debug');},state:()=>C.load(s),open:()=>openPanel('debug')};
})();

