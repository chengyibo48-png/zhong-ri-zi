# 钓鱼系统与全图鉴优化：实施与验收

日期：2026-10-17。工程：`D:\.codex\游戏2\godot`。本轮在 Godot 主版本完成实现和测试，未导出游戏包。旧存档迁移不在本轮范围内；当前格式存取已验证。

## 已完成的玩法

钓鱼现在由准备、蓄力抛竿、等漂、提竿、追踪、鱼获处理组成。追踪结果决定成功或失败，取消原先固定动作时间决定收竿的流程。默认轻松辅助扩大控制范围、缓和突进并自动提竿；手动模式保留提竿窗口。按住上升、松开下降，支持切换操作，键鼠、手柄和触控共用会话命令。首次教学不减少进度。失焦和设置界面冻结会话并清除按住状态，异常会话有超时。

水产共 16 种：鲫鱼、河虾、泥鳅、河蟹、鲈鱼、鲤鱼、草鱼、鲢鱼、鳙鱼、鳊鱼、鲶鱼、黄颡鱼、青鱼、马口鱼、田螺、河蚌。五处水域共用唯一生态规则；季节、天气、时段、捕获方式先筛选，再使用可保存的随机状态加权抽取。五类行为分别配置速度、停顿、预警和难度。河虾、河蟹、田螺、河蚌通过笼捕，泥鳅兼容两种方式，其余鱼类通过垂钓。

三阶鱼竿提供 0／1／2 个钓具槽。稳漂、缓流坠、集鱼铃分别改善控制、脱离容错和等待时间，无耐久维护。免费基础饵与三种专用饵均已接入，专用饵由食材批量制成。鱼饵只能调整合法鱼池内的权重。轻松辅助和笼捕最高为上品，珍品要求完整手动中的优秀表现；普通收集目标不要求珍品。

12 个合法笼位可同时部署 8 个竹编捕笼，显示空笼、投饵、待领与停机原因。投饵后次日结算，未领取时保留原物并停产。收取、补饵、拆除使用不同操作；批量操作逐个走到位置执行，取消保留已完成结果，资源不足时停止。

新水产接通出售、赠礼、保鲜、鱼干和食材分类。新增葱香田螺、萝卜河蚌汤使用独立料理资源，已运行实际烹饪验证。鱼肉、虾蟹、螺蚌的替代关系分开配置。

## 画面、入口与操作

靠近六处钓鱼站位打开“水畔垂钓手记”，可切换准备与钓具、岸边捕笼、水产手记。选择近、中、远落点后抛竿；按住操作键蓄力，松开落水。切换操作模式使用两次按键完成蓄力与落水。追踪阶段按住上升、松开下降；手动咬钩时再次操作提竿。键盘交互映射或空格、手柄 A、屏幕操作按钮共用规则，取消保留已支付的本竿成本。

鱼线连接人物鱼竿与实际浮漂落点。复用现有手绘人物抛竿、等漂、收线和收获动作，修复阶段名不匹配引起的几何回退。水岸增加落水波纹、咬钩、鱼影热点、跃水和收获／放流反馈。热点缩短等待时间。触控钓鱼时隐藏普通移动控件，为追踪按钮留出空间。

校正荷塘与清泉站位，六处站位的 18 个近中远落点以及 12 个笼位均验证处于真实水面，站位具备从公共道路抵达的路径。未改写主地图、主田或牧场通道数据。

新增 20 张独立透明图标：11 种水产、3 种钓具、3 种饵、捕笼及 2 道料理。原始图集、生成提示和修整记录保存在 [美术来源记录](art/sources/fishing-20261017/provenance.json)，正式图标在 `art/icons/items/`。鱼类图集经过间距修整，避免相邻切片裁断鱼尾。

## 全图鉴

统一注册表包含 266 条知识条目、214 个物品定义。便携手册和村史馆读取同一套发现与收集记录；修复 `fish`／`item:fish` 键不一致。图鉴保留分类、搜索、未完成、本季可得、当前可得、可研究筛选及当前选择。

未发现条目显示剪影和真实来源线索。已发现水产显示生态条件、方式、行为、尺寸、饵料与用途，捕获后显示首次捕获、数量、最佳尺寸、最高品质、手动表现和放流记录。购买只增加获得记录，不伪造捕获次数或尺寸。出售、加工和捐赠不会清除发现记录。

作物展示真实种子、生长和加工信息；动物展示居所、饮食、成年、生产周期和产物；料理与加工连接实际配方。24 位人物使用原有个性、身份、初识对白和家庭资料，按相识、研究和故事进度逐步展示。野生伙伴显示观察进度与真实出没条件。所有条目有可加载图片，所有 266 条来源指引均验证具备合法可达站位；种子、厨房和牧场加工指向实际办理地点。

## 结算与存档边界

- `fishing_rules.gd` 管理生态与装备，`fishing_session.gd` 管理追踪模拟，`fishing_service.gd` 管理扣费、鱼获、捕笼和记录；玩家动作仍通过 `GameState` 入口调用。
- 有效落水时只扣一次鱼饵、体力和游戏时间。落水前取消免费，落水后取消不退款；失败和放流不回退随机状态。
- 会话编号和已结算标记阻止重复回调发物。待处理鱼获随存档保留，保留／放流只执行一次；背包满时保留待处理结果。读档后的已支付中断会话不重复收费或发奖。
- 笼内产物保存数量、品质和生产日；领取沿用生产日与温度折算的保鲜进度，背包满时仍留在笼内。未领取跨日不覆盖，不重复扣饵。
- 当前原生存档版本 32、钓鱼数据版本 2。仅接受当前格式，没有加入旧档迁移；旧钓鱼格式明确拒绝，避免进入界面后访问缺失字段。

## 本轮验证

所有下列日志来自本轮实际运行，失败数均为 0。参数化断言数量用于定位回归范围，不代表相同数量的独立人工测试场景。

| 验证范围 | 通过断言 | 失败 | 证据 |
|---|---:|---:|---|
| 规则、会话与守恒 | 11,563 | 0 | [日志](artifacts/fishing-overhaul-20261017/fishing_overhaul_smoke.log) |
| 全图鉴、来源及内容集成 | 414 | 0 | [日志](artifacts/fishing-overhaul-20261017/fishing_content_integration.log) |
| 水岸行走与真实输入 | 127 | 0 | [日志](artifacts/fishing-overhaul-20261017/fishing_overhaul_walk.log) |
| GPU 画面与三种分辨率 | 140 | 0 | [日志](artifacts/fishing-overhaul-20261017/fishing_overhaul_render.log) |
| 横屏触控策略 | 15 | 0 | [日志](artifacts/fishing-overhaul-20261017/fishing_touch_render.log) |
| 26 组四季经营模拟 | 16,472 | 0 | [日志](artifacts/fishing-overhaul-20261017/fishing_economy_seasons.log) |
| 七种动物牧场回归 | 979 | 0 | [日志](artifacts/fishing-overhaul-20261017/ranch_overhaul_smoke.log) |
| 厨房回归 | 29 | 0 | [日志](artifacts/fishing-overhaul-20261017/kitchen_smoke.log) |
| 经济回归 | 12 | 0 | [日志](artifacts/fishing-overhaul-20261017/economy_smoke.log) |
| 土地回归 | 394 | 0 | [日志](artifacts/fishing-overhaul-20261017/farming_soil_smoke.log) |
| 7×7 主田行走与浇水 | 1,170 | 0 | [日志](artifacts/fishing-overhaul-20261017/farm_grid_7x7_smoke.log) |
| 种植框架回归 | 37 | 0 | [日志](artifacts/fishing-overhaul-20261017/farming_redesign_smoke.log) |

关键证据包括：16 种水产实际获取与当前格式存取、购买与捕获区分、重复结算、放流、满背包、保存随机状态、跨日笼捕、保鲜日期、五类鱼行为、辅助与手动品质上限、真实键盘／手柄／触控信号、失焦和设置恢复。

图形验收使用 RTX 3060 Laptop GPU，在 960×600、1280×800、1280×720 检查界面与四向手绘钓鱼动作，覆盖昼夜、雨雪、遮挡和减少动效。横屏触控通过 Windows GPU 启用真实移动布局策略 `ZRZ_FORCE_TOUCH=1` 验证；1280×720 对应逻辑画面 1066×600，检查操作按钮至少 48 逻辑像素。**此项为触控布局与输入模拟，没有声称通过 Android 实机验收。**

对照备份确认：97 块总农田数据、28 种作物定义、七种动物牧场配置未改变；主地图与布局、主田布局脚本以及牧场照料／产物／繁育模块哈希保持一致。另运行 49 格主田的实际行走浇水与牧场回归。

机器可读的 [验收汇总](artifacts/fishing-overhaul-20261017/validation-summary.json)、[源码与美术 SHA-256](artifacts/fishing-overhaul-20261017/source-hashes.json) 和 [水岸坐标证据](artifacts/fishing-overhaul-20261017/water-geometry.json) 随工程保存。修改前脚本和配置位于同一验收目录的 `before/`。

## 四季经营比较

实际执行 26 组各 112 天模拟：2 种模式 × 4 种饵 × 3 套装备，另有 2 组八笼路线。全部季节有收获目标；专用饵改变目标权重，快速路线节约游戏时间，手动优秀追踪增加品质收益，笼捕补足独有水产。

下表取草香饵路线。售价调用游戏真实 `sale_quote`，食材和装备制作材料按基础价格计成本，竿具升级与捕笼计入投入。追踪由确定性稳定控制器操作，属于规则与收益比较模型；不等同于真人成功率、完整经营游玩或玩家收益承诺。

| 路线 | 收获数 | 总售价 | 饵成本 | 设施钓具投入 | 净值 | 游戏分钟 |
|---|---:|---:|---:|---:|---:|---:|
| 轻松辅助／基础竿 | 672 | 24,010 | 1,344 | 0 | 22,666 | 16,800 |
| 轻松辅助／稳漂＋缓流坠 | 672 | 28,079 | 1,344 | 478 | 26,257 | 16,800 |
| 轻松辅助／稳漂＋集鱼铃／快速收线 | 672 | 28,079 | 1,344 | 486 | 26,249 | 10,080 |
| 完整手动／基础竿 | 672 | 24,010 | 1,344 | 0 | 22,666 | 16,800 |
| 完整手动／稳漂＋缓流坠 | 672 | 33,913 | 1,344 | 478 | 32,091 | 16,800 |
| 完整手动／稳漂＋集鱼铃／快速收线 | 672 | 33,913 | 1,344 | 486 | 32,083 | 10,080 |
| 8 个捕笼 | 838 | 26,124 | 1,680 | 1,000 | 23,444 | 5,028 |

完整结果见 [26 组经营数据](artifacts/fishing-overhaul-20261017/economy-112-days.json)。时间列为动作规则计时；笼捕路线另有地图步行成本，未折算为货币。专用饵应按目标鱼种选择，并非所有地点都高于免费饵净收益。

## 画面对照与复现

[打开画廊](artifacts/fishing-overhaul-20261017/review.html)。以下对照由修改前的备份脚本／配置和最终脚本／配置在实际 GPU 上分别渲染。

![修改前的图鉴](artifacts/fishing-overhaul-20261017/comparison-knowledge-before.png)

![修改后的图鉴](artifacts/fishing-overhaul-20261017/comparison-knowledge-after.png)

![实际追踪界面](artifacts/fishing-overhaul-20261017/tracking-gameplay.png)

![横屏触控追踪界面](artifacts/fishing-overhaul-20261017/touch-tracking.png)

在 Godot 工程目录运行以下命令，验证器会使用工程现有 Godot 4.7.2，隔离测试存档并输出日志；不涉及导出。

```powershell
python tools/fishing_validation.py --headless --script res://tools/fishing_overhaul_smoke.gd
python tools/fishing_validation.py --headless --script res://tools/fishing_content_integration.gd
python tools/fishing_validation.py --headless --script res://tools/fishing_economy_seasons.gd
python tools/fishing_validation.py --script res://tools/fishing_overhaul_walk.gd
python tools/fishing_validation.py --script res://tools/fishing_overhaul_render.gd
$env:ZRZ_FORCE_TOUCH='1'
python tools/fishing_validation.py --script res://tools/fishing_touch_render.gd
Remove-Item Env:ZRZ_FORCE_TOUCH
```

设计参考：[Stardew 钓鱼](https://wiki.stardewvalley.net/Fishing)、[鱼类](https://wiki.stardewvalley.net/Fish)、[蟹笼](https://wiki.stardewvalley.net/Crab_Pot)、[收集纪录](https://wiki.stardewvalley.net/Collections)。实际数值和资料以本项目配置及以上测试证据为准。
