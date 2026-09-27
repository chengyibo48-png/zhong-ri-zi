(function () {
  'use strict';
  const D = window.ZRZData, C = window.ZRZCore, W = window.ZRZWorld, X = window.ZRZPanels, V = window.ZRZVillage;
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
  let queuedDestination=null, chaseAt=0, farmQueue=[],farmNextAt=0,farmCompleted=0;
  const F=window.ZRZFarming,R=window.ZRZRanch;
  let kitchenTask=null,buildTask=null;
  const S=window.ZRZScenes,Actions=window.ZRZActions,sequence=new Actions.Sequence();
  const Feedback=window.ZRZFeedback,selection=new Feedback.Selection();
  let replayUI=false,miniAt=0,sceneFade=0,feedbackPollAt=0,guard=null,guardNonce=0;
  function askGuard(title,text,label,perform){const back={name:currentPanel,arg:panelArg};guard={nonce:++guardNonce,perform,back};openPanel('feedback-confirm',{title,text,label,nonce:guard.nonce});}
  function startAction(spec,point,commit,cancel=()=>{}){
    if(inputLocked||sequence.active)return false;
    const identity=s,room=s.village.interior,before=Feedback.snapshot(s,point);spec={...spec,duration:Feedback.duration(s,spec)};keys.clear();walking=false;
    const dx=point.x-s.player.x,dy=point.y-s.player.y;
    if(Math.hypot(dx,dy)>1)s.player.direction=Math.abs(dx)>Math.abs(dy)?dx>0?'right':'left':dy>0?'down':'up';
    inputLocked=true;V.stateRuntime(s).action=null;V.stateRuntime(s).fx=[];sound(spec.kind);
    sequence.start({...spec,x:point.x,y:point.y,targetKind:point.kind,npcId:point.npcId||(['npc','npc-task'].includes(point.kind)?point.id:null),animalId:point.animalId,animalType:point.animalId?s.animals.find(a=>a.id===point.animalId)?.type:null,item:point.animalId?s.animals.find(a=>a.id===point.animalId)?.product:point.kind==='farm-task'?s.plots[point.index]?.crop:spec.item},()=>{
      inputLocked=false;
      if(s!==identity||s.village.interior!==room){cancel();return;}
      try{V.stateRuntime(s).resolvedSequence=true;commit();if(s===identity){const result=Feedback.finish(s,before,point,spec);if(result){save();update();if(result.row.priority)toast(result.row.text,false,true);}}if(spec.door)sceneFade=.3;}catch(err){diagnostics.errors.push(String(err));toast('这次操作未能完成，请重试。',true);}
      finally{inputLocked=false;V.stateRuntime(s).resolvedSequence=false;}
    },()=>{inputLocked=false;V.stateRuntime(s).action=null;V.stateRuntime(s).fx=[];cancel();});
    return true;
  }
  function cancelAction(){if(!sequence.cancel())return;path=[];pending=null;queuedDestination=null;farmQueue=[];ranchQueue=[];kitchenTask=null;buildTask=null;keys.clear();Feedback.note(s,{key:'cancel/'+s.day,title:'已停下手边动作',text:'未完成的这一步没有结算；此前已经做完的部分保留。',type:'未完成',merge:true});save();toast('已停下手边的动作，未结算这次操作。');}

  const K=window.ZRZKitchen,B=window.ZRZBuild,T=window.ZRZTools;
  let ranchQueue=[],ranchNextAt=0,ranchCompleted=0;
  function queueFarm(tasks){closePanel();ranchQueue=[];kitchenTask=null;buildTask=null;farmQueue=tasks.slice();farmCompleted=0;advanceFarm();}
  function advanceFarm(){const task=farmQueue.shift();if(!task)return;const pos=V.plotPosition(task.index);navigate({kind:'farm-task',...pos,...task,name:'农事 · '+(task.index+1)+' 号田'});if(!path.length&&!queuedDestination){farmQueue=[];toast('这块地暂时无法到达，本批已停止。',true);}}


  function queueKitchen(task){buildTask=null;const check=K.preview(s,task);if(!check.ok){toast(check.msg,true);return;}closePanel();farmQueue=[];ranchQueue=[];path=[];pending=null;queuedDestination=null;kitchenTask=task;advanceKitchen();}
  function queueBuild(task){const check=B.preview(s,task);if(!check.ok){toast(check.msg,true);return;}closePanel();farmQueue=[];ranchQueue=[];kitchenTask=null;path=[];pending=null;queuedDestination=null;buildTask=task;advanceBuild();}
  function advanceBuild(){if(!buildTask)return;if(s.village.interior){walkTo(V.points(s).find(p=>p.kind==='exit'));if(!path.length)buildTask=null;return;}const task=buildTask;buildTask=null;walkTo({...B.destination(s,task),...task,kind:'build-task'});}
  function advanceKitchen(){if(!kitchenTask)return;const house=K.house();if(s.village.interior!==house.id){if(s.village.interior)walkTo(V.points(s).find(p=>p.kind==='exit'));else navigate(V.destination(s,'house',house.id));return;}const task=kitchenTask;kitchenTask=null;buildTask=null;walkTo({...K.point(s,task.station),...task,kind:'kitchen-task'});if(!path.length)toast('这个工位暂时走不过去，试试换一侧。',true);}
  function queueRanch(tasks){buildTask=null;kitchenTask=null;closePanel();farmQueue=[];path=[];pending=null;queuedDestination=null;ranchQueue=tasks.slice();ranchCompleted=0;advanceRanch();}
  function advanceRanch(){const t=ranchQueue[0];if(!t)return;let dest;
    if(t.animalId){R.hold(s,t.animalId);dest=R.destination(s,t.animalId);}
    else if(t.pet){R.hold(s,'pet');dest=R.petPoint(s);}
    else{const h=V.houses.find(h=>h.id===R.barns[t.barnId||'cattle'].house);dest=s.village.interior===h.id?{x:480,y:490,room:h.id,name:h.name}:{...h.door,room:null,name:h.name};}
    if(!dest){ranchQueue=[];kitchenTask=null;buildTask=null;toast('伙伴已不在牧场，本批停止。',true);return;}
    if(dest.kind==='enter'){navigate(dest);return;}
    if(s.village.interior!==(dest.room||null)&&s.village.interior){walkTo(V.points(s).find(p=>p.kind==='exit'));return;}
    ranchQueue.shift();walkTo({...dest,...t,kind:'ranch-task',name:'牧场照料 · '+dest.name});
    if(!path.length){ranchQueue=[];kitchenTask=null;buildTask=null;toast('这条照料路线暂时走不过去，本批停止。',true);}
  }

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
      const timbre={water:[580,920,'sine'],hoe:[190,110,'triangle'],build:[240,130,'triangle'],chop:[210,90,'triangle'],harvest:[620,830,'sine'],gather:[620,830,'sine'],seed:[430,660,'sine'],feed:[330,460,'triangle'],door:[240,310,'triangle'],read:[380,420,'sine'],trade:[730,910,'sine'],greet:[440,520,'sine']}[type];osc.type=timbre?.[2]||(type==='music'?'triangle':'sine');osc.frequency.setValueAtTime(timbre?.[0]||(type==='music'?783.99:type==='good'?660:type==='soft'?392:510),now);osc.frequency.exponentialRampToValueAtTime(timbre?.[1]||(type==='good'?880:350),now+.12);
      gain.gain.setValueAtTime(0, now);gain.gain.linearRampToValueAtTime(s.settings.volume * s.settings.effects * .22, now + .02);gain.gain.exponentialRampToValueAtTime(.0001, now + .3);osc.connect(gain);gain.connect(soundContext.destination);osc.start(now);osc.stop(now + .32);
    } catch (_) { /* Sound is optional and never blocks play. */ }
  }
  function ambient(t) {
    if (!soundContext || !s.settings.sound || document.hidden || currentPanel || t < melodyAt) return;
    melodyAt = t + 8;
    try {
    const frequencies = [[261.63,293.66,329.63,392,440],[293.66,329.63,392,440,523.25],[220,261.63,293.66,329.63,392],[196,220,261.63,293.66,329.63]][C.calendar(s).season], now = soundContext.currentTime;
    if(s.settings.music>0&&s.settings.volume>0)[0, 1, 2].forEach((j) => { const osc = soundContext.createOscillator(), gain = soundContext.createGain();osc.type = 'triangle';osc.frequency.value = frequencies[(Math.floor(t / 8) + j * 2) % 5];gain.gain.setValueAtTime(.0001, now + j * .65);gain.gain.exponentialRampToValueAtTime(Math.max(.0002, s.settings.volume * s.settings.music * .09), now + j * .65 + .04);gain.gain.exponentialRampToValueAtTime(.0001, now + j * .65 + 1.5);osc.connect(gain);gain.connect(soundContext.destination);osc.start(now + j * .65);osc.stop(now + j * .65 + 1.6); });
    if(s.settings.ambient>0){
      const wet=['雨','台风'].includes(C.weather(s.day))||s.scene==='river',night=s.minutes>1140;
      const len=soundContext.sampleRate*2,buffer=soundContext.createBuffer(1,len,soundContext.sampleRate),samples=buffer.getChannelData(0);
      for(let i=0;i<len;i++)samples[i]=(Math.random()*2-1)*.2;
      const source=soundContext.createBufferSource(),filter=soundContext.createBiquadFilter(),gain=soundContext.createGain();source.buffer=buffer;filter.type='lowpass';filter.frequency.value=wet?650:300;gain.gain.setValueAtTime(.0001,now);gain.gain.linearRampToValueAtTime(s.settings.volume*s.settings.ambient*(wet?.32:.15),now+.4);gain.gain.exponentialRampToValueAtTime(.0001,now+2);source.connect(filter);filter.connect(gain);gain.connect(soundContext.destination);source.start(now);source.stop(now+2);
      if(!wet){const bird=soundContext.createOscillator(),g=soundContext.createGain();bird.frequency.setValueAtTime(night?650:s.scene==='town'?250:1150,now+.3);bird.frequency.exponentialRampToValueAtTime(night?720:s.scene==='town'?320:1450,now+.5);g.gain.setValueAtTime(.0001,now);g.gain.linearRampToValueAtTime(s.settings.volume*s.settings.ambient*.035,now+.35);g.gain.exponentialRampToValueAtTime(.0001,now+.8);bird.connect(g);g.connect(soundContext.destination);bird.start(now+.3);bird.stop(now+.82);}
    }
    } catch (_) { /* An unavailable audio device must never interrupt the simulation. */ }
  }
  function save(slot = 'auto', silent = true) {
    const started=performance.now();
    try {
      K.ensure(s);const valid = C.load(s), key = SAVE + '-' + slot;
      if (slot === 'auto') { const previous = localStorage.getItem(key); if (previous) { try { C.load(previous); localStorage.setItem(SAVE + '-backup', previous); } catch (_) {} } }
      localStorage.setItem(key, JSON.stringify(valid));diagnostics.saves++;diagnostics.lastSaveMs=performance.now()-started;diagnostics.maxSaveMs=Math.max(diagnostics.maxSaveMs,diagnostics.lastSaveMs);storageAvailable = true;$('save-status').textContent = slot === 'auto' ? '已自动保存 · 安心生活' : '已保存到手动档 ' + slot;
      if (!silent) toast('已经好好记下今天的日子。'); return true;
    } catch (error) { diagnostics.errors.push({kind:'save',message:String(error.message).slice(0,160)});diagnostics.errors=diagnostics.errors.slice(-30);storageAvailable = false;$('save-status').textContent = '本地保存不可用 · 请导出存档';if (!silent) toast('浏览器无法保存，请点“导出存档”保留进度。', true);return false; }
  }
  function toast(msg, error = false, important = false) {
    if(error){Feedback.note(s,{key:'error/'+String(msg).slice(0,100),title:'这一步还没完成',text:msg,type:'未完成',priority:1,merge:true});save();}
    if(!error&&!important&&Feedback.ensure(s).prefs.quiet)return;
    if (currentPanel) { const existing = $('modal-body').querySelector('.modal-toast');if (existing) existing.remove();const el = document.createElement('div');el.className = 'modal-toast' + (error ? ' error' : '');el.setAttribute('role','status');el.textContent = msg;const title = $('modal-body').querySelector('.subtitle');if (title) title.after(el);else $('modal-body').prepend(el); }
    else { const el = document.createElement(important?'button':'div');if(important){el.type='button';el.dataset.action='feedback';el.setAttribute('aria-label',msg+'，打开回响查看');}el.className = 'toast' + (error ? ' error' : '');el.textContent = msg+(important?' · 查看回响 →':'');const same=[...$('toasts').children].find(v=>v.textContent===el.textContent);if(same)same.remove();$('toasts').appendChild(el);while ($('toasts').children.length > 3) $('toasts').firstChild.remove();setTimeout(() => el.remove(), Feedback.ensure(s).prefs.seconds*1000); }
  }
  function apply(result, refresh = false) { if (result.ok) { sound('good');if(s.settings.vibration){try{const pad=[...(navigator.getGamepads?.()||[])].find(Boolean);pad?.vibrationActuator?.playEffect('dual-rumble',{duration:60,weakMagnitude:.12,strongMagnitude:0})?.catch(()=>{});}catch(_){}}save();update();if (refresh && currentPanel) renderPanel(currentPanel,panelArg); } toast(result.msg,!result.ok);return result.ok; }
  function update() {
    window.ZRZUIArt.apply(s);
    $('game-root').style.setProperty('--reading-scale',s.settings.textScale);$('game-root').classList.toggle('high-contrast',s.settings.contrast);
    const fp=Feedback.ensure(s).prefs;$('game-root').classList.toggle('reduced-feedback',fp.motion==='reduced');const unread=Feedback.ensure(s).rows.filter(r=>!r.read).length;if($('feedback-button')){$('feedback-button').textContent='回响'+(unread?' · '+unread:'');$('feedback-button').setAttribute('aria-label','打开手边回响，'+unread+' 条未读');}
    const c = C.calendar(s), hr = Math.floor(s.minutes / 60), minute = Math.floor(s.minutes % 60 / 10) * 10;
    $('year-label').textContent = '在禾溪的第 ' + c.year + ' 年';
    $('season-date').innerHTML = D.seasons[c.season] + ' <b>' + String(c.date).padStart(2,'0') + '</b><small>日</small>';
    $('solar-term').textContent = c.term;$('weather-today').innerHTML = svg(C.weather(s.day)==='晴'?'sun':C.weather(s.day)==='雨'?'rain':'cloud') + window.ZRZEnvironment.profile(s.day).label+' '+window.ZRZEnvironment.profile(s.day,s.minutes).temperature+'°';
    $('clock-label').textContent = String(hr).padStart(2,'0')+':'+String(minute).padStart(2,'0')+' · '+(hr<8?'清晨':hr<12?'上午':hr<17?'午后':hr<20?'傍晚':'夜间');
    $('forecast').textContent = window.ZRZEnvironment.warning(s.day);
    $('player-name').textContent = s.name;$('money').innerHTML = svg('coin') + s.money;$('energy-text').textContent = Math.floor(s.stamina)+' / 100';$('energy-fill').style.width = s.stamina+'%';
    $('scene-title').textContent=V.title(s);$('location-pill').textContent='禾溪村 · '+V.title(s);
    $('sound-btn').innerHTML=svg(s.settings.sound?'sound':'mute');$('sound-btn').setAttribute('aria-pressed',String(s.settings.sound));
    if($('toolbelt').dataset.active!==tool){$('toolbelt').innerHTML=tools.map(t=>'<button class="tool '+(t.id===tool?'active':'')+'" title="'+t.name+' · '+t.key+' · '+t.desc+'" aria-label="'+t.name+'" aria-pressed="'+(t.id===tool)+'" data-action="tool" data-id="'+t.id+'"><span>'+t.key+'</span><canvas width="32" height="32" data-item="'+t.id+'"></canvas></button>').join('');$('toolbelt').dataset.active=tool;}
    const selected=tools.find(t=>t.id===tool);$('tool-name').textContent=selected.name+' · '+selected.desc+(T.defs[tool]?' · '+T.tool(s,tool).level+'阶'+(['hoe','water','sickle'].includes(tool)?' / '+T.shapes[T.tool(s,tool).shape]:''):'');
    $('seed-label').innerHTML=D.crops[s.seed].name+' · '+F.kinds[F.ensure(s).seedKind].name+' <small>剩余 '+(s.bag[F.seedId(s.seed,s.farm.seedKind)]||0)+' 份 · 点击更换</small>';
    $('bag-count').textContent=Object.values(s.bag).reduce((a,b)=>a+b,0)+' 件物品';
    const roomOwner=V.houses.find(h=>h.id===s.village.interior)?.owner;
    $('time-pill').textContent=currentPanel?'翻阅手记中 · 时间暂停':roomOwner?V.profiles[roomOwner][2]:s.settings.speed==='relaxed'?'舒缓时光 · 慢慢来':'常规时光 · 好好生活';
    const phases=[s.flags.firstHarvest,s.flags.firstCook,s.flags.firstDish,s.flags.bridge];const stage=phases.findIndex(x=>!x);
    const objectives=[['收下第一份青菜','菜地左上角有阿婆照料好的青菜。选双手，点击收获。'],['为邻居做一道菜','走到小厨房，用 2 份小青菜做一盘清炒时蔬。'],['给阿婆送一份心意','翻开邻里手记，把清炒时蔬送给阿婆，开始认识邻居。'],['一起修好河埠','去竹林采集木料 ×8、竹材 ×6，再到河边一起动工。'],['小小的村庄，有了变化','去修好的河埠坐坐吧。继续种菜、拜访，或为聚会做道菜。']];
    const o=stage<0?['这一年，继续慢慢过',D.weekHints[Math.floor(s.day%112/7)]+'。生活簿里有新的故事与安排。']:objectives[stage];$('objective').innerHTML='<h3>'+o[0]+'</h3><p>'+o[1]+'</p><div class="progress-line">'+phases.map(f=>'<span class="'+(f?'done':'')+'"></span>').join('')+'</div>';
    $('wish-card').hidden=!s.settings.hints;$('controls-hint').hidden=!s.settings.hints;
    $('controls-hint').innerHTML='<kbd>'+['up','left','down','right'].map(keyLabel).join(' ')+'</kbd> 移动 <i></i><kbd>'+keyLabel('interact')+'</kbd> 交互 <i></i><kbd>1–8</kbd> 工具 <i></i><kbd>Tab</kbd> 菜单';
    document.querySelector('.bag-button kbd').textContent=keyLabel('bag');
    document.querySelector('.energy-track').classList.toggle('low',s.stamina<25);
    $('fullscreen-btn').setAttribute('aria-label',document.fullscreenElement?'退出全屏':'进入全屏');
    $('fullscreen-btn').setAttribute('aria-pressed',String(!!document.fullscreenElement));
    const pc=$('portrait');W.portrait(pc.getContext('2d'),pc.width,pc.height,{color:['#57826a','#647e9b','#b17d67','#ac9a65'][s.appearance.shirt]},window.ZRZCharacters?.context(s)||s.appearance);
    const seedCtx=$('seed-icon').getContext('2d');seedCtx.clearRect(0,0,24,24);W.item(seedCtx,F.seedId(s.seed,s.farm.seedKind),0,0,.75);
    drawIcons();
  }
  function drawIcons(){const mini=$('area-map');if(mini)W.mapView(mini.getContext('2d'),s);document.querySelectorAll('canvas[data-item]').forEach(el=>{const c=el.getContext('2d');c.clearRect(0,0,el.width,el.height);c.imageSmoothingEnabled=false;el.setAttribute('role','img');el.setAttribute('aria-label',D.items[el.dataset.item]?.name||T.defs[el.dataset.item]?.name||({coin:'金币',seed:'种子袋',hand:'双手',build:'布置工具'}[el.dataset.item]||el.dataset.item));if(T.defs[el.dataset.item])T.drawTool(c,el.dataset.item,T.tool(s,el.dataset.item).level,el.width/2,el.height*.7,el.width/58);else W.item(c,el.dataset.item,0,0,el.width/32);});document.querySelectorAll('canvas[data-npc]').forEach(el=>{const n=D.npcs.find(n=>n.id===el.dataset.npc);if(n){const c=el.getContext('2d');W.portrait(c,el.width,el.height,n,window.ZRZCharacters?window.ZRZCharacters.context(s,n.id,el.dataset.emotion):{id:n.id,emotion:el.dataset.emotion});}});}
  function head(title,subtitle='在这里，时间会等你。'){return '<h2 id="modal-title">'+title+'</h2><p class="subtitle">'+subtitle+'</p>';}
  const button=(label,action,id='',cls='primary',extra='')=>'<button class="'+cls+'" data-action="'+action+'"'+(id?' data-id="'+id+'"':'')+' '+extra+'>'+label+'</button>';
  const itemCanvas=id=>'<canvas width="32" height="32" data-item="'+id+'"></canvas>';
  const ingredients=needs=>'<div class="ingredients">'+Object.entries(needs).map(([id,n])=>'<span class="'+((s.bag[id]||0)<n?'missing':'')+'">'+D.items[id].name+' '+(s.bag[id]||0)+' / '+n+'</span>').join('')+'</div>';
  function openPanel(name,arg=null){if(inputLocked)return;path=[];pending=null;queuedDestination=null;farmQueue=[];ranchQueue=[];kitchenTask=null;buildTask=null;hovered=null;capturing=null;keys.clear();if(!currentPanel)lastFocus=document.activeElement;currentPanel=name;panelArg=arg;$('modal-overlay').hidden=false;$('game-root').classList.add('menu-open');$('hover-card').hidden=true;renderPanel(name,arg);$('modal-body').scrollTop=0;const focus=$('modal-body').querySelector('input,button,select');if(focus)focus.focus({preventScroll:true});else document.querySelector('.modal-close').focus({preventScroll:true});update();}
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
      const ids=[...Object.values(D.crops).filter(c=>c.seasons.includes(season)).map(c=>c.seed),'feed','rice','compost','slowFertilizer','bioCare','plantCare'];
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
      html+=D.orders.map(o=>'<div class="row-card"><div class="row-text"><h3>'+o.title+' '+(s.flags[o.id]?'<span class="tag">已经送达</span>':'')+'</h3><p>'+o.text+'</p>'+(!s.flags[o.id]?ingredients(o.needs):'')+'<p class="item-rewards">回礼：'+itemCanvas('coin')+o.money+' 元 · '+Object.entries(o.reward).map(([id,n])=>itemCanvas(id)+D.items[id].name+' ×'+n).join('、')+'</p></div>'+button(s.flags[o.id]?'已完成':'送去料理','deliver',o.id,'mini-btn',s.flags[o.id]||!C.has(s,o.needs)?'disabled':'')+'</div>').join('');
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
      for(const slot of ['auto','1','2','3','backup','recovery']){const raw=readSave(SAVE+'-'+slot);let meta='还没有留下记录。',valid=false;if(raw){try{const v=C.load(raw),c=C.calendar(v);meta=escape(v.name)+' · 第 '+c.year+' 年 '+D.seasons[c.season]+' '+c.date+' 日 · '+v.money+' 元';valid=true;}catch(_){meta='此存档损坏，原数据保留。';}}html+='<div class="save-row"><div><h3>'+({auto:'每日自动档',backup:'上一份自动备份',recovery:'读取前的回退档'}[slot]||'手动存档 '+slot)+'</h3><p>'+meta+'</p></div>'+(!['auto','backup','recovery'].includes(slot)?button('保存到此处','save-slot',slot,'mini-btn'):'')+button('读取','load-slot',slot,'mini-btn',valid?'':'disabled')+'</div>';}
      html+='<div class="button-row">'+button('导出存档','export','','secondary')+button('导入存档','import','','secondary')+'</div><p class="mode-tag">浏览器清理数据或更换游戏路径可能影响本地存档。导出一份 JSON，就能在另一台电脑继续生活。</p>';
    } else if(name==='settings'){
      html=head('按自己的节奏生活','画面、声音与操作，都由你来决定。设置随存档保存。')+window.ZRZUIArt.settings(s);
      html+='<div class="settings-row"><label>画面全屏<small>游戏始终铺满窗口；点击还可隐藏浏览器边框。</small></label>'+button(document.fullscreenElement?'退出原生全屏':'进入原生全屏','fullscreen','','secondary')+'</div>';
      html+='<div class="settings-row"><label>镜头距离<small>保持像素比例，镜头跟随角色，不拉伸场景。</small></label><select id="zoom-setting"><option value="1" '+(s.settings.zoom===1?'selected':'')+'>开阔 · 100%</option><option value="1.2" '+(s.settings.zoom===1.2?'selected':'')+'>舒适 · 120%</option><option value="1.4" '+(s.settings.zoom===1.4?'selected':'')+'>近景 · 140%</option></select></div>';
      html+='<div class="settings-row"><label>时间速度<small>常规约 10 分钟一天，舒缓约 15 分钟；劳动另计少量时间。</small></label><select id="speed-setting"><option value="relaxed" '+(s.settings.speed==='relaxed'?'selected':'')+'>舒缓 · 慢慢来</option><option value="normal" '+(s.settings.speed==='normal'?'selected':'')+'>常规 · 日常节奏</option></select></div>';
      html+='<div class="settings-row"><label>琴音与交互音</label>'+button(s.settings.sound?'已开启':'已关闭','sound','','secondary')+'</div><div class="settings-row"><label>音量</label><input id="volume-setting" type="range" min="0" max="1" step=".05" value="'+s.settings.volume+'" aria-label="音量"></div>';
      html+='<div class="settings-row"><label>生活提示<small>显示画面里的心愿便条与操作提示；H 可临时收起全部界面。</small></label>'+button(s.settings.hints?'已开启':'已关闭','toggle-hints','','secondary')+'</div>';
      html+='<div class="settings-row"><label>自定义按键<small>方向键、空格和 Esc 始终保留，也可以更换 8 个字母快捷键。</small></label>'+button('修改按键','controls','','secondary')+'</div>';
      html+='<div class="button-row">'+button('保存与读档','save','','secondary')+button('生活指南','help','','secondary')+button('重新开始','new-confirm','','secondary danger')+'</div><div class="mode-tag">种日子 v0.20.0 · 纸上四时，手边日常<br>24 位村民、28 种作物、30 道菜、8 条成年关系线。</div>';
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
      html=head('一张地图，走遍禾溪。','所有地方由村道相连。点击地区、房屋或地图上的位置，主角会沿路步行；Shift 加快脚步，也可在户外骑自行车。');
      html+='<div class="village-region-tabs">'+V.regions.map(r=>button(r.name,'v-walk-region',r.id,'mini-btn')).join('')+'</div>';
      html+='<div class="village-atlas"><canvas id="area-map" width="1152" height="1152" aria-label="禾溪村全图，标有六个地区、全部住宅与当前位置，点击可步行导航"></canvas></div>';
      html+='<p class="atlas-legend"><span>● 你的位置</span> · 赭色为乡亲住处 · 青色为公共房屋 · 浅色为连通村道</p><div class="section-divider">二十四户人家 · 点选后沿路拜访</div><div class="home-directory">'+D.npcs.map(n=>{const h=V.homeOf(n.id),home=s.village.npc[n.id].room;return '<button class="home-entry" data-action="v-walk-house" data-id="'+h.id+'"><canvas data-npc="'+n.id+'" width="64" height="80"></canvas><span><strong>'+n.name+'家</strong><small>'+V.profiles[n.id][1]+' · '+V.offsets[h.region].name+'</small><em>'+(home?'此刻在家':'出门活动中')+' · '+Object.keys(s.village.memories).filter(id=>id.startsWith(h.id+'-egg-')).length+'/3 件小故事</em></span></button>';}).join('')+'</div>';
      html+='<div class="section-divider">田园与牧场 · 动手试一试</div><div class="landmark-list">'+V.outdoorActions.map(p=>button(p.name,'v-walk-activity',p.id,'mini-btn')).join('')+'</div>';
      html+='<div class="section-divider">公共屋舍也能进门</div><div class="landmark-list">'+V.houses.filter(h=>!h.owner).map(h=>button(h.name,'v-walk-house',h.id,'mini-btn')).join('')+'</div>';
    } else if(name==='fishing'){
      html=head('听，水面的动静。','轻松垂钓 · 不需要抢时机，坐稳等一小会儿。')+'<p class="dialogue-quote">鱼漂轻轻晃动，风从河面吹来……</p><div class="paper-note">等浮漂稳定，约两秒后收竿。设置可打开自动收竿，跳过等待。</div>';
    }
    html+=X.after(name,s,{button});$('modal-body').innerHTML=html;X.mount(s);
    const focused=['welcome','npc','gifts','fishing','sleep','year','new-confirm','story','wedding','separation','feedback-confirm'].includes(name);$('modal').classList.toggle('focused',focused);
    const active=window.ZRZUIArt.bookPage(name)||{cook:'recipes',sell:'bag',seeds:'bag',save:'settings',help:'settings',project:'orders',festival:'calendar',controls:'settings'}[name]||name;
    $('book-nav').innerHTML=bookPages.map(([id,title,icon])=>'<button data-action="'+id+'" class="'+(id===active?'active':'')+'" '+(id===active?'aria-current="page"':'')+'>'+svg(icon)+title+'</button>').join('');
    window.ZRZUIArt.mount(s,name);
    drawIcons();
  }
  function projectCard(){return '<div class="row-card"><div class="row-text"><h3>一起修缮村口河埠 '+(s.flags.bridge?'<span class="tag">已经完成</span>':'')+'</h3><p>换下旧木板，添一张长椅。让老人孩子都能安心在河边歇脚。</p>'+(!s.flags.firstDish?'<p>先给林阿婆送一道家常菜，她会把你介绍给大家。</p>':'')+ingredients({wood:8,bamboo:6})+'</div>'+button(s.flags.bridge?'去河边看看':'和乡亲们动工',s.flags.bridge?'travel':'repair',s.flags.bridge?'river':'','mini-btn',!s.flags.bridge&&(!s.flags.firstDish||!C.has(s,{wood:8,bamboo:6}))?'disabled':'')+'</div>';}
  function startGame(){const name=$('new-name')?.value||s.name,gender=$('new-gender')?.value||'不设定';s.name=name.trim().slice(0,12)||'小满';s.gender=gender;s.flags.introDone=true;currentPanel=null;$('modal-overlay').hidden=true;$('game-root').classList.remove('menu-open');save();update();camera.update(s,0,true);$('world').focus();sound('soft');toast('欢迎回家，'+s.name+'。先用双手收下菜地左上角的青菜吧。');}
  function announceScene(){const el=$('scene-arrival');clearTimeout(arrivalTimer);el.hidden=true;void el.offsetWidth;el.innerHTML=D.scenes[s.scene].name+'<small>'+D.scenes[s.scene].subtitle+'</small>';el.hidden=false;arrivalTimer=setTimeout(()=>el.hidden=true,2700);}
  function navigate(point){if(!point)return;closePanel();keys.clear();hovered=null;pointer=null;if(s.village.interior){queuedDestination=point;walkTo(V.points(s).find(p=>p.kind==='exit'));toast('先走出小屋，再沿村道出发。');return;}walkTo(point);toast('沿村道前往：'+point.name+'。方向键可随时取消导航。');}
  function queueNeighbor(id,op,data={}){const n=D.npcs.find(n=>n.id===id),point=n&&V.npcPoint(s,n);if(!point||!window.ZRZNpc.near(s,id)){navigate(V.destination(s,'npc',id));toast('先沿路找到对方，再选择话题或一起做事。');return;}closePanel();interact({...point,kind:'npc-task',npcId:id,op,...data});}
  function travel(id){if(inputLocked)return;navigate(V.destination(s,'region',id));}
  function walkTo(point){if(!point)return;const stand=Actions.approach(s,point);path=W.route(s,stand.x,stand.y);pending=path.length?point:null;if(!path.length)toast('这条路暂时走不过去，试试旁边的空地。',true);}
  function goToPoint(scene,kind,id){let p=V.destination(s,kind,id||scene);if(!p&&kind==='cook')p=V.houses.find(h=>h.name==='禾溪小灶');if(p?.door)p=V.destination(s,'house',p.id);navigate(p);}
  function guide(){
    if(!s.flags.firstHarvest){setTool('hand');const i=s.plots.findIndex(p=>p.crop&&p.growth>=D.crops[p.crop].days);if(i>=0)navigate({kind:'plot',index:i,...W.plotPosition(i),name:'成熟的菜地'});else toast('这一轮作物还在长。选水壶照料，明早再来看看。');}
    else if(!s.flags.firstCook)goToPoint('farm','cook');
    else if(!s.flags.firstDish)openPanel('orders');
    else if(!s.flags.bridge){if(C.has(s,{wood:8,bamboo:6}))goToPoint('river','project');else{const needed=(s.bag.wood||0)<8?'wood':'bamboo',point=W.points({...s,village:{...s.village,interior:null}},true).find(p=>p.kind==='gather'&&p.item===needed&&(window.ZRZForage?window.ZRZForage.status(s,p).ready:s.collected[p.id]!==s.day));if(point)navigate(point);else toast('这一处今天已经采过了。野山也有木料，或者明天再来。');}}
    else openPanel('stories');
  }
  function toggleHud(){hudVisible=!hudVisible;$('game-root').classList.toggle('hud-hidden',!hudVisible);$('hud-restore').hidden=hudVisible;}
  async function fullscreen(){try{if(document.fullscreenElement)await document.exitFullscreen();else if($('game-root').requestFullscreen)await $('game-root').requestFullscreen();else throw new Error('unsupported');}catch(_){toast('画面已铺满当前窗口。此浏览器不支持原生全屏，可以用 Edge 或 Chrome 打开。',true);}camera.update(s,0,true);update();}
  let lastDialogue='';
  function interact(p,performed=false){
    if(!p||currentPanel||inputLocked)return;
    if(p.kind==='npc-task'){if(!window.ZRZNpc.near(s,p.id)){toast('对方走开了，先靠近再聊。');return;}if(!performed){const n=window.ZRZNpc.profiles[p.id],kind=p.op==='join'?n.helpKind:p.op==='supply'?'trade':p.op==='story'?'read':'greet';startAction({...Actions.spec(kind,p.op==='join'?n.helpAction:p.op==='supply'?'点好材料，交到邻居手中':'停下脚步，面对面回应'),duration:p.op==='join'?2.8:1.15,item:p.op==='supply'?n.item:null},p,()=>interact(p,true));return;}const r=p.op==='talk'?window.ZRZNpc.converse(s,p.id,p.topic||'auto'):p.op==='story'?C.storyChoice(s,p.id,p.choice):window.ZRZNpc.resolve(s,p.id,p.op,p.day);if(r.ok)lastDialogue=r.msg;apply(r);openPanel(p.op==='story'?'story':'npc',p.id);return;}
    if(!performed&&p.kind==='fish'&&window.ZRZFishing){const begun=window.ZRZFishing.begin(s,p);if(!begun.ok){toast(begun.msg,true);return;}startAction(begun.spec,p,()=>apply(window.ZRZFishing.finish(s)),()=>window.ZRZFishing.cancel(s));return;}
    if(!performed){const spec=Actions.point(p,tool);if(spec){startAction(spec,p,()=>interact(p,true));return;}}
    if(p.kind==='build-task'){const r=B.perform(s,p);if(r.ok)V.feedback(s,p,p.op?.startsWith('economy-')?'harvest':'hoe',r.msg,1.7);apply(r);return;}
    if(p.kind==='build-piece'){if(p.service==='water'){const r=F.fillWater(s);V.feedback(s,p,'water',r.msg,1.5);apply(r);}else if(p.service==='rest'){V.feedback(s,p,'steam','在自己的小院里歇一歇。',1.5);apply(C.rest(s));}else if(p.service)openPanel(p.service);else{V.feedback(s,p,'spark','这处小景，是你亲手安置的。',1.5);sound('soft');}return;}
    if(p.kind==='kitchen-station'){if(['stove','steam'].includes(p.station))openPanel('cook',{tab:'recipes'});else openPanel('processing',{station:p.station});return;}
    if(p.kind==='kitchen-task'){if(s.village.interior!==K.house().id){queueKitchen(p);return;}if(p.op==='manual'){openPanel('kitchen-heat',p);return;}const r=K.perform(s,p);if(r.ok)V.feedback(s,p,'steam',r.msg,2,p.op==='make'||p.op==='sub'?p.id:null);apply(r);return;}
    if(p.kind==='ranch-task'){if(p.animalId){const a=s.animals.find(a=>a.id===p.animalId),actual=a&&R.point(s,a);if(!actual||Math.hypot(actual.x-s.player.x,actual.y-s.player.y)>70){ranchQueue.unshift(p);advanceRanch();return;}p={...p,x:actual.x,y:actual.y};}const r=R.perform(s,p);if(r.ok){const a=s.animals.find(a=>a.id===p.animalId);V.feedback(s,p,p.action==='collect'?'harvest':p.action==='feed'?'feed':p.action==='clean'?'brush':'pet',r.msg,1.3,p.action==='collect'?a?.product:null);ranchCompleted++;save();update();sound('good');}else{ranchQueue=[];kitchenTask=null;buildTask=null;toast(r.msg+' 本批停止，已完成 '+ranchCompleted+' 次。',true);}ranchNextAt=frameTime+1.1;if(!ranchQueue.length&&r.ok)toast(r.msg);return;}
    if(p.kind==='farm-task'){const before=s.plots[p.index].crop,r=p.action==='inspect'?{ok:true,msg:F.advice(s,p.index).join('；')}:p.action==='facility'?F.facility(s,p.index,p.arg.type,p.arg.mode,p.arg.target):p.action==='fill'?F.fillWater(s):F.perform(s,p.index,p.action,p.arg);if(r.ok){const kind=['harvest','seedSave','companionHarvest'].includes(p.action)?'harvest':p.action==='water'||p.action==='fill'?'water':p.action==='sow'||p.action==='companion'?'seed':'hoe';V.feedback(s,p,kind,r.msg,1.2,kind==='harvest'?before:null);farmCompleted++;save();update();sound('good');}else{toast(r.msg+' 已完成 '+farmCompleted+' 块，本批停止。',true);farmQueue=[];}farmNextAt=frameTime+.85;if(!farmQueue.length&&r.ok)toast('农事完成 · '+farmCompleted+' 次。'+r.msg);return;}
    if(p.kind==='npc'){const actual=V.npcPoint(s,D.npcs.find(n=>n.id===p.id));if(!actual){navigate(V.destination(s,'npc',p.id));return;}if(Math.hypot(actual.x-s.player.x,actual.y-s.player.y)>70){walkTo(actual);return;}lastDialogue=C.talk(s,p.id).msg;V.feedback(s,actual,'greet',lastDialogue,1.2);save();update();sound('soft');openPanel('npc',p.id);return;}
    if(p.kind==='enter'||p.kind==='exit'){const ok=p.kind==='enter'?V.enter(s,p.house):V.leave(s);if(ok){path=[];pending=null;hovered=null;camera.update(s,0,true);save();update();sound('soft');if(queuedDestination){const target=queuedDestination;queuedDestination=null;walkTo(target);}}return;}
    if(p.kind==='walk'){V.feedback(s,s.player,'spark','走到了。慢慢看看周围吧。');return;}
    if(p.kind==='egg'){const r=V.inspect(s,p);if(r.ok){sound(p.name.match(/声|琴|铃|曲|录音/)?'music':'good');save();update();}return;}
    if(p.kind==='chore'&&p.action==='churn'){queueKitchen({op:'process',id:'cream',n:1,station:'dairy'});return;}
    if(p.kind==='chore'){const r=V.chore(s,p);if(r.ok){sound('good');save();update();}else toast(r.msg,true);return;}
    if(p.kind==='ambient'){V.feedback(s,p,p.action==='river'?'bell':'wind','手边的小物件，也有自己的声响。',2);sound('soft');return;}
    if(p.kind==='tea'||p.kind==='bed-visit'){s.stamina=Math.min(100,s.stamina+8);V.feedback(s,p,'steam',p.kind==='tea'?'倒一杯热茶，暖一暖手。':'把坐垫抚平，再轻轻放回原位。',2);save();update();sound('soft');return;}
    if(p.kind==='plot'&&['hoe','water','sickle'].includes(tool)){const tasks=T.plan(s,p.index,tool);if(tasks.length)queueFarm(tasks);else toast('范围内暂无适用田块：锄头整理空地，水壶照料缺水田，镰刀收下成熟作物。',true);return;}
    if(p.kind==='plot'){const crop=s.plots[p.index].crop,r=C.plotAction(s,p.index,tool);if(r.ok)V.feedback(s,p,tool==='hand'?'harvest':tool,r.msg,.9,tool==='hand'?crop:null);apply(r);return;}
    if(p.kind==='animal'){const a=s.animals.find(a=>a.id===p.id);if(!a)return;queueRanch([{animalId:a.id,action:a.ready||a.feathers?'collect':a.hunger<90&&a.care.feed!==s.day?'feed':'pet',arg:s.ranch.feed}]);return;}
    if(p.kind==='forage-care'){apply(window.ZRZForage.care(s,p.id));return;}
    if(p.kind==='gather'){const r=C.gather(s,p.id,p.item);if(r.ok)V.feedback(s,p,'gather',r.msg,1.2,p.item);apply(r);return;}
    if(p.kind==='rest'){const r=C.rest(s);V.feedback(s,p,'steam','坐一坐，看看眼前的日子。',2);apply(r);return;}
    if(p.kind==='fish'){const before={...s.bag},r=C.fish(s),caught=Object.keys(s.bag).find(id=>s.bag[id]>(before[id]||0));if(r.ok)V.feedback(s,p,'harvest',r.msg,.8,caught);apply(r);return;}
    if(p.kind==='pet'){const r=C.pet(s);V.feedback(s,p,'pet',r.msg,1.2);apply(r);return;}
    if(p.kind==='story')openPanel('stories');else openPanel(p.kind);
  }
  function nearest(){
    const pts=W.points(s);if(!s.village.interior)for(let i=0;i<s.plots.length;i++)pts.push({kind:'plot',index:i,...W.plotPosition(i),name:'照料菜地'});
    return selection.choose(s,pts,hovered,tool);
  }
  function cycleTarget(direction=1){nearest();const next=selection.cycle(direction);if(next){hovered=null;pointer=null;toast('当前目标：'+Feedback.describe(s,next,tool).name);} }

  function setTool(id){selection.clear();tool=id;T.equipped=id;update();sound();if(id==='build')openPanel('decor');}
  document.addEventListener('click',e=>{
    const b=e.target.closest('[data-action]');if(!b||b.disabled||inputLocked)return;const a=b.dataset.action,id=b.dataset.id;
    if(a==='fb-confirm'){if(currentPanel!=='feedback-confirm'||!guard||Number(id)!==guard.nonce)return;const run=guard.perform;guard=null;run();return;}
    if(a==='fb-cancel'){const back=guard?.back;guard=null;back?openPanel(back.name,back.arg):closePanel();return;}
    if(a==='fb-cycle'){cycleTarget();return;}if(a==='fb-interact'){const p=nearest();if(p)interact(p);return;}
    if(a==='v-walk-activity'){navigate(V.outdoorActions.find(p=>p.id===id));return;}
    if(a==='v-walk-region'){navigate(V.destination(s,'region',id));return;}if(a==='v-walk-house'){navigate(V.destination(s,'house',id));return;}if(a==='v-npc-talk'){queueNeighbor(id,'talk',{topic:'auto'});return;}if(a==='v-npc-gift'){openPanel('gifts',id);return;}if(a==='v-bike'){if(s.village.interior){toast('先走出小屋再骑车。');return;}s.village.riding=!s.village.riding;update();return;}if(a==='v-stop'){path=[];pending=null;queuedDestination=null;farmQueue=[];ranchQueue=[];kitchenTask=null;buildTask=null;return;}
    if(window.ZRZ_DEV&&a==='debug'){openPanel('debug');return;}
    if(X.dispatch(a,id,b.dataset,{s,apply,open:openPanel,render:()=>renderPanel(currentPanel,panelArg),save,update,toast,close:closePanel,queueFarm,queueRanch,queueKitchen,queueBuild,queueNeighbor,navigate,equipTool:setTool,equipSeed:()=>setTool('seed')}))return;
    if(a==='walk-landmark'){const point=W.points(s).find(p=>p.id===id);closePanel();if(point)walkTo(point);return;}
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
    if(a==='find-npc'){navigate(V.destination(s,'npc',id));return;}
    if(a==='sell-panel'){inventoryFilter='全部';openPanel('sell');return;}
    if(a==='buy')apply(C.buy(s,id,Number(b.dataset.qty)),true);
    if(a==='sell-item')apply(C.sell(s,id,1),true);if(a==='sell-all')apply(C.sell(s,id,s.bag[id]||0),true);
    if(a==='eat')apply(C.eat(s,id),true);
    if(a==='choose-seed'){if(!id||!D.crops[id]){openPanel('seeds');return;}s.farm.seedKind='normal';s.seed=id;setTool('seed');closePanel();save();toast('选好了'+D.crops[id].name+'种子。点击松好的菜地播种。');}
    if(a==='cook-item'){const r=C.cook(s,id,Number(b.dataset.qty));if(r.ok)V.feedback(s,s.player,'steam','灶火与热气一起升起来。',2);apply(r,true);}
    if(a==='gift-list')openPanel('gifts',id);
    if(a==='gift-item')apply(C.gift(s,b.dataset.npc,id),true);
    if(a==='deliver')apply(C.deliver(s,id),true);
    if(a==='repair')apply(C.repair(s),true);
    if(a==='upgrade')apply(C.upgrade(s,id),true);
    if(a==='join-festival')apply(C.festival(s,id),true);
    if(a==='cal-season'){calSeason=Number(id);renderPanel('calendar');}
    if(a==='next-day'){closePanel();apply(C.nextDay(s));path=[];pending=null;hovered=null;camera.update(s,0,true);if(s.day%112===0)openPanel('year');else announceScene();}
    if(a==='save-slot'){const write=()=>{if(save(id,false)){openPanel('save');toast('已保存到手动档 '+id+'。');}};const raw=readSave(SAVE+'-'+id);if(raw){let meta='此位置已有一份记录';try{const prior=C.load(raw),date=C.calendar(prior);meta=prior.name+' · 第 '+date.year+' 年 '+D.seasons[date.season]+' '+date.date+' 日 · '+prior.money+' 元';}catch(_){}askGuard('覆盖手动存档 '+id+'？','将替换：'+meta+'。当前这一天会写入该位置，其余手动槽保持原记录。','覆盖这个存档',write);}else write();return;}
    if(a==='load-slot'){askGuard('读取这份日子？','将回到所选记录。读取前，会用当前进度替换“读取前的回退档”，以后可从存档页找回这一次的进度。','保存回退档并读取',()=>{try{const next=C.load(readSave(SAVE+'-'+id));if(!save('recovery')){toast('回退档未能保存，先导出当前进度再读取。',true);return;}s=next;selection.clear();W.restorePosition(s);closePanel();path=[];pending=null;hovered=null;camera.update(s,0,true);save();update();toast('回到了上次记下的日子。');}catch(err){toast(err.message,true);}});return;}
    if(a==='export'){K.ensure(s);const blob=new Blob([JSON.stringify(C.load(s),null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download='种日子-第'+C.calendar(s).year+'年-'+D.seasons[C.calendar(s).season]+C.calendar(s).date+'日.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),2000);toast('存档已交给浏览器下载。');}
    if(a==='import')$('import-file').click();
    if(a==='fullscreen')fullscreen();
    if(a==='new-confirm')openPanel('new-confirm');
    if(a==='new-game'){save('backup');s=C.initial();path=[];pending=null;hovered=null;tool='hand';openPanel('welcome');update();}
  });
  document.addEventListener('change',e=>{if(e.target.dataset.uiArt){if(window.ZRZUIArt.set(s,e.target.dataset.uiArt,e.target.value)){save();update();}return;}if(e.target.dataset.feedbackPref){if(Feedback.preference(s,e.target.dataset.feedbackPref,e.target.value)){save();update();}return;}if(e.target.dataset.extraSetting){const key=e.target.dataset.extraSetting;s.settings[key]=['textScale','music','ambient','effects'].includes(key)?Number(e.target.value):e.target.value;save();update();return;}if(e.target.id==='speed-setting'){s.settings.speed=e.target.value;save();update();}if(e.target.id==='volume-setting'){s.settings.volume=Number(e.target.value);save();sound();}if(e.target.id==='zoom-setting'){s.settings.zoom=Number(e.target.value);camera.update(s,0,true);save();update();}});
  $('import-file').addEventListener('change',async e=>{const file=e.target.files[0];if(!file)return;try{if(file.size>2e6)throw new Error('存档文件过大，请选择本游戏导出的 JSON。');const next=C.load(await file.text());save('backup');s=next;W.restorePosition(s);path=[];pending=null;hovered=null;closePanel();save();update();toast('存档已经带回来了，欢迎继续生活。');}catch(err){toast(err.message||'无法读取这份存档。',true);}finally{e.target.value='';}});
  $('modal-overlay').addEventListener('click',e=>{if(e.target===$('modal-overlay'))closePanel();});
  function hoverInfo(){const box=$('hover-card');if(!hovered||currentPanel||inputLocked){box.hidden=true;return;}const info=Feedback.describe(s,hovered,tool);box.innerHTML='<strong>'+escape(info.name)+'</strong><small>'+escape(info.state)+'<br>'+escape(info.reason||info.verb)+(info.detail?'<br>'+escape(info.detail):'')+'<br>点击走近 · '+keyLabel('interact')+' 交互</small>';box.hidden=false;}

  function coords(e){const r=$('world').getBoundingClientRect();return camera.toWorld(e.clientX-r.left,e.clientY-r.top);}
  function positionHover(){if(!pointer)return;const box=$('hover-card'),v=camera.view;box.style.left=Math.max(8,Math.min(v.width-box.offsetWidth-12,pointer.x+20))+'px';box.style.top=Math.max(8,Math.min(v.height-box.offsetHeight-150,pointer.y+23))+'px';}
  $('world').addEventListener('pointermove',e=>{const r=$('world').getBoundingClientRect();selection.manual='';pointer={x:e.clientX-r.left,y:e.clientY-r.top};const p=coords(e);hovered=W.hit(s,p.x,p.y);hoverInfo();positionHover();});
  $('world').addEventListener('pointerleave',()=>{hovered=null;pointer=null;hoverInfo();});
  $('world').addEventListener('pointerdown',e=>{if(currentPanel||inputLocked)return;queuedDestination=null;farmQueue=[];ranchQueue=[];kitchenTask=null;buildTask=null;e.preventDefault();$('world').focus();sound('soft');const p=coords(e),hit=W.hit(s,p.x,p.y);if(hit&&Math.hypot(hit.x-s.player.x,hit.y-s.player.y)<53){path=[];pending=null;interact(hit);return;}const target=hit?Actions.approach(s,hit):p;path=W.route(s,target.x,target.y);pending=path.length?hit:null;if(!path.length)toast('这里走不过去，试试旁边的小路。');});
  document.addEventListener('keydown',e=>{
    if(capturing){e.preventDefault();if(e.key==='Escape'){capturing=null;renderPanel('controls');return;}const key=e.key.toLowerCase();if(!C.bindingKeyAllowed(key)){toast('请选择字母键；C、F、H、Q 是固定功能键。',true);return;}const old=s.settings.bindings[capturing],other=Object.keys(s.settings.bindings).find(k=>s.settings.bindings[k]===key);if(other)s.settings.bindings[other]=old;s.settings.bindings[capturing]=key;capturing=null;save();update();renderPanel('controls');toast('按键已经换好了，下次打开也会记住。');return;}
    if(e.key==='Tab'&&currentPanel){const focusable=[...$('modal').querySelectorAll('button:not([disabled]):not([hidden]),input,select,summary')].filter(el=>el.offsetParent!==null);if(!focusable.length)return;const first=focusable[0],last=focusable.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}return;}
    if(e.key==='Escape'){e.preventDefault();if(sequence.active){cancelAction();return;}currentPanel?closePanel():openPanel('menu');return;}
    if(currentPanel||inputLocked||['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName))return;
    if(e.ctrlKey||e.metaKey||e.altKey)return;
    if(e.key===' '&&document.activeElement.closest('button'))return;
    const key=e.key.toLowerCase(),bindings=s.settings.bindings;
    if([...Object.values(bindings),'arrowup','arrowdown','arrowleft','arrowright',' ','1','2','3','4','5','6','7','8','tab','c','q','f','h'].includes(key))e.preventDefault();
    if(key==='shift')keys.add(key);
    if([bindings.up,bindings.left,bindings.down,bindings.right,'arrowup','arrowdown','arrowleft','arrowright'].includes(key)){keys.add(key);path=[];pending=null;queuedDestination=null;farmQueue=[];ranchQueue=[];kitchenTask=null;buildTask=null;}
    if(e.repeat)return;
    if(key==='['||key===']'){e.preventDefault();cycleTarget(key==='['?-1:1);return;}
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
    padX=0;padY=0;if(!s.settings.gamepad||document.hidden)return;
    const pad=[...(navigator.getGamepads?.()||[])].find(p=>p?.connected);if(!pad){padPrevious=[];return;}
    const down=i=>!!pad.buttons[i]?.pressed,press=i=>down(i)&&!padPrevious[i];if(inputLocked){if(press(1))cancelAction();padPrevious=pad.buttons.map(b=>b.pressed);return;}if(press(0)||press(1)||press(10)||Math.abs(pad.axes[0]||0)>.2||Math.abs(pad.axes[1]||0)>.2)inputMode='pad';
    if(currentPanel){
      if(press(1)||press(9)){closePanel();}
      else{const focus=document.activeElement,horizontal=press(15)?1:press(14)?-1:0;if(horizontal&&focus?.tagName==='SELECT'){focus.selectedIndex=(focus.selectedIndex+horizontal+focus.options.length)%focus.options.length;focus.dispatchEvent(new Event('change',{bubbles:true}));}else if(horizontal&&focus?.matches('input[type=range],input[type=number]')){const step=Number(focus.step)||1;focus.value=String(Math.max(Number(focus.min)||0,Math.min(Number(focus.max)||999999,Number(focus.value)+horizontal*step)));focus.dispatchEvent(new Event('change',{bubbles:true}));}
        const direction=down(13)?1:down(12)?-1:Math.abs(pad.axes[1]||0)>.5?Math.sign(pad.axes[1]):0;
        if(direction&&now>padMenuAt){padMenuAt=now+190;const list=[...$('modal').querySelectorAll('button:not([disabled]),input,select,summary')].filter(el=>el.offsetParent!==null),i=list.indexOf(document.activeElement);if(list.length){const next=list[(i+direction+list.length)%list.length];next.focus();next.scrollIntoView({block:'nearest'});}}
        if(press(0)&&document.activeElement?.matches('button:not([disabled]),input[type=checkbox],summary'))document.activeElement.click();
      }
    }else{
      padX=(Math.abs(pad.axes[0]||0)>.2?pad.axes[0]:0)+(down(15)?1:0)-(down(14)?1:0);padY=(Math.abs(pad.axes[1]||0)>.2?pad.axes[1]:0)+(down(13)?1:0)-(down(12)?1:0);
      if(padX||padY){path=[];pending=null;queuedDestination=null;farmQueue=[];ranchQueue=[];kitchenTask=null;buildTask=null;}
      if(press(10))cycleTarget();if(press(0)){const point=nearest();if(point)interact(point);}
      if(press(2))openPanel('bag');if(press(3))openPanel('map');if(press(9)||press(1))openPanel('menu');
      if(press(4)||press(5)){const i=tools.findIndex(t=>t.id===tool),next=(i+(press(5)?1:-1)+tools.length)%tools.length;setTool(tools[next].id);}
    }
    padPrevious=pad.buttons.map(b=>b.pressed);
  }
  function move(dt){if(buildTask&&!path.length&&!pending&&!queuedDestination)advanceBuild();if(kitchenTask&&!path.length&&!pending&&!queuedDestination)advanceKitchen();if(ranchQueue.length&&!path.length&&!pending&&!queuedDestination&&frameTime>=ranchNextAt)advanceRanch();if(farmQueue.length&&!path.length&&!pending&&!queuedDestination&&frameTime>=farmNextAt)advanceFarm();if(['npc','animal'].includes(pending?.kind)&&frameTime>chaseAt){chaseAt=frameTime+.7;const target=V.destination(s,pending.kind,pending.id);if(target&&Math.hypot(target.x-pending.x,target.y-pending.y)>30){path=W.route(s,target.x,target.y+5);pending=target;}}const bindings=s.settings.bindings;let dx=(keys.has(bindings.right)||keys.has('arrowright')?1:0)-(keys.has(bindings.left)||keys.has('arrowleft')?1:0),dy=(keys.has(bindings.down)||keys.has('arrowdown')?1:0)-(keys.has(bindings.up)||keys.has('arrowup')?1:0);const speed=(s.village.riding?355:keys.has('shift')?265:195)*(K.activeBuff(s)?.kind==='轻快'?1.12:1)*(window.ZRZEnvironment?.speed(s)||1)*dt;
    dx+=padX;dy+=padY;
    if(path.length&&!dx&&!dy){const n=path[0],dist=Math.hypot(n.x-s.player.x,n.y-s.player.y);if(dist<=speed){s.player.x=n.x;s.player.y=n.y;path.shift();if(!path.length&&pending){const p=pending;pending=null;interact(p);}return true;}dx=(n.x-s.player.x)/dist;dy=(n.y-s.player.y)/dist;}
    const norm=Math.hypot(dx,dy);if(!norm)return false;dx=dx/norm*speed;dy=dy/norm*speed;const p=s.player;
    if(Math.abs(dx)>Math.abs(dy))p.direction=dx>0?'right':'left';else p.direction=dy>0?'down':'up';
    if(!W.blocked(s,p.x+dx,p.y))p.x+=dx;if(!W.blocked(s,p.x,p.y+dy))p.y+=dy;return true;
  }
  function frame(now){diagnostics.frames++;pollGamepad(now);const dt=Math.min(.05,(now-(lastTime||now))/1000);lastTime=now;frameTime=now/1000;
    if(!currentPanel&&!document.hidden&&V.update(s,dt)){diagnostics.sceneChanges++;update();}
    if(!currentPanel&&!document.hidden&&!inputLocked){walking=move(dt);s.minutes=Math.min(1320,s.minutes+dt*(s.settings.speed==='normal'?1.55:1.04));tick+=dt;if(tick>1){tick=0;update();if(s.minutes>=1320)openPanel('sleep');}ambient(frameTime);}else walking=false;
    window.ZRZFishing?.tick(s,dt,document.hidden);sequence.tick(dt,document.hidden);sceneFade=Math.max(0,sceneFade-dt);
    camera.update(s,dt);if(frameTime>feedbackPollAt&&!document.hidden){feedbackPollAt=frameTime+4;const added=Feedback.poll(s);if(added.length){save();update();const first=added.slice().sort((a,b)=>b.priority-a.priority)[0];toast(first.title+' · '+first.text+(added.length>1?'（另有 '+(added.length-1)+' 条，回响里可查看）':''),false,true);}}
    if(pointer&&!currentPanel){const point=camera.toWorld(pointer.x,pointer.y);hovered=W.hit(s,point.x,point.y);hoverInfo();positionHover();}
    const feedbackTarget=!currentPanel&&!inputLocked?nearest():null;
    const renderStart=performance.now();V.stateRuntime(s).sequence=sequence.snapshot();T.equipped=tool;W.draw(camera.buffer,s,frameTime,hovered,walking,effect,camera.view);

    if(path.length){const c=camera.buffer.getContext('2d');c.save();c.translate(-camera.view.x,-camera.view.y);c.fillStyle='#fff3b8a0';path.forEach((p,i)=>{if(i%2===0)c.fillRect(Math.round(p.x)-1,Math.round(p.y)-1,2,2);});const dest=path[path.length-1],radius=7+Math.sin(frameTime*5)*2;c.strokeStyle='#fff0ab';c.lineWidth=1.5;c.beginPath();c.ellipse(dest.x,dest.y,radius,radius*.5,0,0,Math.PI*2);c.stroke();c.restore();}
    Feedback.draw(camera.buffer.getContext('2d'),s,currentPanel||document.hidden?0:dt,feedbackTarget,tool,camera.view);
    camera.paint();W.drawLabels?.($('world'),s,camera.view);diagnostics.renderMs=Math.round((performance.now()-renderStart)*100)/100;diagnostics.averageRenderMs=Math.round(((diagnostics.averageRenderMs||diagnostics.renderMs)*.95+diagnostics.renderMs*.05)*100)/100;
    drawJourney(dt);
    const near=feedbackTarget,info=near&&Feedback.describe(s,near,tool),prompt=$('interaction-prompt');prompt.hidden=false;prompt.classList.toggle('visible',!!near);prompt.setAttribute('aria-hidden',String(!near));if(near){const point=camera.toScreen(near.scenery?near.x:s.player.x,near.scenery?near.top-10:s.player.y-43);prompt.style.left=Math.max(125,Math.min(camera.view.width-125,point.x))+'px';prompt.style.top=Math.max(110,Math.min(camera.view.height-145,point.y))+'px';prompt.classList.toggle('unavailable',!info.ready);prompt.innerHTML='<kbd>'+(inputMode==='pad'?'A':inputMode==='touch'?'点按':keyLabel('interact'))+'</kbd><strong>'+escape(info.verb+' · '+info.name)+'</strong><small>'+escape(info.reason||info.state)+(info.detail?'<br>'+escape(info.detail):'')+'</small>';}

    updateContext(near);
    requestAnimationFrame(frame);
  }
  const contextual=document.createElement('div');contextual.id='context-actions';document.getElementById('game-hud').appendChild(contextual);let contextKey='',inputMode='keyboard';
  document.addEventListener('keydown',()=>inputMode='keyboard');$('world').addEventListener('pointerdown',e=>inputMode=e.pointerType==='touch'?'touch':'keyboard');
  const feedbackButton=document.createElement('button');feedbackButton.id='feedback-button';feedbackButton.dataset.action='feedback';feedbackButton.textContent='回响';feedbackButton.setAttribute('aria-label','打开手边回响');document.querySelector('.quiet-corner').prepend(feedbackButton);
  function updateContext(near){const key=(currentPanel?'menu':near?.kind+'/'+(near?.id??near?.index))+'/'+inputLocked+'/'+s.village.riding+'/'+!!path.length+'/'+selection.options.length+'/'+inputMode+'/'+tool+'/'+(near?Feedback.describe(s,near,tool).verb:'');if(key!==contextKey){contextKey=key;contextual.hidden=!!currentPanel||inputLocked;let html='';if(near?.kind==='plot')html=button('查看这块田','f-inspect',String(near.index),'context-btn')+button('四时农事','farmcare','','context-btn');else if(near?.kind==='animal')html=button('看看这位伙伴','r-open',near.id,'context-btn')+button('喂一份','r-task',near.id,'context-btn','data-op="feed"')+button('摸摸它','r-task',near.id,'context-btn','data-op="pet"');else if(near?.kind==='fish')html=button('鱼饵与垂钓手记','fishing','','context-btn');else if(near?.kind==='gather')html=button('采法与山野手记','forage','','context-btn');else if(near?.kind==='npc')html=button('继续聊聊','v-npc-talk',near.id,'context-btn')+button('送份心意','v-npc-gift',near.id,'context-btn')+button('去他家看看','v-walk-house',V.homeOf(near.id).id,'context-btn');else if(!s.village.interior)html=button(s.village.riding?'下车慢慢走':'骑自行车','v-bike','','context-btn');if(path.length)html+='<span id="walk-progress"></span>'+button('停止带路','v-stop','','context-btn');if(near)html='<button class="context-btn" data-action="fb-interact">'+escape(Feedback.describe(s,near,tool).verb)+'</button>'+html;if(selection.options.length>1)html+=button('换目标 · '+(inputMode==='pad'?'L3':inputMode==='touch'?'点按':'[ / ]'),'fb-cycle','','context-btn');contextual.innerHTML=html;}
    if(path.length){let dist=0,last=s.player;for(const p of path){dist+=Math.hypot(p.x-last.x,p.y-last.y);last=p;}const el=$('walk-progress');if(el)el.textContent=(queuedDestination?'先出门':pending?.name||'前往标记')+' · 约 '+Math.max(1,Math.ceil(dist/(s.village.riding?355:195)))+' 秒';}
  }
  const journey=document.createElement('div');journey.id='journey-hud';journey.innerHTML='<button id="mini-toggle" data-action="map" aria-label="打开行路地图"><canvas id="mini-map" width="264" height="106"></canvas><span id="mini-title"></span></button><div id="route-compass" hidden></div>';document.getElementById('game-hud').appendChild(journey);
  const actionHud=document.createElement('div');actionHud.id='action-progress';actionHud.hidden=true;actionHud.innerHTML='<span id="action-label"></span><div id="action-meter" role="progressbar" aria-label="动作进度" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0"><i id="action-fill"></i></div><small id="action-phase"></small><button id="action-cancel" aria-label="取消当前动作">停下 · Esc</button>';document.getElementById('game-root').appendChild(actionHud);
  const fade=document.createElement('div');fade.id='door-fade';fade.hidden=true;document.getElementById('game-root').appendChild(fade);
  $('action-cancel').addEventListener('click',cancelAction);
  function drawJourney(dt){const a=sequence.snapshot();actionHud.hidden=!a;if(a){$('action-label').textContent=a.label;$('action-cancel').textContent='停下 · '+(inputMode==='pad'?'B':inputMode==='touch'?'点按':'Esc');$('action-fill').style.width=(a.progress*100)+'%';$('action-meter').setAttribute('aria-valuenow',Math.round(a.progress*100));$('action-phase').textContent=a.phase+' · 完成后结算';}
    const darkness=Feedback.ensure(s).prefs.motion==='reduced'?0:a?.door?Math.max(0,(a.progress-.6)/.4)*.7:a?.kind==='sleep'?Math.sin(a.progress*Math.PI)*.6:sceneFade/ .3*.7;fade.hidden=!darkness;fade.style.opacity=darkness||0;
    journey.hidden=true;miniAt-=dt;if(miniAt<=0&&!journey.hidden){miniAt=.3;const target=S.resolve(s,s.atlas.tracking);S.drawMap($('mini-map').getContext('2d'),s,{mini:true,path:s.village.interior?[]:path,selected:target,view:camera.view});$('mini-title').textContent=S.scope(s).name+(s.village.interior?' · 屋内':' · 点开地图');}
    const target=path.length?path[path.length-1]:S.resolve(s,s.atlas.tracking),indicator=$('route-compass');indicator.hidden=!target||!!s.village.interior;if(target){const dx=target.x-s.player.x,dy=target.y-s.player.y;indicator.textContent=(Math.abs(dx)>Math.abs(dy)?dx>0?'向东 →':'← 向西':dy>0?'向南 ↓':'向北 ↑')+' · '+(pending?.name||target.name||'地图目标')+(path.length?' · 行进中':' · 地图可继续带路');}
  }
  document.addEventListener('click',e=>{if(e.target.id!=='area-map'||inputLocked)return;const r=e.target.getBoundingClientRect(),x=(e.clientX-r.left)/r.width*V.WIDTH,y=(e.clientY-r.top)/r.height*V.HEIGHT;S.pick(s,S.clickPoint(s,x,y,s.atlas.layer));renderPanel('map');});
  // Hide the panel without discarding its form values, show the world action, then dispatch once.
  document.addEventListener('click',e=>{const b=e.target.closest('[data-action]');if(!b||b.disabled||replayUI)return;if(inputLocked){e.stopImmediatePropagation();e.preventDefault();return;}if(['v-npc-talk','e-story-choice'].includes(b.dataset.action))return;const spec=Actions.ui(b.dataset.action,b.textContent.trim());if(!spec)return;
    e.stopImmediatePropagation();e.preventDefault();const prior=currentPanel,arg=panelArg,scroll=$('modal-body').scrollTop;
    if(b.dataset.action==='k-finish')b.dataset.actionHeat=parseFloat($('k-needle')?.style.left)||0;
    closePanel();path=[];pending=null;queuedDestination=null;farmQueue=[];ranchQueue=[];kitchenTask=null;buildTask=null;
    const restore=()=>{if(prior){currentPanel=prior;panelArg=arg;$('modal-overlay').hidden=false;$('game-root').classList.add('menu-open');$('modal-body').scrollTop=scroll;}};
    const giftTarget=prior==='gifts'?V.npcPoint(s,D.npcs.find(n=>n.id===arg)):null;
    startAction({...spec,item:b.dataset.id},giftTarget||s.player,()=>{currentPanel=prior;panelArg=arg;replayUI=true;try{b.click();}finally{replayUI=false;delete b.dataset.actionHeat;}if(currentPanel){$('modal-overlay').hidden=false;$('game-root').classList.add('menu-open');$('modal-body').scrollTop=scroll;}},restore);
  },true);
  W.restorePosition(s);camera.update(s,0,true);update();requestAnimationFrame(frame);
  if(!s.flags.introDone)openPanel('welcome');else if(startupNotice)toast(startupNotice,true);
  // Read-only snapshot for diagnostics; state mutations stay inside the game.
  window.ZRZSnapshot=()=>JSON.parse(JSON.stringify(s));
  window.ZRZView=()=>({...camera.view});
  window.ZRZDiagnostics=()=>JSON.parse(JSON.stringify({...diagnostics,action:sequence.snapshot(),navigation:{remaining:path.length,pending:pending?.kind||null},cache:window.ZRZVillageView.cacheStats()}));
  if(window.ZRZ_DEV)window.ZRZDeveloper={replace(next){s=C.load(next);W.restorePosition(s);save();update();camera.update(s,0,true);openPanel('debug');},state:()=>C.load(s),walk:travel,open:()=>openPanel('debug')};
})();

