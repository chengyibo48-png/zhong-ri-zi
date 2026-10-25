# UI 显示与任务系统：实施与验收

2026-10-17 · Godot 主版本。工程目录：`D:\.codex\游戏2\godot`。

本轮已完成 UI 与任务框架、40 个引导节点、真实交付和独立验证。未导出游戏包，未增加旧档迁移。当前格式存档版本为 33，任务数据版本为 1。

## 玩家现在如何使用

- 默认 **J 打开任务手记**，也可点击 HUD 左上入口。键位可在设置中改绑；手柄 View 打开手记，肩键切页，A 确认，B 返回。
- 手记包含进行中、可接取、已完成和今天的打算；支持分类、搜索及期限筛选。每天的建议可忽略，没有清空奖励或连续签到要求。
- 详情明确列出当前步骤、材料数量、品质、保护状态、办理地点、开放条件、期限和回报。交付／领取按钮固定在详情底部，长说明在上方滚动。
- “查来源”连接真实图鉴；“在地图查看”设置合法目标；“沿路去看看”由玩家主动开始寻路，方向键或 Esc 可停止。
- 邻里交付必须靠近实际人物，合作订单在合作社交接点办理，柜台时间 **08:00—20:00**；公共项目在四处实际立牌站位共同动工。
- 主线、人物与引导任务无期限。合作订单主动接取，显示截止日，接取后条件固定。过期或放弃不扣钱与关系，未交物资仍在背包。

## UI 的实际改造

主菜单改为随身、经营、乡里、手记、系统五组，任务、背包和地图保持快捷入口。HUD 将日期、时间、天气和零钱集中到右上，工具与体力留在底部；左上最多固定两项任务，可折叠，与展开的小地图互相替换。新任务和完成提醒合并显示，可领／可交数量使用短文字提示，没有持续闪烁。

保留原有纸张、瓷色和木色主题，统一按钮、分页、焦点、边框、文字层级与高对比状态。正文以 18 号为基准，次要说明至少 16 号，紧凑 HUD 至少 14 号；文字放大时通过重排与滚动容纳。地图原先 10 号的地区名改为可缩放的至少 14 号标签，走访和图钉统计移到可缩放正文区域。

共享界面壳应用到 **35 个注册面板、37 类业务视图**，包括背包、仓库、地图、日历、种植、牧场、钓鱼、厨房、加工、火候、建造、设施、工具、技能、人物、对话、故事、图鉴、村史馆、邮件、家、设置及关系确认等。物品筛选行可换行，数量、品质、鲜度、保护与交易报价继续调用真实规则。

统一界面栈区分“关闭页面”和“进入子页”。子页返回恢复来源选择、滚动与焦点；按钮重建后按语义恢复焦点。显式关闭的旧页面不会在下一帧重新打开并取消批量农活。执行操作时可暂时离开界面，原有回调返回流程保留。

钓鱼、烹饪和建造使用情境界面；钓鱼追踪避让资源栏，隐藏普通工具和移动按钮。设置打开、失焦及暂停会冻结钓鱼会话，并清除按住输入。触控操作目标至少 48 逻辑像素，考虑安全边距。

## 任务内容与结算

| 引导链 | 节点数 |
|---|---:|
| 安顿小院 | 6 |
| 第一季农事 | 6 |
| 牧场伙伴 | 5 |
| 水畔手记 | 5 |
| 一碗家常 | 5 |
| 邻里往来 | 5 |
| 村庄共建 | 4 |
| 四季留痕 | 4 |

40 个节点全部通过真实操作入口完成验证。已有邻里心愿、顺路帮忙、四项公共项目、合作订单、人物故事与四季章节进入同一任务视图；原有剧情选择、配方解锁及奖励仍由原系统结算，不在手记重复发放。

人物故事在相识后逐步出现，后续章节不会整条铺开；已完成的故事和章节保留在任务历史中。引导可并行推进，季节条件尚未满足时说明等待原因，不以全收集或珍品阻挡年度回看。

任务明确区分拥有、亲自操作、接取后完成和交付。小院原有庄稼不会伪造亲自播种，购买鱼也不会增加亲自捕获；要求接取后完成的目标保存起点。材料用掉后，可交付状态立即回退。

交付动作有独立操作编号。执行结束重新核对地点、人物、日期、期限及材料；取消、读档后的旧回调和重复点击不能补结算。按合格品质与鲜度选料，剩余批次保留数量、品质和生产日。回礼容量不足时保留领取资格，整理后再领。

## 模块与当前格式存取

- `quest_service.gd` 管理任务定义、进度快照、来源、接取、交付和领奖；`data/quests.json` 配置八条引导链与柜台时间。
- `GameState` 保留 `quest_snapshot`、`quest_accept`、`quest_pin`、`quest_track`、`quest_submit`、`quest_claim`、`quest_abandon` 和 `quest_event` 入口，通过任务变更事件刷新界面。
- `ui_shell.gd` 负责界面栈、返回与安全范围；HUD 分区、任务浮层及共用主题分别管理显示职责。
- `quest_save_rules.gd` 是不依赖 UI 或 autoload 的纯校验模块，避免早期加载存档规则时引入图形依赖。

当前存档保存接取日、截止日、定义快照、进度起点、已完成／领取凭据、提醒状态和最多两项追踪选择。未完成的交付动作属于瞬时状态，读档后不能重放；可交付与待领取状态由保存的真实记录重新派生。当前格式内存和磁盘往返均已验证。

## 本轮独立验收

以下日志均为本轮重新运行，失败数为 0。断言数量包含参数化规则与布局检查，不代表相同数量的人工游玩案例。

| 验证范围 | 通过断言 | 失败 | 证据 |
|---|---:|---:|---|
| 任务规则、动作回调与守恒 | 133 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_rules.log) |
| 40 节点真实玩法流程 | 175 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_content.log) |
| 112 天订单与长期任务 | 1,188 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_seasons.log) |
| 真实施工站位、人物与输入 | 48 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_walk.log) |
| 主要界面 GPU／主题／字号 | 316 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_gpu.log) |
| 其余注册面板 GPU | 140 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_extra_gpu.log) |
| 触控与实时钓鱼暂停 | 185 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_touch.log) |
| 辅助面板触控与大字号 | 70 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_extra_touch.log) |
| 全部 37 类视图横屏触控 | 610 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_all_touch.log) |
| 地图文字专项 GPU | 42 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_map_gpu.log) |
| 最终核心画面与返回焦点 | 23 | 0 | [日志](artifacts/ui-quests-20261017/ui_quest_final_capture.log) |
| 七种动物牧场回归 | 979 | 0 | [日志](artifacts/ui-quests-20261017/ranch_overhaul_smoke.log) |
| 厨房回归 | 29 | 0 | [日志](artifacts/ui-quests-20261017/kitchen_smoke.log) |
| 经济回归 | 12 | 0 | [日志](artifacts/ui-quests-20261017/economy_smoke.log) |
| 土地回归 | 394 | 0 | [日志](artifacts/ui-quests-20261017/farming_soil_smoke.log) |
| 种植框架回归 | 37 | 0 | [日志](artifacts/ui-quests-20261017/farming_redesign_smoke.log) |
| 钓鱼规则与守恒回归 | 11,563 | 0 | [日志](artifacts/ui-quests-20261017/fishing_overhaul_smoke.log) |
| 水产、全图鉴与来源回归 | 414 | 0 | [日志](artifacts/ui-quests-20261017/fishing_content_integration.log) |
| 7×7 主田行走浇水回归 | 1,170 | 0 | [日志](artifacts/ui-quests-20261017/farm_grid_7x7_smoke.log) |

GPU 使用 **NVIDIA GeForce RTX 3060 Laptop GPU**，桌面检查 960×600、1280×800、1280×720，另覆盖 1.25 倍文字、高对比、三种主题和减少动效。横屏触控在 1280×720 的 Windows GPU 上启用 `ZRZ_FORCE_TOUCH=1`，逻辑画面为 1066×600；完整遍历 37 类视图，检查操作尺寸、情境 HUD 和实际按下／松开信号。**这是移动布局与输入模拟，不是 Android 实机验收。**

40 节点集成验证使用真实生产、鱼条追踪、鱼获处理、次日收笼、人物交付、施工及村史馆操作。为缩短回归时间，测试提供材料并加速日期和成熟，不将其当作真人完整经营游玩。

112 天模拟执行真实 `advance_day` 和动作结算：48 张订单主动接取，16 张交付，32 张按截止日过期；四季均有候选，长期心愿跨年仍保留。此模拟验证任务生命周期与可用性，不是收益承诺或新一轮经济价格校准。

实际行走验证四个施工站位，另验证人物移动后重新定位、交付时走开不扣料、柜台 08:00／20:00 边界，以及键盘和手柄入口。7×7 回归实际走完并浇灌 49 格，不只核对静态坐标。

## 保留内容与证据

对照本轮备份，97 格总农田数据、28 种作物、七种动物配置、16 种水产规则与 266 条图鉴定义保持一致。主地图、世界布局和主田布局未变；牧场生长与原钓鱼会话规则保持原实现，仅在需要的位置接入任务记录及 UI 生命周期。

- [机器可读验收汇总](artifacts/ui-quests-20261017/validation-summary.json)
- [源码 SHA-256](artifacts/ui-quests-20261017/source-hashes.json)
- [截图尺寸与 SHA-256](artifacts/ui-quests-20261017/screenshots.json)
- [40 节点流程记录](artifacts/ui-quests-20261017/content-report.json)
- [112 天订单结果](artifacts/ui-quests-20261017/seasons-report.json)
- [施工站位与行走记录](artifacts/ui-quests-20261017/walk-report.json)
- [画面对照与完整截图索引](artifacts/ui-quests-20261017/review.html)

修改前完整脚本与数据位于验收目录 `before/`。四张“修改前”截图由该备份的完整脚本与数据在隔离基线工程中实际运行获得，未用示意图替代。

![修改前任务安排](artifacts/ui-quests-20261017/before-tasks.png)

![修改后任务手记](artifacts/ui-quests-20261017/after-tasks.png)

![修改后 HUD](artifacts/ui-quests-20261017/after-hud.png)

![地图可读性](artifacts/ui-quests-20261017/map-final-960x600-1.00.png)

## 复现

在 Godot 工程目录运行，验证器使用工程已有 Godot 4.7.2，并隔离测试存档、缓存目录与日志。

```powershell
python tools/ui_quest_validation.py --headless --script res://tools/ui_quest_rules.gd
python tools/ui_quest_validation.py --headless --script res://tools/ui_quest_content.gd
python tools/ui_quest_validation.py --headless --script res://tools/ui_quest_seasons.gd
python tools/ui_quest_validation.py --headless --script res://tools/ui_quest_walk.gd
python tools/ui_quest_validation.py --script res://tools/ui_quest_gpu.gd
python tools/ui_quest_validation.py --script res://tools/ui_quest_extra_gpu.gd
python tools/ui_quest_validation.py --script res://tools/ui_quest_map_gpu.gd
python tools/ui_quest_validation.py --script res://tools/ui_quest_final_capture.gd
$env:ZRZ_FORCE_TOUCH='1'
python tools/ui_quest_validation.py --script res://tools/ui_quest_touch.gd
python tools/ui_quest_validation.py --script res://tools/ui_quest_extra_touch.gd
python tools/ui_quest_validation.py --script res://tools/ui_quest_all_touch.gd
Remove-Item Env:ZRZ_FORCE_TOUCH
```

设计借鉴《星露谷物语》的紧凑手记、任务提醒、长期故事与主动限时委托；具体条件、数字和交付方式以本项目规则为准。[任务机制参考](https://stardewvalleywiki.com/Quests)
