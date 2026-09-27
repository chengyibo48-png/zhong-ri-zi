(function(root){
  'use strict';
  const D=root.ZRZData,C=root.ZRZCore;
  const panels=['storage','processing','stories','story','projects','decor','skills','archive','mail','home','wedding','separation','animals','farmcare','tools','appearance','gatherings','catalog'];
  const ui={recipe:'全部',npc:'全部',catalog:'作物',furniture:'bench',festival:null};
  let typeTimer=null;
  const val=id=>document.getElementById(id)?.value;
  function render(name,arg,s,A){
    const {head,button:b,itemCanvas:ic,ingredients:needs,escape:e}=A;
    const row=(title,body,actions='',icon='')=>'<article class="row-card">'+(icon?ic(icon):'')+'<div class="row-text"><h3>'+title+'</h3>'+body+'</div><div class="row-actions">'+actions+'</div></article>';
    const select=(id,options)=>'<select id="'+id+'">'+options.map(([k,v])=>'<option value="'+e(k)+'">'+e(v)+'</option>').join('')+'</select>';
    const dishes=Object.entries(s.bag).filter(([id,n])=>n>0&&D.items[id].kind==='料理').map(([id,n])=>[id,D.items[id].name+' ×'+n]);
    const qtext=id=>{const q=s.quality[id]||[];return q.some(n=>n>0)?' · 优质 '+(q[0]||0)+' / 上品 '+(q[1]||0)+' / 珍品 '+(q[2]||0):'';};
    const source=r=>r.source==='known'?'爷爷留下的家常配方':r.source==='market'?'杂货铺手写配方':r.source.startsWith('festival')?D.festivals[Number(r.source.slice(-1))]+' / 赶集配方摊':(D.npcs.find(n=>n.id===r.source)?.name||'邻居')+'熟悉后传授 / 赶集配方摊';
    if(name==='recipes'||name==='cook'){
      let h=head(name==='cook'?'灶火正暖，做点家常。':'三十道菜，三十次相聚。','已掌握 '+s.knownRecipes.length+' / '+D.recipes.length+' 道 · 6 种厨房工序 · 做菜、便当、家宴和节令各有用处。');
      h+='<div class="tabs">'+['全部','日常恢复','田间便当','待客家宴','节令食品','未学会'].map(k=>b(k,'e-recipe-filter',k,ui.recipe===k?'active':'')).join('')+'</div>';
      h+=D.recipes.filter(r=>ui.recipe==='全部'||ui.recipe==='未学会'&&!s.knownRecipes.includes(r.id)||r.category===ui.recipe).map(r=>{const known=s.knownRecipes.includes(r.id),station=C.canUseStation(s,r.station),sub=C.recipeNeeds(s,r,true),can=C.has(s,r.ingredients);let actions=known?(name==='cook'?b('做 1 份','cook-item',r.id,'mini-btn','data-qty="1" '+(!can||!station?'disabled':''))+b('做 3 份','cook-item',r.id,'mini-btn','data-qty="3" '+(!C.has(s,r.ingredients,3)||!station?'disabled':''))+(!can&&C.has(s,sub)?b('用替代食材做','e-sub-cook',r.id,'mini-btn',station?'':'disabled'):''):b('去小厨房','go-kitchen','','mini-btn')):b('购配方 · 35 元','e-recipe-buy',r.id,'mini-btn',r.source!=='market'&&!C.market(s).open?'disabled':'');return row(D.items[r.id].name+' <span class="tag">'+(known?r.category:'尚未掌握')+'</span>','<p>'+r.story+'<br>'+r.station+' · 体力 +'+D.items[r.id].energy+(r.category==='田间便当'?' · 食用后当日劳动消耗 −1':'')+'<br>来源：'+source(r)+'</p>'+needs(r.ingredients)+(!station?'<p class="missing">需要添置'+r.station+'。</p>':''),actions,r.id);}).join('');
      if(name==='cook'){const foods=Object.entries(s.bag).filter(([id,n])=>n>0&&['食材','加工物'].includes(D.items[id].kind)).map(([id,n])=>[id,D.items[id].name+' ×'+n]);h+='<div class="section-divider">试做发现 · 搭配两种食材</div><p>选择食材试推配方；不成功保留食材。相同食材需要两份。学会后按菜谱用量制作。</p><div class="form-inline">'+select('trial-first',foods)+select('trial-second',foods)+b('试试这个搭配','e-trial')+'</div>';}
      h+='<div class="button-row">'+b('加工工序','processing','','secondary')+b('邀请来吃饭','home','','secondary')+'</div>';return h;
    }
    if(name==='processing'){
      let h=head('晾晒、磨粉，也留一点等待。','短工序，不绕远路。批量最多 20 批；次日完成的产物会自动收入背包。');
      h+='<div class="form-inline"><label>批数 <input id="process-count" type="number" min="1" max="20" value="1"></label></div>';
      h+=D.processingRecipes.map(r=>row(r.name+' <span class="tag">'+r.station+'</span>','<p>每批产出 '+D.items[r.id].name+' ×'+r.qty+' · '+(r.days?'次日完成，雨天晒制顺延':'当场完成')+'</p>'+needs(r.needs),s.scene==='farm'?b('开始加工','e-process',r.id,'mini-btn',C.canUseStation(s,r.station)?'':'disabled'):b('回小院加工','travel','farm','mini-btn'),r.id)).join('');
      h+='<div class="section-divider">正在等的味道</div>'+(s.processing.length?s.processing.map(p=>'<p>'+D.items[p.id].name+' ×'+p.qty+' · '+(p.station||'腌菜坛')+' · '+(p.readyDay-s.day)+' 天后</p>').join(''):'<p>暂时没有等待中的工序。</p>');return h;
    }
    if(name==='storage'){
      let h=head('老屋的储物柜','存取保留品质，不腐坏。背包与柜子分开存放；拿到手边的食材才用于制作。');if(!s.upgrades.storage)return h+'<p>先添置一个储物柜，之后可按数量存取和拆分一叠物品。</p>'+b('去修缮小院','build');
      h+='<div class="form-inline"><label>本次数量 <input id="move-count" type="number" min="1" max="999999" value="1"></label></div><div class="storage-columns">';
      for(const [label,bag,to]of [['随身背包',s.bag,true],['储物柜',s.storage,false]])h+='<section><h3>'+label+'</h3>'+Object.entries(bag).filter(([,n])=>n>0).map(([id,n])=>row(D.items[id].name+' ×'+n,'<p>'+D.items[id].kind+'</p>',b(to?'存入':'取出',to?'e-store':'e-take',id,'mini-btn')+b('整叠',to?'e-store-all':'e-take-all',id,'mini-btn'),id)).join('')+'</section>';
      return h+'</div>';
    }
    if(name==='relations'){
      let h=head('二十四位邻居，各有自己的日子。','8 位成年候选人、12 位主要支持村民、4 位少年儿童。关系不会衰减，故事可以延后。');h+='<div class="tabs">'+['全部','画像册','成年候选人','主要邻居','孩子们'].map(k=>b(k,'e-npc-filter',k,ui.npc===k?'active':'')).join('')+'</div>';
      if(ui.npc==='画像册')return h+'<div class="portrait-gallery">'+D.npcs.map(n=>'<article><canvas width="128" height="160" data-npc="'+n.id+'" aria-label="'+n.name+'的画像"></canvas><h3>'+n.name+'</h3><p>'+n.role+'</p>'+b('去找'+n.name,'find-npc',n.id,'mini-btn')+'</article>').join('')+'</div>';
      h+=D.npcs.filter(n=>ui.npc==='全部'||n.tier===({'成年候选人':'romance','主要邻居':'support','孩子们':'child'}[ui.npc])).map(n=>{const st=s.stories[n.id],r=s.relations[n.id],where=C.npcScene(s,n);return '<article class="row-card"><canvas class="npc-portrait" width="64" height="80" data-npc="'+n.id+'"></canvas><div class="row-text"><h3>'+n.name+' <span class="tag">'+(s.marriage.spouse===n.id?'伴侣':s.partners[n.id]==='dating'?'心意相通':C.stage(r.points))+'</span></h3><p>'+n.role+' · '+n.age+' 岁 · '+n.gender+'<br>'+n.family+'<br>此刻：'+D.scenes[where].name+' · 生日：'+D.seasons[Math.floor((n.birthday-1)/28)]+' '+((n.birthday-1)%28+1)+' 日<br>喜欢：'+n.likes.map(id=>D.items[id].name).join('、')+'</p><div class="relationship-bar"><span style="width:'+r.points+'%"></span></div><p>个人故事 '+st.step+' / '+D.arcs[n.id].length+' · '+C.storyReady(s,n.id).msg+'</p></div><div class="row-actions">'+b('去找对方','find-npc',n.id,'mini-btn')+b('故事与线索','e-story-open',n.id,'mini-btn')+'</div></article>';}).join('');return h;
    }
    if(name==='npc'){
      const n=D.npcs.find(n=>n.id===arg),r=s.relations[arg];let h=head(n.name,n.role+' · '+C.stage(r.points)+' · '+n.age+' 岁');
      h+='<canvas class="dialogue-portrait" width="128" height="160" data-npc="'+n.id+'"></canvas><p class="dialogue-quote typed-text">'+e(A.dialogue||n.greeting)+'</p><div class="button-row">'+b('聊聊你的近况','e-story-open',n.id,'secondary')+b('送一道菜','gift-list',n.id,'secondary')+b('邀请来吃饭','home','','secondary')+'</div><div class="paper-note">'+C.storyReady(s,n.id).msg+'</div>';
      if(n.tier==='romance'&&s.stories[n.id].step>=4){if(s.marriage.spouse===n.id)h+=b('我们的共同生活','home');else if(s.partners[n.id]!=='dating')h+=b('认真表达心意','e-date',n.id,'secondary');else if(!s.marriage.spouse)h+=b('商量婚礼','e-wedding-open',n.id,'secondary');}return h;
    }
    if(name==='story'){
      const n=D.npcs.find(n=>n.id===arg);if(!n)return head('邻里故事');const st=s.stories[arg],arc=D.arcs[arg],event=arc[st.step],ready=C.storyReady(s,arg),near=s.scene===C.npcScene(s,n);
      let h=head(n.name+' · '+(event?event.title:'这一段，已经好好记下。'),'故事 '+st.step+' / '+arc.length+' · 错过日期不会失去剧情。');
      if(event){h+='<p class="dialogue-quote typed-text">'+e(event.text)+'</p>'+(event.needs?needs(event.needs):'')+'<div class="paper-note">'+ready.msg+'</div>';if(ready.ok&&near)h+='<div class="story-choices">'+event.choices.map((v,i)=>b(v.label,'e-story-choice',arg,'secondary','data-choice="'+i+'"')).join('')+'</div>';else h+=b('去找'+n.name,'find-npc',arg,'secondary');}
      if(st.step){h+='<div class="section-divider">旧事回看</div>'+arc.slice(0,st.step).map((v,i)=>'<details class="memory-page"><summary>'+v.title+'</summary><p>'+v.text+'</p><p>你的回应：'+v.choices[st.choices[i]].label+'</p><p>'+v.choices[st.choices[i]].reply+'</p></details>').join('');}
      if(n.tier==='romance'&&st.step>=4&&s.marriage.spouse!==arg&&!s.marriage.spouse)h+='<div class="button-row">'+(s.partners[arg]==='dating'?b('商量婚礼','e-wedding-open',arg):b('重新表达心意','e-date',arg))+'</div>';return h;
    }
    if(name==='wedding'){
      const n=D.npcs.find(n=>n.id===arg);return head('把两个人的日子放在一起','婚后各自保留工作和朋友。安排共餐、探亲与来年计划，家不是自动农务设施。')+'<p class="dialogue-quote">'+e(n?.name||'对方')+'愿意与你慢慢生活。你也确定想和对方成为伴侣吗？</p><div class="paper-note">需要：双方心意相通、前四章故事、信任 70、整理好的厢房。婚礼不会消耗贵重礼品。</div><div class="button-row">'+b('确定，与'+e(n?.name||'对方')+'举行婚礼','e-marry',arg)+b('再慢慢想想','close','','secondary')+'</div>';
    }
    if(name==='home'){
      let h=head('家里的饭桌，有自己的节奏。','可以独居、邀请朋友，也可以与伴侣共同生活。没有每日共餐义务。');const spouse=D.npcs.find(n=>n.id===s.marriage.spouse);
      if(spouse){h+=row('与你共同生活的 '+spouse.name,'<p>此刻在'+D.scenes[C.npcScene(s,spouse)].name+' · 仍继续'+spouse.role+'的工作。</p>',b('婚后故事','e-story-open',spouse.id,'mini-btn'));
        h+='<div class="section-divider">每周的共同安排</div><div class="form-inline">'+select('shared-dish',dishes)+'</div><div class="button-row">'+[['meal','共餐，聊聊今天'],['visit','探望家人与朋友'],['objects','整理老屋物件'],['plan','讨论来年安排']].map(([id,label])=>b(label,'e-shared',id,'secondary')).join('')+'</div><p>已留下 '+s.marriage.memories.length+' 次共同生活的记忆。</p>'+b('平静地商量各自生活','separation','','mini-btn');}
      else h+='<div class="paper-note">现在的小院由你安排。八位成年候选人的关系不限主角性别，友情也能走到长久的信任。</div>';
      h+='<div class="section-divider">请一位邻居来吃饭</div><p>需要整理厢房、在小院备好一道菜。每位邻居每周可邀请一次。</p><div class="form-inline">'+select('meal-npc',D.npcs.map(n=>[n.id,n.name]))+select('meal-dish',dishes)+b('摆好饭桌','e-host')+'</div><div class="section-divider">院里的小伙伴</div><p>'+e(s.pet.name)+' · '+(s.pet.type==='cat'?'猫':'狗')+' · 亲近 '+s.pet.bond+' / 100</p><div class="form-inline"><input id="pet-name" maxlength="12" value="'+e(s.pet.name)+'" aria-label="宠物名字">'+select('pet-type',[['cat','猫'],['dog','狗']])+b('记下名字','e-pet-name','','secondary')+b('陪它玩一会儿','e-pet','','secondary')+'</div>';return h;
    }
    if(name==='separation')return head('好好商量，各自生活','不扣关系，不清除已经发生的故事。')+'<p>确定结束目前的伴侣关系，恢复普通邻里相处吗？</p><div class="button-row">'+b('确定，各自生活','e-separate','','secondary')+b('先回家坐坐','home')+'</div>';
    if(name==='projects'||name==='project'){
      let h=head('不是一个人的工程。','四季各一项，开放后可随时补做。每位乡亲都贡献材料、手艺或组织。');h+=Object.entries(D.projects).map(([id,p])=>row(p.name+' <span class="tag">'+(s.projects[id]?'已完成':D.seasons[p.season]+'季起')+'</span>','<p>'+p.people+'<br>'+p.change+'</p>'+needs(p.needs),s.projects[id]?b('去看看','travel',p.scene,'mini-btn'):b('与乡亲一起动工','e-project',id,'mini-btn',s.day<p.season*28?'disabled':''))).join('');return h;
    }
    if(name==='orders'){
      let h=head('心愿可以慢慢完成。','送饭、个人故事、四季目标和共同劳动，都会让这张关系网长起来。');h+=D.orders.map(o=>row(o.title,'<p>'+o.text+'</p>'+needs(o.needs),b(s.flags[o.id]?'已完成':'送去料理','deliver',o.id,'mini-btn',s.flags[o.id]||!C.has(s,o.needs)?'disabled':''))).join('');h+='<div class="section-divider">顺手的帮助 · 无截止日期</div>'+D.favors.map(f=>row(f.title,'<p>'+f.text+'</p>'+needs(f.needs),b(s.seasonEvents['favor-'+f.id]?'已经帮过忙':'搭把手','e-favor',String(f.id),'mini-btn',s.seasonEvents['favor-'+f.id]?'disabled':''))).join('');return h+'<div class="button-row">'+b('四季生活与个人故事','stories','','secondary')+b('四项公共事务','projects','','secondary')+b('信件和邀约','mail','','secondary')+'</div>';
    }
    if(name==='stories'){
      const cal=C.calendar(s);let h=head('这一年，慢慢长出的故事。','第 '+(Math.floor((s.day%112)/7)+1)+' 周 · '+D.weekHints[Math.floor((s.day%112)/7)]+'。所有主要章节都有回看与补做入口。');
      h+=D.seasonChapters.map((ch,i)=>{const done=s.chapters[cal.year+'-'+i]!==undefined;return '<article class="chapter-card"><span class="chapter-season">'+D.seasons[i]+'</span><div><h3>'+ch.title+'</h3><p>'+ch.text+'</p><p class="mode-tag">生活目标：'+ch.goal+'</p>'+((s.day%112)>=i*28?(done?'<div class="paper-note">你的想法：'+ch.choices[s.chapters[cal.year+'-'+i]]+'</div>':'<div class="story-choices">'+ch.choices.map((v,n)=>b(v,'e-chapter',String(i),'secondary','data-choice="'+n+'"')).join('')+'</div>'):'<p>这一季到来后可以阅读；过季仍能补看。</p>')+'</div></article>';}).join('');
      h+='<div class="section-divider">谁还有话想与你说</div>'+D.npcs.filter(n=>s.stories[n.id].step<D.arcs[n.id].length).map(n=>row(n.name+' · '+D.arcs[n.id][s.stories[n.id].step].title,'<p>'+C.storyReady(s,n.id).msg+'</p>',b('看看线索','e-story-open',n.id,'mini-btn'))).join('');return h;
    }
    if(name==='build')return head('把老院修成想住的样子','八处功能修缮，每一处都能留下用途；自由布置可以随时撤回。')+Object.entries(D.upgrades).map(([id,u])=>row(u.name,'<p>'+u.description+'</p>'+needs(u.materials)+'<p>工钱 '+u.cost+' 元 · 现有 '+s.money+' 元</p>',b(s.upgrades[id]?'已经修好':'一起动工','upgrade',id,'mini-btn',s.upgrades[id]?'disabled':''))).join('')+'<div class="button-row">'+b('庭院自由布置','decor','','secondary')+b('工具维修升级','tools','','secondary')+b('储物柜','storage','','secondary')+'</div>';
    if(name==='decor'){
      let h=head('庭院留白，随你安排。','先制作或领取家具，再点一格放下。已占用的格子点一下收回，换个位置重新放；不扣材料。');if(!s.upgrades.yard)return h+b('先整理庭院','build');
      h+='<div class="paper-note">这里布置庭院景观，果树改善散养环境。农田设施请在“四时农事 → 田埂设施”安置：已做好的菜架、篱笆、稻草人、温棚可直接使用库存，局部生效并可查看覆盖。稻草人驱鸟，病虫另行治理。</div><div class="decor-palette">'+Object.entries(D.furniture).map(([id,f])=>'<div><button data-action="e-decor-select" data-id="'+id+'" class="'+(ui.furniture===id?'active':'')+'">'+f.name+' <b>×'+(s.furniture[id]||0)+'</b></button>'+b('制作','e-craft',id,'mini-btn')+'</div>').join('')+'</div><p>正在摆放：'+D.furniture[ui.furniture].name+' · '+Object.entries(D.furniture[ui.furniture].needs).map(([id,n])=>D.items[id].name+' '+n).join('、')+'</p><div class="yard-plan"><div class="yard-house">老屋 · 菜地 · 小厨房（保留通道）</div><div class="decor-grid">'+C.layoutSlots.map((p,i)=>{const f=s.layouts.find(v=>v.slot===i);return '<button class="'+(f?'occupied':'')+'" data-action="e-place" data-id="'+i+'" aria-label="庭院第 '+(i+1)+' 格">'+(f?D.furniture[f.id].name:'＋')+'</button>';}).join('')+'</div></div>';return h;
    }
    if(name==='tools')return head('旧工具，修得更顺手','每种只升级一次，减少对应劳动的体力消耗；没有耐久损坏。')+Object.entries(D.toolUpgrades).map(([id,t])=>row(t.name,needs(t.needs)+'<p>'+t.cost+' 元 · 消耗 −1</p>',b(s.toolUpgrades[id]?'已升级':'请宋伯改一改','e-tool-upgrade',id,'mini-btn',s.toolUpgrades[id]?'disabled':''))).join('');
    if(name==='farmcare'){
      let h=head('看看土，给农事留一点余地。','肥沃 / 稳定 / 需要养护三档。浇水、豆类轮作、堆肥和休耕都能慢慢养好；不用逐日打卡。');h+='<div class="paper-note">今天 '+C.weather(s.day)+' · '+C.weatherAdvice(s.day+1)+'<br>蓄水 '+s.waterReserve+' / 3 · '+(s.upgrades.irrigation?'普通天气自动浇水，高温/台风用储备':'修好公共水渠后，可安装蓄水设施')+'</div>'+b('装满蓄水桶','e-fill-water','','secondary');
      h+='<div class="plot-cards">'+s.plots.map((p,i)=>{const crop=D.crops[p.crop];return '<article><h3>第 '+(i+1)+' 块 · '+(crop?crop.name:'休耕中')+'</h3><p>土壤：'+(p.soil>=1.75?'肥沃':p.soil>=.75?'稳定':'需要养护')+'<br>'+(crop?'还需约 '+Math.ceil(crop.days-p.growth)+' 个照料日':'适合：'+(p.lastGroup==='叶菜'?'豆类、根菜':'当季轮作'))+'<br>'+(p.watered?'已经润湿':'等待浇水')+(p.pest?' · 有少量小虫，生长略缓':'')+'</p>'+b('施熟堆肥','e-fertilize',String(i),'mini-btn',p.soil>=2?'disabled':'')+(p.pest?b('手工移走小虫','e-pest',String(i),'mini-btn'):'')+'</article>';}).join('')+'</div>';return h;
    }
    if(name==='animals')return head('有名字的小伙伴','收产物、添一次饲料，就是一天基础照料。清洁和陪玩可以按心情安排，漏一天不会生病或失去它们。')+s.animals.map(a=>row(e(a.name)+' · '+a.species,'<p>'+a.personality+' · 亲近 '+a.bond+' / 100<br>产物 '+D.items[a.product].name+' ×'+a.ready+' · '+(a.fed?'今天吃饱了':'可添一份饲料')+'</p><div class="form-inline"><input id="animal-name-'+a.id+'" maxlength="12" value="'+e(a.name)+'" aria-label="'+e(a.name)+'的新名字">'+b('改名','e-animal-name',a.id,'mini-btn')+'</div>',b(a.ready?'收取产物':'喂食与抚摸','e-animal',a.id,'mini-btn','data-kind="feed"')+b('清理垫草','e-animal',a.id,'mini-btn','data-kind="clean"')+b('陪玩','e-animal',a.id,'mini-btn','data-kind="pet"'),a.product)).join('')+'<div class="button-row">'+b(s.freeRange?'散养已开启':'开启散养','e-free-range','','secondary')+'</div><p>散养在高亲近、有果树荫地时偶尔多出一份产物，不会走失。扩建棚舍可自动使用背包饲料。</p>';
    if(name==='skills')return head('熟能生巧，不必样样刷满。','达到 25 点熟练度后选择一种轻量风格，基础操作从一开始就能使用。')+Object.entries(D.skillNames).map(([id,label])=>{const sk=s.skills[id];return '<article class="skill-card"><h3>'+label+' · '+sk.xp+' 点</h3><div class="relationship-bar"><span style="width:'+Math.min(100,sk.xp/25*100)+'%"></span></div><div class="skill-options">'+D.skillChoices[id].map(([key,title,desc])=>'<div><strong>'+title+'</strong><p>'+desc+'</p>'+b(sk.choice===key?'已选择':'选择此风格','e-skill',id,'mini-btn','data-choice="'+key+'" '+(sk.choice||sk.xp<25?'disabled':''))+'</div>').join('')+'</div></article>';}).join('');
    if(name==='mail')return head('院门口的信箱','查看天气与邀约，领取小礼物。来信不会过期，错过的邀请也能从聚会页补办。')+'<div class="paper-note">明日 '+C.weather(s.day+1)+' · '+C.weatherAdvice(s.day+1)+'<br>每周第 6 天赶集，本周需求：'+D.items[C.market(s).demand].name+'，当天基础售价 +20%。</div>'+s.letters.map(m=>row(e(m.title),' <p>'+e(m.from)+' · 第 '+(m.day+1)+' 天<br>'+e(m.text)+'</p>'+(m.gift?'<p>随信：'+Object.entries(m.gift).map(([id,n])=>D.items[id].name+' ×'+n).join('、')+'</p>':''),b(s.mailRead.includes(m.id)?'已收好':'收下信与礼物','e-mail',m.id,'mini-btn',s.mailRead.includes(m.id)?'disabled':''))).join('');
    if(name==='festival'){
      const c=C.calendar(s);let season=ui.festival===null?c.season:ui.festival;const f=D.festivalDetails[season],done=s.festivals.includes(c.year+'-'+season),available=s.day%112>=season*28+13;
      let h=head(f.name,'准备、相聚、事后的来往，都是节日的一部分。过季可以补办，来年也能再聚。');h+='<div class="tabs">'+D.seasons.map((n,i)=>b(n+'季','e-festival-season',String(i),i===season?'active':'')).join('')+'</div><div class="festival-steps"><article><b>一 · 备菜</b><p>'+f.prepare+'</p></article><article><b>二 · 相聚</b><p>'+f.activity+'</p></article><article><b>三 · 回响</b><p>'+(done?f.after:'相聚后会在手记里留下一页。')+'</p></article></div>';
      if(done)h+='<p class="dialogue-quote">'+f.after+'</p>';else if(!available)h+='<p>本季第 14 天起开放，现在可以先备菜、学习节令配方。</p>';else h+='<div class="form-inline">'+select('festival-dish',dishes)+'</div><div class="story-choices">'+f.choices.map((v,i)=>b(v,'e-festival',String(season),'secondary','data-choice="'+i+'"')).join('')+'</div>';return h+b('邻里小聚','gatherings','','secondary');
    }
    if(name==='gatherings')return head('不用等到节日才相聚','每周都能参加一回，错过就等下一次。不比赛、不淘汰，没有重要线索只出现一次。')+[['tea','山间茶桌','周远烧好热水，欢迎坐下来讲讲这一周。','mountain'],['repair','修理摊边的小聚','宋伯摆出旧工具，大家讲讲修好继续用的东西。','town'],['stage','戏台上的小调','戏台修好后，江桂珍每周招呼大家来听一段。','town'],['lost','河边的小画本','小岚请大家陪她找一找落在长椅边的画本。','river']].map(([id,title,text,scene])=>row(title,'<p>'+text+' · '+D.scenes[scene].name+'</p>',s.scene===scene?b('参加一会儿','e-small-event',id,'mini-btn'):b('去附近看看','travel',scene,'mini-btn'))).join('');
    if(name==='archive'){
      let h=head('爷爷的旧物柜，村庄的新记录。','不收奇珍，只留生活。收集不会锁住年度结局。');h+=D.archives.map(a=>row(s.archives.includes(a.id)?a.title:'还没有收好的记录','<p>'+(s.archives.includes(a.id)?a.text:'线索：'+a.source)+'</p>')).join('');
      h+='<div class="section-divider">日常的小纪念</div>'+D.achievements.map(a=>row(a.name,'<p>'+a.desc+' · '+Math.min(s.stats[a.stat],a.target)+' / '+a.target+'<br>纪念物：'+D.furniture[a.reward].name+'</p>',b(s.achievements.includes(a.id)?'已收好':'领取纪念物','e-achievement',a.id,'mini-btn',s.achievements.includes(a.id)||s.stats[a.stat]<a.target?'disabled':''))).join('');return h;
    }
    if(name==='catalog'){
      let h=head('禾溪物产与人物册','作物、料理、鱼、动物、人物故事和旧物都能找到线索。全收集不是生活目标。');h+='<div class="tabs">'+['作物','料理','鱼类','动物','人物','旧物'].map(v=>b(v,'e-catalog',v,ui.catalog===v?'active':'')).join('')+'</div>';
      if(ui.catalog==='人物')return h+D.npcs.map(n=>row(n.name,'<p>'+n.role+' · '+s.stories[n.id].step+' / '+D.arcs[n.id].length+' 章</p>',b('查看故事','e-story-open',n.id,'mini-btn'))).join('');
      if(ui.catalog==='旧物')return h+b('打开家中旧物柜','archive');if(ui.catalog==='动物')return h+b('看看牧场伙伴和陪伴宠物','animals');
      const ids=ui.catalog==='作物'?Object.keys(D.crops):ui.catalog==='料理'?D.recipes.map(r=>r.id):[...new Set(D.fishBySeason.flat().concat('shrimp'))];h+='<div class="inventory-grid">'+ids.map(id=>'<article class="item-card"><div class="item-head">'+ic(id)+'<strong>'+D.items[id].name+'</strong></div><p>'+ (s.discovered.includes(id)?'已收录':'还没遇见')+qtext(id)+'</p><small>'+(D.crops[id]?'时令：'+D.crops[id].seasons.map(v=>D.seasons[v]).join('、')+' · '+D.crops[id].days+' 天':ui.catalog==='鱼类'?'河边垂钓，时令和雨水会改变鱼种。':'来源：'+source(D.recipes.find(r=>r.id===id)))+'</small></article>').join('')+'</div>';return h;
    }
    if(name==='journal')return head('日子里的来往，都记得。','重要事件另有线索页与回看入口；这份日志只负责把经历好好收起来。')+'<div class="button-row">'+b('物产图鉴','catalog','','secondary')+b('旧物与纪念','archive','','secondary')+b('故事与线索','stories','','secondary')+'</div>'+s.journal.map(v=>{const c=C.calendar({day:v.day});return '<div class="journal-entry"><time>'+D.seasons[c.season]+' '+c.date+' 日</time><span>'+e(v.text)+'</span></div>';}).join('');
    if(name==='year'){
      const prev=C.calendar(s).year-1;return head('一年，把日子过成自己的模样。','四季已经走完，未完成的故事仍会等你。')+'<div class="year-illustration"><span>春耕</span><span>夏雨</span><span>秋收</span><span>冬灯</span></div><p class="dialogue-quote">'+C.yearSummary(s).map(e).join('<br><br>')+'</p>'+(s.yearPlans[prev]===undefined?'<h3>来年，你想给什么多留一点时间？</h3><div class="story-choices">'+['继续照看小院，也常与邻居来往','分享手艺，摆开更多饭桌','出门看看，也保留回家的路'].map((v,i)=>b(v,'e-year-plan',String(i),'secondary')).join('')+'</div>':'<div class="paper-note">来年的安排已经写好，继续自由生活。</div>')+'<div class="button-row">'+b('回到新一年的小院','close')+b('翻看个人故事','stories','','secondary')+'</div>';
    }
    if(name==='appearance')return head('还是你，换一个喜欢的样子','姓名与性别不限制成年关系；外观随存档保存，可随时调整。')+'<div class="appearance-form"><label>姓名<input id="appearance-name" maxlength="12" value="'+e(s.name)+'"></label><label>性别'+select('appearance-gender',[[s.gender,s.gender],...['不设定','女','男'].filter(x=>x!==s.gender).map(x=>[x,x])])+'</label><label>上衣'+select('appearance-shirt',[[0,'青绿'],[1,'靛蓝'],[2,'陶红'],[3,'米黄']])+'</label><label>发型'+select('appearance-hair',[[0,'短发'],[1,'齐肩'],[2,'束发'],[3,'卷发']])+'</label><label>肤色'+select('appearance-skin',[[0,'暖浅'],[1,'小麦'],[2,'暖棕']])+'</label><label><input id="appearance-hat" type="checkbox" '+(s.appearance.hat?'checked':'')+'> 戴草帽</label></div>'+b('换好衣服','e-appearance');
    return null;
  }
  function after(name,s,A){const b=A.button;let h='';
    if(name==='menu')h+='<div class="section-divider">小院与这一年</div><div class="menu-grid expansion-menu">'+[['stories','四季与人物故事','慢慢认识，也可以回看'],['mail','信箱与天气','收下邻里的来信'],['processing','家常加工','磨粉、榨油、晾晒'],['farmcare','农田照料','土壤、堆肥与蓄水'],['animals','牧场名册','鸡鸭牛羊猪 · 畜舍与繁育'],['storage','储物柜','分开放好收成'],['home','家与饭桌','待客、伴侣与宠物'],['projects','公共事务','四季一起做的事'],['tools','工具与设施','工具专长、范围与设施状态'],['decor','庭院布置','摆放、收回与移动'],['skills','做事的风格','熟能生巧的选择'],['catalog','物产图鉴','认识时令和故事'],['archive','家中旧物柜','保留生活的痕迹'],['gatherings','邻里小聚','一杯茶，一段小调'],['appearance','我的样子','衣服、发型与名字']].map(([id,title,desc])=>'<button class="menu-card" data-action="'+id+'"><span><strong>'+title+'</strong><small>'+desc+'</small></span></button>').join('')+'</div>';
    if(name==='settings')h+='<div class="section-divider">阅读、听觉与手柄</div>'+[['music','四季琴音'],['ambient','环境声'],['effects','交互音效']].map(([id,label])=>'<div class="settings-row"><label>'+label+'</label><input type="range" min="0" max="1" step=".05" data-extra-setting="'+id+'" value="'+s.settings[id]+'" aria-label="'+label+'音量"></div>').join('')+'<div class="settings-row"><label>字号</label><select data-extra-setting="textScale">'+[[1,'标准'],[1.15,'较大'],[1.3,'大字']].map(([v,n])=>'<option value="'+v+'" '+(s.settings.textScale===v?'selected':'')+'>'+n+'</option>').join('')+'</select></div><div class="settings-row"><label>对话文字速度</label><select data-extra-setting="textSpeed">'+[['instant','立即显示'],['normal','逐字 · 常规'],['slow','逐字 · 舒缓']].map(([v,n])=>'<option value="'+v+'" '+(s.settings.textSpeed===v?'selected':'')+'>'+n+'</option>').join('')+'</select></div>'+[['contrast','提高文字对比度'],['gamepad','手柄输入'],['vibration','手柄轻震动'],['fishAssist','钓鱼自动收竿']].map(([id,label])=>'<div class="settings-row"><label>'+label+'</label>'+b(s.settings[id]?'已开启':'已关闭','e-setting-toggle',id,'secondary')+'</div>').join('')+'<p class="paper-note">手柄：左摇杆 / 十字键移动，A 交互或确认，B 返回，X 背包，Y 地图，LB/RB 切换工具，Start 菜单。菜单上下选项目，左右调整选项或数量，A 确认。须先按一次手柄键让浏览器识别。</p>';
    if(name==='shop')h='<div class="paper-note">'+(C.market(s).open?'今天赶集：'+D.items[C.market(s).demand].name+'售价 +20%。':'每周第 6 天赶集，本周需求：'+D.items[C.market(s).demand].name)+' · 基础价不会随机暴跌。</div>'+['compost','egg','milk'].map(id=>'<div class="row-card"><div class="row-text"><h3>'+D.items[id].name+'</h3><p>'+D.items[id].cost+' 元</p></div>'+b('买 1 份','buy',id,'mini-btn','data-qty="1"')+'</div>').join('')+b('配方摊与菜谱线索','recipes','','secondary');
    if(name==='calendar'){const c=C.calendar(s);h+='<div class="paper-note">本周：'+D.weekHints[Math.floor(s.day%112/7)]+'<br>每周第 6 天赶集，第 7 天休闲小聚；生日只作相聚的理由，错过不扣关系。<br>明日 '+C.weather(s.day+1)+' · '+C.weatherAdvice(s.day+1)+'</div><div class="section-divider">全年的生日册</div><div class="birthday-list">'+D.npcs.map(n=>'<span>'+D.seasons[Math.floor((n.birthday-1)/28)]+' '+((n.birthday-1)%28+1)+' 日 · '+n.name+'</span>').join('')+'</div>'+b('节庆准备与补办','e-open-festival','','secondary');}
    if(name==='bag')h+='<div class="paper-note">品质会在出售时温和加价：好收成 +20%，精心照料 +40%。消耗时优先使用普通品质。'+Object.entries(s.quality).filter(([,q])=>q[0]+q[1]>0).map(([id,q])=>'<br>'+D.items[id].name+' · 好收成 '+q[0]+' · 精心照料 '+q[1]).join('')+'</div>'+b('存取与拆分物品','storage','','secondary');
    if(name==='help')h+='<div class="section-divider">本版新增生活入口</div><p>Tab 总览下方可查看四季故事、信箱、加工、土壤、动物、储物、家宴、公共事务、布置、技能和图鉴。每位村民的故事页会说明缺少什么、去哪里找人。八位成年候选人的第四章可选择友情或心意，之后能商量婚礼；第五章与每周共同安排属于婚后生活。所有重要内容可延后和回看。</p>';
    return h;
  }
  function dispatch(a,id,data,A){
    const {s,apply,open,render:refresh,save,update,toast,close}=A;
    const use=(r,panel)=>{const success=apply(r,true);if(success&&panel)open(panel,id);return true;};
    if(panels.includes(a)){open(a);return true;}
    if(!a.startsWith('e-'))return false;
    switch(a){
      case'e-recipe-filter':ui.recipe=id;refresh();break;
      case'e-npc-filter':ui.npc=id;refresh();break;
      case'e-catalog':ui.catalog=id;refresh();break;
      case'e-recipe-buy':return use(C.buyRecipe(s,id));
      case'e-sub-cook':return use(C.cook(s,id,1,true));
      case'e-trial':return use(C.trial(s,val('trial-first'),val('trial-second')));
      case'e-process':return use(C.process(s,id,Number(val('process-count'))));
      case'e-store':case'e-take':case'e-store-all':case'e-take-all':{const to=a.includes('store'),qty=a.endsWith('all')?(to?s.bag:s.storage)[id]:Number(val('move-count'));return use(C.storageMove(s,id,qty,to));}
      case'e-story-open':open('story',id);break;
      case'e-story-choice':{const r=C.storyChoice(s,id,Number(data.choice));if(apply(r,false)){open('story',id);toast(r.msg);}break;}
      case'e-date':return use(C.date(s,id),'story');
      case'e-wedding-open':open('wedding',id);break;
      case'e-marry':{const r=C.marry(s,id);if(apply(r,false)){open('home');toast(r.msg);}break;}
      case'e-separate':return use(C.separate(s),'home');
      case'e-shared':return use(C.sharedLife(s,id,val('shared-dish')));
      case'e-host':return use(C.hostMeal(s,val('meal-npc'),val('meal-dish')));
      case'e-pet':return use(C.pet(s));
      case'e-pet-name':s.pet.name=(val('pet-name')||'小团').trim().slice(0,12)||'小团';s.pet.type=val('pet-type');save();refresh();toast('记住了这个名字。');break;
      case'e-favor':return use(C.favor(s,Number(id)));
      case'e-project':return use(C.project(s,id));
      case'e-chapter':return use(C.chapter(s,Number(id),Number(data.choice)));
      case'e-decor-select':ui.furniture=id;refresh();break;
      case'e-craft':return use(C.craft(s,id));
      case'e-place':return use(s.layouts.some(v=>v.slot===Number(id))?C.removeFurniture(s,Number(id)):C.place(s,ui.furniture,Number(id)));
      case'e-tool-upgrade':return use(C.toolUpgrade(s,id));
      case'e-fertilize':return use(C.fertilize(s,Number(id)));
      case'e-pest':return use(C.clearPest(s,Number(id)));
      case'e-fill-water':return use(C.fillWater(s));
      case'e-animal':return use(C.animalAction(s,id,data.kind));
      case'e-animal-name':{const a=s.animals.find(a=>a.id===id);a.name=(val('animal-name-'+id)||a.name).trim().slice(0,12)||a.name;save();refresh();break;}
      case'e-free-range':s.freeRange=!s.freeRange;save();refresh();break;
      case'e-skill':return use(C.skill(s,id,data.choice));
      case'e-mail':return use(C.mail(s,id));
      case'e-achievement':return use(C.claimAchievement(s,id));
      case'e-open-festival':ui.festival=null;open('festival');break;
      case'e-festival-season':ui.festival=Number(id);refresh();break;
      case'e-festival':return use(C.festival(s,val('festival-dish'),Number(data.choice),Number(id)));
      case'e-small-event':return use(C.smallEvent(s,id));
      case'e-year-plan':return use(C.yearPlan(s,Number(id)));
      case'e-appearance':s.name=(val('appearance-name')||s.name).trim().slice(0,12)||s.name;s.gender=val('appearance-gender');s.appearance={shirt:Number(val('appearance-shirt')),hair:Number(val('appearance-hair')),skin:Number(val('appearance-skin')),hat:document.getElementById('appearance-hat').checked};save();update();toast('换好了，还是熟悉的你。');break;
      case'e-setting-toggle':s.settings[id]=!s.settings[id];save();update();refresh();break;
      case'e-reveal':finishTyping();break;
    }
    return true;
  }
  function finishTyping(){clearInterval(typeTimer);typeTimer=null;document.querySelectorAll('.typed-text').forEach(el=>{if(el.dataset.fullText)el.textContent=el.dataset.fullText;});document.querySelector('[data-action="e-reveal"]')?.remove();}
  function mount(s){clearInterval(typeTimer);const el=document.querySelector('.typed-text');if(el&&s.settings.textSpeed!=='instant'){const text=el.textContent;el.dataset.fullText=text;el.textContent='';let i=0;const skip=document.createElement('button');skip.className='mini-btn';skip.dataset.action='e-reveal';skip.textContent='立即显示全文';el.after(skip);typeTimer=setInterval(()=>{if(!el.isConnected){clearInterval(typeTimer);return;}el.textContent=text.slice(0,++i);if(i>=text.length){clearInterval(typeTimer);skip.remove();}},s.settings.textSpeed==='slow'?60:25);}for(const k of ['shirt','hair','skin']){const input=document.getElementById('appearance-'+k);if(input)input.value=s.appearance[k];}}
  root.ZRZPanels={panels,render,after,dispatch,mount};
})(window);
