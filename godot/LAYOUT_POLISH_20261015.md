# 房间、外景与近景镜头调整 · 0.26.2

日期：2026-10-15。实际工程：`D:\.codex\游戏2`。

## 本轮修改

| 项目 | 调整 |
| --- | --- |
| 游玩镜头 | 标准档外景放大 35%，室内放大 12%；原存档的镜头档位继续生效，设置内可再调近。这里调整的是二维视野范围，没有改变俯视绘画的透视角度。 |
| 家具比例 | 床、高柜、桌、椅分别设置竖向显示空间，不再统一挤进 55 像素上限；仍保持透明边缘裁切和脚底锚点。 |
| 老屋与自建家具 | 老屋床铺和各级固定家具接入手绘图；茶桌、书架、柜、工作台、展示架、育苗架按原格位绘制已有素材。 |
| 公共休息位 | 无住户的公共建筑将“整理坐垫”床形外观改为长凳，交互编号、落点和碰撞范围保留。 |
| 小物比例与落位 | 缩小搪瓷缸、部分小镜与草帽；搪瓷缸放到桌面，避免巨型杯子落在地上。 |
| 标签位置 | 修正家具名称整体偏向右侧的问题。 |
| 外景道路 | 粮仓、堆肥工具房新增两条门前步道和一段连接牧场主路的小院路面。 |
| 动物比例 | 鸡鸭缩小至相对人物合理的尺寸；手绘与特殊状态备用绘制同步调整，脚底位置不变。 |
| 手机交互布局 | 操作区按容器实际高度定位，单按钮不再压住工具栏；提示框更宽、文字更大，并随文本布局收缩高度。 |

原始 PNG 保留；本轮使用已有素材调整，没有生成新原画。存档格式、建筑门口、农田编号和通行碰撞未改。

## 检查范围和结果

- 素材清单 337 个条目、983 条不同 PNG 路径：缺失 0；46 套预设房间家具种类均有对应素材，世界 PNG 完全重复组 0。见 [素材审查](artifacts/layout-polish-20261015/asset-review.json)。
- 742 个外景物件显示范围审查：352 个已规划陈设产生的重叠为 0；25 组固定物件显示范围相交保留为审查项，其中包含树冠、石头和邻接设施，不能直接当作 25 处碰撞错误。见 [范围审查](artifacts/layout-polish-20261015/outdoor-envelopes.json)。
- [布局与入口](artifacts/layout-entrances-20261015.log)：69,279 通过、0 失败。
- [日夜、四季和动作画面](artifacts/layout-acceptance-20261015.log)：434 通过、0 失败。
- [全房间采集](artifacts/layout-final-rooms-20261015.log)：47 个房间各有日夜截图，另采集六区外景；重点房间和外景已逐图对照。采集不等于每个房间完整人工游玩。
- [手机检查](artifacts/layout-final-mobile-20261015.log)：触控移动、背包、存档、大字菜单、转屏检查失败 0。手机为 844×390 等尺寸的原生触控模拟。
- [Windows 独立包](artifacts/layout-windows-20261015-render.json)：1,633 通过、0 失败；[实际 EXE](artifacts/actual-exe-0.26.2.log) 从空工作目录启动通过。
- [移动包核对](artifacts/layout-polish-20261015/mobile-package-verification.json)：16 个 Web 文件逐字节核对、APK 签名/版本/双架构/16 KiB 对齐通过。

最终源码 SHA256：`c59473610be535ceacaeec5db78d743e38bdd11514c14d3be4826facedda6452`。上述主要检查的 execution.json 和发行清单对应同一指纹；旧版 203 组完整回归属于 0.26.1，本轮未将其算作 0.26.2 的完整回归。

## 可玩文件

- [种日子-Windows-0.26.2.zip](build/releases/20261015-0.26.2/种日子-Windows-0.26.2.zip)：227.37 MiB
- [种日子-Web-0.26.2.zip](build/releases/20261015-0.26.2/种日子-Web-0.26.2.zip)：69.21 MiB
- [种日子-Android-0.26.2.apk](build/releases/20261015-0.26.2/种日子-Android-0.26.2.apk)：322.95 MiB
- [种日子-Android-0.26.2.zip](build/releases/20261015-0.26.2/种日子-Android-0.26.2.zip)：152.12 MiB

Windows 解压后运行 ZhongRiZi.exe。Web 包需 HTTPS 或本地服务运行，浏览器包尚未公开部署。安卓包沿用原签名，版本代码 262。

## 画面对照

- [调整前手机外景](artifacts/continuation-20261014/screenshots/mobile-landscape.png) / [调整后手机外景](artifacts/layout-polish-20261015/screenshots/phone-farm.png)
- [电脑外景近景](artifacts/layout-polish-20261015/screenshots/pc-farm.png)
- [粮仓与工具房门前步道](artifacts/layout-polish-20261015/screenshots/pc-pasture.png)
- [顾安家夜景与家具比例](artifacts/layout-polish-20261015/screenshots/pc-home-an-night.png)
- [公共建筑休息长凳](artifacts/layout-polish-20261015/screenshots/pc-building-pasture-18-day.png)
- [小摆件与桌面](artifacts/layout-polish-20261015/screenshots/pc-home-granny-day.png)
- [手机房间及操作区](artifacts/layout-polish-20261015/screenshots/phone-home-an-day.png)

## 仍可继续优化

- 村史馆未修缮展柜、部分自建家具仍使用简化绘制；全套专用美术并未在本轮完成。
- 固定物件的 25 组保守范围相交可继续结合实际遮挡逐点精修。
- 真实集显笔记本、安卓手机、iPhone Safari 的画面与性能仍需设备验收。本轮 GPU 为 RTX 3060，不代表这些设备已经实测。

修改前备份位于 `artifacts/layout-polish-20261015/before/`，旧版发行目录保留。
