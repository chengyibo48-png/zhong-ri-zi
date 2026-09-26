'use strict';
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
async function main() {
  const browser = await chromium.launch({ headless: true, executablePath: process.env.BROWSER_EXE || 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe' });
  try {
  const page = await browser.newPage({ viewport: {width:1440,height:900}, deviceScaleFactor:1 });
  const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('favicon'))errors.push(m.text());});
  const out=path.join(__dirname,'..','qa');fs.mkdirSync(out,{recursive:true});
  await page.goto('http://127.0.0.1:4173');
  await page.locator('#new-name').fill('小满');await page.locator('[data-action="start"]').click();
  await page.screenshot({path:path.join(out,'01-farm.png'),fullPage:true});
  const snapshot=()=>page.evaluate(()=>window.ZRZSnapshot());
  async function worldClick(x,y){const v=await page.evaluate(()=>ZRZView());await page.mouse.click((x-v.x)*v.scale,(y-v.y)*v.scale);}
  async function travel(id){await page.keyboard.press('m');await page.locator('#modal-body [data-action="travel"][data-id="'+id+'"]').click();}
  async function panel(action){if(!await page.locator('#modal-overlay').isVisible())await page.keyboard.press('Tab');await page.locator('#book-nav [data-action="menu"]').click();await page.locator('#modal-body [data-action="'+action+'"]').first().click();}
  async function waitPanel(name){await page.locator('#modal-title').filter({hasText:name}).waitFor({timeout:15000});}
  async function close(){await page.locator('.modal-close').click();}
  // Real pointer input traverses the map and interacts; no state injection here.
  await worldClick(310,291);await page.waitForFunction(()=>ZRZSnapshot().bag.cabbage===2,{timeout:15000});
  await worldClick(680,216);await waitPanel('把日子煮成家常');
  await page.locator('[data-action="cook-item"][data-id="greens"][data-qty="1"]').click();
  assert.equal((await snapshot()).bag.greens,1);await close();
  await panel('orders');await page.locator('[data-action="deliver"][data-id="firstDish"]').click();
  assert.equal((await snapshot()).flags.firstDish,true);await page.screenshot({path:path.join(out,'02-neighbor-story.png'),fullPage:true});await close();
  // Plant, water, buy, sell, harvest restrictions and inventory UI.
  await page.locator('[data-action="tool"][data-id="seed"]').click();await worldClick(395,291);await page.waitForFunction(()=>ZRZSnapshot().plots[2].crop==='cabbage');
  await page.locator('[data-action="tool"][data-id="water"]').click();await worldClick(395,291);await page.waitForFunction(()=>ZRZSnapshot().plots[2].watered);
  await travel('town');await worldClick(237,262);await waitPanel('许婶的杂货铺');
  const before=(await snapshot()).money;await page.locator('[data-action="buy"][data-id="feed"][data-qty="1"]').click();assert.equal((await snapshot()).money,before-4);await close();
  await page.screenshot({path:path.join(out,'03-town.png'),fullPage:true});
  // Two mornings of material gathering, via actual clicks and sleep UI.
  for(let day=0;day<2;day++){
    await travel('bamboo');
    for(const [id,x,y] of [['bamboo-0',296,287],['bamboo-1',215,382],['bamboo-3',691,237],['bamboo-4',181,469]]){
      await worldClick(x,y);await page.waitForFunction(id=>ZRZSnapshot().collected[id]===ZRZSnapshot().day,id,{timeout:15000});
    }
    if(!day){await travel('farm');await worldClick(214,216);await waitPanel('今天，就到这里吧');await page.locator('[data-action="next-day"]').click();await page.waitForFunction(()=>ZRZSnapshot().day===1);}
  }
  await travel('river');await worldClick(471,195);await waitPanel('让村庄多一点好');await page.locator('[data-action="repair"]').click();assert.equal((await snapshot()).flags.bridge,true);await close();
  await page.screenshot({path:path.join(out,'04-repaired-river.png'),fullPage:true});
  await worldClick(269,198);await waitPanel('听，水面的动静');await page.waitForFunction(()=>ZRZSnapshot().stats.fish===1,{timeout:15000});
  await page.locator('[data-action="save"]').first().click();await page.locator('[data-action="save-slot"][data-id="1"]').click();await close();
  await page.reload();await page.waitForFunction(()=>ZRZSnapshot().flags.bridge);assert.equal((await snapshot()).flags.firstDish,true);
  // All panels fit and time pauses while browsing.
  for(const action of ['bag','recipes','relations','journal','build','calendar','settings','help','save']){
    await panel(action);const minutes=(await snapshot()).minutes;await page.waitForTimeout(1100);assert.equal((await snapshot()).minutes,minutes);assert.ok(await page.locator('#modal-title').isVisible());await close();
  }
  await travel('mountain');await page.screenshot({path:path.join(out,'05-mountain.png'),fullPage:true});
  // Corrupt automatic save recovers from backup in a new page.
  await page.addInitScript(()=>{if(!sessionStorage.getItem('qa-corrupted')){localStorage.setItem('zhong-ri-zi-v2-auto','corrupt');sessionStorage.setItem('qa-corrupted','yes');}});
  await page.reload();await page.waitForFunction(()=>ZRZSnapshot().flags.bridge);assert.ok(await page.getByText('自动存档损坏，已恢复上一份备份。',{exact:true}).isVisible());
  await page.setViewportSize({width:800,height:1000});await page.screenshot({path:path.join(out,'06-compact.png'),fullPage:true});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth===innerWidth&&document.documentElement.scrollHeight===innerHeight),true);
  assert.deepEqual(errors,[]);
  console.log('Browser QA passed: actual harvest → cook → deliver → gather → sleep → repair → fish; persistence, recovery, menus, pause, responsive layout.');
  } finally { await browser.close(); }
}
main().catch(e=>{console.error(e);process.exitCode=1;});
