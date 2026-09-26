'use strict';
const { chromium }=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const fs=require('node:fs/promises');
async function main(){
  const browser=await chromium.launch({headless:true,executablePath:process.env.BROWSER_EXE||'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe'});
  try{
    const context=await browser.newContext({viewport:{width:1440,height:1080},acceptDownloads:true,offline:true});
    const page=await context.newPage(),errors=[],remote=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(/^https?:/.test(r.url()))remote.push(r.url());});
    await page.goto(pathToFileURL(path.join(__dirname,'..','种日子.html')).href);
    await page.locator('#new-name').fill('禾禾');await page.locator('[data-action="start"]').click();
    const state=()=>page.evaluate(()=>ZRZSnapshot());
    await page.waitForFunction(()=>ZRZSnapshot().minutes>390);
    const before=await state();await page.keyboard.down('w');await page.waitForFunction(y=>ZRZSnapshot().player.y<y,before.player.y,{timeout:5000});await page.keyboard.up('w');assert.ok((await state()).player.y<before.player.y);
    await page.locator('[data-action="save"]').first().click();await page.locator('[data-action="save-slot"][data-id="1"]').click();
    let fixture=await state();fixture.day=111;fixture.scene='farm';fixture.player={x:214,y:216,direction:'down'};fixture.minutes=1290;fixture.stats.harvested=50;fixture.stats.cooked=12;fixture.flags.bridge=true;
    await page.locator('#import-file').setInputFiles({name:'winter.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(fixture))});
    await page.waitForFunction(()=>ZRZSnapshot().day===111);await page.keyboard.press('e');await page.locator('[data-action="next-day"]').click();await page.getByRole('heading',{name:'一年，把心安顿下来。'}).waitFor();assert.equal((await state()).day,112);
    await page.screenshot({path:path.join(__dirname,'..','qa','07-year-review.png'),fullPage:true});await page.locator('.modal-close').click();
    await page.locator('[data-action="save"]').first().click();await page.locator('[data-action="load-slot"][data-id="1"]').click();await page.waitForFunction(()=>ZRZSnapshot().day===0);assert.equal((await state()).name,'禾禾');
    await page.locator('[data-action="save"]').first().click();const downloadPromise=page.waitForEvent('download');await page.locator('[data-action="export"]').click();const download=await downloadPromise;const downloaded=JSON.parse(await fs.readFile(await download.path(),'utf8'));assert.equal(downloaded.name,'禾禾');assert.equal(downloaded.version,2);
    const validDay=(await state()).day;await page.locator('#import-file').setInputFiles({name:'bad.json',mimeType:'application/json',buffer:Buffer.from('{bad')});await page.getByText('存档无法解析，请使用备份。',{exact:true}).waitFor();assert.equal((await state()).day,validDay);
    await page.locator('.modal-close').click();await page.reload();await page.waitForFunction(()=>ZRZSnapshot().name==='禾禾');await page.waitForTimeout(800);
    await page.screenshot({path:path.join(__dirname,'..','qa','08-offline-game.png'),fullPage:true});
    assert.deepEqual(errors,[]);assert.deepEqual(remote,[]);
    console.log('Offline QA passed: disconnected file:// launch, keyboard movement, manual save/load, export/download, validated import, corrupt import preservation, winter→year2 and annual review. Zero remote resource requests.');
  }finally{await browser.close();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
