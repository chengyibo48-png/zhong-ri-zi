'use strict';
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
async function main(){
  const browser=await chromium.launch({headless:true,executablePath:process.env.BROWSER_EXE||'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'});
  try{
    const page=await browser.newPage({viewport:{width:1440,height:900}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.goto('http://127.0.0.1:4173/');await page.locator('[data-action="start"]').click();
    const state=()=>page.evaluate(()=>ZRZSnapshot());
    async function fullCanvas(){assert.equal(await page.evaluate(()=>{const b=document.getElementById('world').getBoundingClientRect();return b.x===0&&b.y===0&&b.width===innerWidth&&b.height===innerHeight&&document.documentElement.scrollWidth===innerWidth&&document.documentElement.scrollHeight===innerHeight;}),true);}
    await fullCanvas();assert.equal(await page.locator('.sidebar,.topbar,.page-foot,.bottom-nav').count(),0);
    await page.locator('[data-action="guide"]').click();await page.waitForFunction(()=>ZRZSnapshot().bag.cabbage===2);assert.equal((await state()).flags.firstHarvest,true);
    await page.keyboard.press('Tab');const minutes=(await state()).minutes;await page.waitForTimeout(1200);assert.equal((await state()).minutes,minutes);
    await page.locator('#book-nav [data-action="settings"]').click();await page.locator('#modal-body [data-action="controls"]').click();
    await page.locator('[data-action="bind-key"][data-id="up"]').click();await page.keyboard.press('i');
    await page.locator('[data-action="bind-key"][data-id="interact"]').click();await page.keyboard.press('r');
    assert.equal((await state()).settings.bindings.up,'i');assert.equal((await state()).settings.bindings.interact,'r');
    await page.locator('[data-action="bind-key"][data-id="left"]').click();await page.keyboard.press('i');
    assert.equal((await state()).settings.bindings.left,'i');assert.equal((await state()).settings.bindings.up,'a');
    await page.locator('[data-action="bind-key"][data-id="left"]').click();await page.keyboard.press('Escape');assert.equal(await page.locator('#modal-overlay').isVisible(),true);
    await page.locator('#book-nav [data-action="settings"]').click();await page.locator('#zoom-setting').selectOption('1.4');await page.locator('[data-action="toggle-hints"]').click();await page.locator('.modal-close').click();
    assert.equal(await page.locator('#wish-card').isVisible(),false);
    await page.reload();assert.equal((await state()).settings.zoom,1.4);assert.equal((await state()).settings.bindings.left,'i');assert.equal((await state()).settings.hints,false);
    const player=(await state()).player;await page.keyboard.down('i');await page.waitForTimeout(240);await page.keyboard.up('i');assert.ok((await state()).player.x<player.x-15);
    await page.keyboard.press('h');assert.equal(await page.locator('#hud-restore').isVisible(),true);await page.locator('#hud-restore').click();assert.equal(await page.locator('#hud-restore').isVisible(),false);
    await page.keyboard.press('b');await page.getByRole('heading',{name:'随身的东西'}).waitFor();await page.locator('.modal-close').click();
    await page.keyboard.press('m');await page.locator('#modal-body [data-action="travel"][data-id="river"]').click();assert.equal((await state()).scene,'river');
    await page.locator('#fullscreen-btn').click();await page.waitForFunction(()=>document.fullscreenElement?.id==='game-root');await fullCanvas();
    await page.keyboard.press('Tab');assert.equal(await page.evaluate(()=>document.fullscreenElement.contains(document.getElementById('modal-overlay'))),true);await page.getByRole('heading',{name:'在禾溪，好好生活。'}).waitFor();await page.locator('.modal-close').click();await page.keyboard.press('f');await page.waitForFunction(()=>!document.fullscreenElement);
    for(const size of [{width:1920,height:1080},{width:1280,height:720},{width:800,height:1000},{width:390,height:844}]){await page.setViewportSize(size);await page.waitForTimeout(200);await fullCanvas();const v=await page.evaluate(()=>ZRZView());assert.ok(Math.abs(v.viewWidth/v.viewHeight-size.width/size.height)<1e-8);}
    const oldView=await page.evaluate(()=>ZRZView());await page.keyboard.down('d');await page.waitForTimeout(650);await page.keyboard.up('d');await page.waitForTimeout(300);const newView=await page.evaluate(()=>ZRZView());assert.ok(newView.x>oldView.x);
    await page.keyboard.press('Tab');await page.screenshot({path:path.join(__dirname,'..','qa','v02-narrow-menu.png')});await fullCanvas();await page.locator('.modal-close').click();
    await page.setViewportSize({width:1440,height:900});await page.keyboard.press('Tab');await page.locator('#book-nav [data-action="settings"]').click();await page.locator('#zoom-setting').selectOption('1');await page.locator('[data-action="toggle-hints"]').click();await page.locator('.modal-close').click();
    await page.keyboard.press('m');await page.locator('#modal-body [data-action="travel"][data-id="farm"]').click();await page.waitForTimeout(2800);await page.screenshot({path:path.join(__dirname,'..','qa','v02-final.png')});
    assert.deepEqual(errors,[]);console.log('Immersive QA passed: full viewport, in-game navigation, guide path, menu pause, remap/swap/cancel/persist, zoom, HUD toggle, true fullscreen including menus, four sizes, camera follow.');
  }finally{await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
