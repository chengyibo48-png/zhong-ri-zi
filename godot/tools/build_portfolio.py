"""Assemble a current, evidence-based portfolio; publish only after verification."""
from pathlib import Path
import json,shutil,hashlib,zipfile,re
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/release-20261017'
STAGE=ROOT/'build/portfolio-0.29.0'
UI=OUT/'evidence/ui-quests-20261017'
pdfmetrics.registerFont(TTFont('CN','C:/Windows/Fonts/msyh.ttc',subfontIndex=0))
pdfmetrics.registerFont(TTFont('CNB','C:/Windows/Fonts/msyhbd.ttc',subfontIndex=0))
W,H=960,600
INK='#243B30';MUTED='#5A685D';PAPER='#F6F2E8';ACCENT='#B85D3E';LINE='#D6D4C6'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def text(c,x,y,value,size=13,color=INK,bold=False):
 c.setFillColor(HexColor(color));c.setFont('CNB' if bold else 'CN',size);c.drawString(x,y,value)
def para(c,x,y,value,width=390,size=12,leading=20,color=INK):
 for raw in value.split('\n'):
  line=''
  for ch in raw:
   if pdfmetrics.stringWidth(line+ch,'CN',size)>width:
    text(c,x,y,line,size,color);y-=leading;line=''
   line+=ch
  text(c,x,y,line,size,color);y-=leading
 return y
def image(c,p,x,y,w,h):
 c.setFillColor(HexColor('#E6E4D7'));c.roundRect(x,y,w,h,6,fill=1,stroke=0)
 c.drawImage(ImageReader(str(p)),x,y,width=w,height=h,preserveAspectRatio=True,anchor='c',mask='auto')
def base(c,n,kicker,title):
 c.setFillColor(HexColor(PAPER));c.rect(0,0,W,H,fill=1,stroke=0)
 text(c,38,564,'种日子  /  GAME DESIGN & SYSTEMS',11,MUTED,True)
 text(c,755,564,'WINDOWS  0.29.0',11,MUTED)
 c.setStrokeColor(HexColor(LINE));c.line(38,549,922,549)
 text(c,38,514,kicker,11,ACCENT,True);text(c,38,480,title,28,INK,True)
 text(c,38,22,'个人项目 · AI 辅助开发与美术 · 2026.10.17',10,MUTED)
 text(c,840,22,f'{n:02d} / 04',10,MUTED)
def make_pdf():
 p=STAGE/'种日子_游戏作品集.pdf';c=canvas.Canvas(str(p),pagesize=(W,H),pageCompression=1)
 c.setTitle('种日子 | 玩法、UI 与系统设计 | 0.29.0');c.setAuthor('种日子项目')
 base(c,1,'01  项目与可玩体验','把种田日常，连成有记忆的乡村生活')
 image(c,UI/'after-hud.png',38,115,568,350)
 text(c,38,91,'本轮 GPU 实际运行画面；场景、角色与 HUD 同帧绘制。',10,MUTED)
 y=441
 for big,label in [('7 × 7','主田空间与相连菜畦'),('7 种 / 16 种','牧场伙伴 / 淡水水产'),('40 个 / 266 条','引导节点 / 图鉴条目')]:
  text(c,638,y,big,25,ACCENT,True);text(c,638,y-25,label,12,MUTED);y-=86
 para(c,638,173,'个人主导玩法规划、需求取舍、视觉方向、资源筛选、集成与验收。\n程序与美术使用 AI 辅助；以实际可玩流程和保留日志核对结果。',278,12,20)
 c.showPage()
 base(c,2,'02  UI 与任务改造','让玩家看清当前状态，也知道下一步')
 image(c,ROOT/'artifacts/ui-quests-20261017/before-tasks.png',38,213,430,254)
 image(c,UI/'after-tasks.png',492,213,430,254)
 text(c,38,191,'改造前 · 旧版安排页',12,MUTED,True);text(c,492,191,'改造后 · 统一任务手记与固定操作区',12,ACCENT,True)
 para(c,38,156,'显示层：35 个面板统一纸张主题、文字层级、焦点与返回。HUD 最多追踪两项；小地图与任务栏互换位置。',424,12,20)
 para(c,492,156,'规则层：八条链可并行推进，长期任务无期限。订单主动接取；人物、柜台和施工点使用真实交付站位。',424,12,20)
 text(c,38,76,'防误操作',12,ACCENT,True)
 para(c,127,76,'材料缺口实时回退；交付完成才扣料；取消后的旧回调无效；背包满时保留待领取奖励。',786,12,20)
 c.showPage()
 base(c,3,'03  经营循环与实体反馈','把照料、收获和收集，落回世界中的对象')
 image(c,UI/'ranch-1280x800.png',38,219,430,248)
 image(c,UI/'fishing-tracking-ui.png',492,219,430,248)
 text(c,38,195,'牧场 · 七种动物与畜舍经营',14,INK,True)
 para(c,38,167,'新增山羊与兔子。亲近、健康和心情分别记录；产物从动物、地面到所属畜舍收集箱，再进入背包，保留生产日期与品质。',420,12,20)
 text(c,492,195,'水畔 · 鱼条追踪与另一条笼捕路线',14,INK,True)
 para(c,492,167,'五类鱼行为、16 种水产与四季条件。轻松辅助保留全物种收集，手动优秀表现获得珍品；笼捕次日结算，不覆盖未领产物。',420,12,20)
 text(c,38,66,'循环',12,ACCENT,True)
 text(c,96,66,'观察状态 → 准备物资 → 实际行动 → 权威结算 → 图鉴与任务留痕',13,INK,True)
 c.showPage()
 base(c,4,'04  技术结构与验证边界','用规则、实际流程和独立成品三层核对')
 for x,t,sub in [(38,'统一玩家入口','GameState 动作与存取'),(340,'独立规则模块','任务 / 钓鱼 / 畜产流转'),(642,'界面与世界表现','快照 / 事件 / 真实导航')]:
  c.setFillColor(HexColor('#E9EBDD'));c.roundRect(x,373,280,82,7,fill=1,stroke=0)
  text(c,x+17,424,t,17,INK,True);text(c,x+17,396,sub,12,MUTED)
 text(c,38,338,'本轮重新运行',15,ACCENT,True)
 rows=json.loads((OUT/'tests.json').read_text(encoding='utf8'))
 para(c,38,310,f'{len(rows)} 组专项 / 回归，{sum(r["passed"] for r in rows):,} 个通过断言，0 失败。\n40 节点走通；112 天订单模拟；49 格主田实际行走浇水。\n960×600、1280×800、1280×720 GPU 检查，含大字、高对比与减少动效。',884,13,24)
 text(c,38,195,'可以现场演示',15,ACCENT,True)
 para(c,38,168,'解压 Windows 试玩包，双击 ZhongRiZi.exe；无需编辑器与联网。\nJ 任务手记 / B 背包 / M 地图 / Tab 菜单 / WASD 移动 / E 互动。\n源码摘选、测试日志、生产包 SHA-256 与独立启动记录随作品集提供。',884,13,24)
 para(c,38,76,'验收边界：输入为自动化事件模拟；触控在 Windows GPU 上模拟，未宣称 Android 实机或实体手柄验收。\n测试通过不等于人工完整通关；开发工程保留完整资源，作品集源码摘选不包含全部美术。',884,10,17,MUTED)
 c.save();return p

def main():
 STAGE.mkdir(parents=True,exist_ok=True)
 shots=STAGE/'实机画面';shots.mkdir(exist_ok=True)
 sources=[('01-村庄与紧凑HUD.png',UI/'after-hud.png'),('02-任务手记.png',UI/'after-tasks.png'),('03-五组生活菜单.png',UI/'after-menu.png'),('04-背包与物品经济.png',UI/'after-bag.png'),('05-牧场名册.png',UI/'ranch-1280x800.png'),('06-鱼条追踪.png',UI/'fishing-tracking-ui.png'),('07-全图鉴.png',UI/'knowledge-1280x800.png'),('08-家常烹饪.png',UI/'kitchen-960x600.png'),('09-邻里面对面.png',UI/'dialogue-1280x800.png'),('10-村庄地图.png',UI/'map-final-1280x800-1.00.png')]
 for name,p in sources:shutil.copy2(p,shots/name)
 (shots/'截图说明.txt').write_text('全部来自本轮 Windows GPU 实际运行帧，未用概念图代替。测试通过自动化切换界面和事件模拟采集；不表示 Android 实机或人工长期游玩验收。\n',encoding='utf8')
 core=STAGE/'核心源码与说明';core.mkdir(exist_ok=True)
 src=core/'Godot源码摘选';src.mkdir(exist_ok=True)
 for folder in ['scripts','scenes','data']:
  shutil.copytree(ROOT/folder,src/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
 shutil.copy2(ROOT/'project.godot',src/'project.godot')
 (core/'技术说明.md').write_text('''# 源码阅读路线

源码摘选与 Windows 0.29.0 对应，包含当前脚本、数据与场景，未附全部美术和音频，不能单独作为完整可运行工程。

1. `scripts/quest_service.gd` 与 `data/quests.json`：任务定义、真实进度、接取、来源和一次性结算。
2. `scripts/ui_shell.gd`、`hud_layout.gd`、`life_plan_panel.gd`：界面栈、情境 HUD、任务视图和焦点返回。
3. `scripts/fishing_rules.gd`、`fishing_session.gd`、`fishing_service.gd`：生态选择、连续会话与鱼获转移。
4. `scripts/ranch_care.gd`、`ranch_products.gd`：日常照料和实体产物的统一记录。
5. `scripts/native_save_rules.gd`、`quest_save_rules.gd`：当前格式校验和任务凭据，原子存取入口见 save_repository。

GameState 保留玩家操作入口。界面发出命令、读取快照，不直接发奖励。当前格式版本 33，任务版本 1，本轮不提供旧档迁移。

个人主导玩法、视觉与取舍，使用 AI 辅助实现及美术；所列模块不应描述为未经辅助的独立手写成果。
''',encoding='utf8')
 evidence=core/'验证记录';evidence.mkdir(exist_ok=True)
 for p in OUT.glob('*.log'):
  if p.stem in {r['name'] for r in json.loads((OUT/'tests.json').read_text(encoding='utf8'))}:shutil.copy2(p,evidence/p.name)
 shutil.copy2(OUT/'tests.json',evidence/'本轮测试汇总.json')
 (STAGE/'提交说明.txt').write_text('''《种日子》游戏作品集 | Windows 0.29.0 | 2026-10-17

建议先阅读四页 PDF；需要技术细节时查看核心源码与说明和本轮验证日志。Windows试玩目录提供最新原生包，解压后双击 ZhongRiZi.exe，无需 Godot 或联网。

本版包含 7×7 主田、七种动物、16 种水产、266 条图鉴，以及八条引导链和40个任务节点。J 打开任务手记，B 背包，M 地图，Tab 菜单，E 互动。

源码摘选未包含全部美术和音频，不能直接运行；完整开发工程保留在本机。个人主导玩法、视觉、集成与验收，使用 AI 辅助代码和美术。触控为 Windows GPU 模拟，未宣称移动实机或实体手柄验收。

根目录的轻量投递 ZIP 不含游戏二进制；试玩包可单独发送，避免反复把大游戏包压进展示附件。旧版浏览器原型已从当前作品集移除，仍在开发工程中保留。
''',encoding='utf8')
 (STAGE/'简历项目描述与面试要点.md').write_text('''# 简历项目描述

**《种日子》｜中式乡村生活经营游戏｜个人项目｜Godot 4.7 / GDScript / Windows 0.29.0**

围绕种植、畜牧、钓鱼、料理与邻里生活设计经营循环；完成 7×7 主田、七种动物和16种水产的系统整合。统一35个界面面板，设计八条引导链40个任务节点，接通真实办理地点、材料缺口、主动限时订单与266条图鉴。通过取消保护、交付复核和奖励凭据避免重复结算；保留本轮独立规则、GPU、112天模拟和导出成品验证记录。

个人主导玩法规划、视觉方向、需求取舍、资源筛选、集成及验收；使用 AI 辅助程序开发与美术制作。

## 面试讨论

1. **任务不是按钮列表：**区分拥有、亲自产出、接取后动作和提交材料；用事件起点和结算编号处理重复回调与取消。
2. **画面服务操作：**任务和小地图共享左上区域，情境 HUD 让出操作区；界面栈保存来源和焦点，避免世界输入穿透。
3. **对象与账目统一：**鱼获、笼捕和畜产保留品质、数量与生产日期，显示层从真实记录派生。
4. **分层验证：**规则与真实动作、GPU 多分辨率、脱离工程目录的成品启动分别验证。自动化断言不等于人工完整通关。

## 交付边界

当前交付 Windows x86_64。横屏触控和手柄使用输入事件模拟，未宣称 Android 实机或实体手柄验收。源码摘选不是带全资源的独立工程。早期 Canvas 原型保留于开发工程，不与新版成品混放。
''',encoding='utf8')
 make_pdf()
 rows=[{'path':str(p.relative_to(STAGE)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':digest(p)} for p in STAGE.rglob('*') if p.is_file()]
 (core/'文件校验清单.json').write_text(json.dumps({'version':'0.29.0','files':rows},ensure_ascii=False,indent=2),encoding='utf8')
 print('PORTFOLIO_STAGE_READY',STAGE,len(rows))
if __name__=='__main__':main()
