'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),D=require('../src/content.js'),C=require('../src/core.js');
const html=fs.readFileSync(path.join(root,'种日子.html'),'utf8');
assert(!/<script\s+src=/.test(html),'Single file still references a JavaScript file');
assert(!/<link[^>]+stylesheet/.test(html),'Single file still references a stylesheet');
assert(!html.includes('src/debug.js'),'Developer controls leaked into release');
assert(!/\b(?:src|href)=["']https?:\/\//.test(html),'Remote resources found');
const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];assert.equal(scripts.length,56);scripts.forEach((m,i)=>new vm.Script(m[1],{filename:'offline-script-'+i}));
require('../src/environment.js');
const rows=[['游戏日','季节','季内日期','节气','天气','提前提示','本周生活内容','生日','活动','当季可种作物']];
for(let day=0;day<112;day++){const c=C.calendar({day});rows.push([day+1,D.seasons[c.season],c.date,c.term,C.weather(day),C.weatherAdvice(day+1),D.weekHints[Math.floor(day/7)],D.npcs.filter(n=>n.birthday===day+1).map(n=>n.name).join('、'),c.date===14?D.festivals[c.season]+'开席，可延后':day%7===5?'赶集':day%7===6?'休闲小聚':'',Object.values(D.crops).filter(v=>v.seasons.includes(c.season)).map(v=>v.name).join('、')]);}
fs.writeFileSync(path.join(root,'docs','112天内容日历.csv'),'\ufeff'+rows.map(r=>r.map(v=>'"'+String(v).replaceAll('"','""')+'"').join(',')).join('\r\n'),'utf8');
const paths=['种日子.html','index.html','style.css','ui-art.css','build.cjs','server.cjs','package.json',...fs.readdirSync(path.join(root,'src')).map(f=>'src/'+f)];
const manifest={name:'种日子',version:require('../package.json').version,platform:'Windows 桌面浏览器 / 单机离线 HTML',generatedAt:new Date().toISOString(),runtimeDependencies:[],remoteAssets:[],assets:'像素美术、图标、四季琴音及环境音均由项目代码绘制或合成；系统字体不随包分发。',developerOnly:['src/debug.js'],files:paths.map(name=>{const b=fs.readFileSync(path.join(root,name));return {name,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')};})};
fs.writeFileSync(path.join(root,'资源与构建清单.json'),JSON.stringify(manifest,null,2),'utf8');
console.log('Release verified: 56 embedded scripts compile; no remote assets or external runtime files; no developer UI. Calendar has 112 days. SHA-256 manifest written.');
