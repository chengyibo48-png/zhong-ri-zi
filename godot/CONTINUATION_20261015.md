# 0.26.1 继续优化与验收（2026-10-15）

本轮工作始于 10 月 14 日，最终验收于 10 月 15 日完成；发行目录沿用 `20261014-0.26.1` 批次名。在 0.26.0 基础上补齐存档保护、模块拆分和电脑/手机设置。旧发行文件与历史失败记录保留。主清单见 [当前状态](CURRENT_STATUS_20261014.md)。

## 本轮修改

- 原生存档增加深层结构、有限数值、品质索引、库存数量、深度与节点预算检查。主要玩法字段损坏时，在修改内存或写导入回退档前拒绝。
- 保留原有可恢复字段的归一化语义：损坏的邻里手记按条重置，坏 NPC 位置恢复安全位置，旧标量钓鱼表和 Unicode 厨房任务标识保持可读；钓鱼界面与结算增加安全访问。
- 读写文件统一限制 16 MiB；浮点精度附加记录最多 20,000 条，路径最多 64 层。超过读取器能力时拒绝写入，保护现有文件。
- 提取 `native_save_snapshot.gd`、`npc_social_profile.gd` 和玩家设置归一化。主状态脚本从 8,824 行降至 8,674 行，现有 469 个调用入口保留。后续仍可按玩法子系统继续拆分。
- 设置页新增“画面模式：自动 / 省电”。省电模式上限 30 帧，修改及读档后立即生效；自动模式对 Intel/常见 AMD 集显名称采用 60 帧上限，手机维持 30 帧上限。
- 网页设备判断缓存，避免反复跨 JavaScript 查询。Windows 触屏笔记本保持电脑布局，iPad 桌面 UA 按触屏设备识别。设置页正确显示保存的对话文字速度。
- 发行工具统一读取导出配置中的版本，并记录生产代码指纹。导出临时文件与浏览器检查配置也写入 D 盘，私有签名文件保持在本地。

## 最终验证

- 完整注册回归：203 组通过、0 失败，40,017,570 项断言；源代码及原网页规则在运行中保持不变。
- 实际 GPU 画面：434 项通过；手机尺寸的触控、菜单、存档滚动、大字界面和竖屏暂停通过。
- Chromium 中模拟 iPhone/Android：可信触摸、中文显示、存档下载与导入通过，控制台无新增错误；下载的 JSON 在原生版读写 4 项通过。
- 连续运行 600 秒、77,386 帧，跨 112 天、16 次存档往返，35 项通过、0 失败。
- Windows ZIP 清单与独立资源包 GPU 检查 1,633 项通过，实际 EXE 在空目录启动通过。
- Web ZIP 16 个文件逐字节核对；Android 包版本 0.26.1、包名、v2/v3 签名、ARM64/ARMv7 与 16 KiB 对齐通过。

生产代码 SHA-256：`492db2d286d4095e89b836f025f48601e84b6ffd6904422dc40d3bb368cf1a99`。

## 发行文件

| 文件 | 体量 | SHA-256 |
| --- | ---: | --- |
| [种日子-Windows-0.26.1.zip](build/releases/20261014-0.26.1/种日子-Windows-0.26.1.zip) | 227.4 MiB | `a43fdd133d6491864f83653a4cee9c700d2b167ef7bfef46973d26d518d8a69b` |
| [种日子-Web-0.26.1.zip](build/releases/20261014-0.26.1/种日子-Web-0.26.1.zip) | 69.2 MiB | `05169656811ba14271b4fb70042e9b1d5b91e172813a4061af87d68ba64dfb78` |
| [种日子-Android-0.26.1.apk](build/releases/20261014-0.26.1/种日子-Android-0.26.1.apk) | 322.9 MiB | `4057837b7d6032e20e819a4a1724f1d474c28f893794e6d444cf315c0fea5167` |
| [种日子-Android-0.26.1.zip](build/releases/20261014-0.26.1/种日子-Android-0.26.1.zip) | 152.1 MiB | `9f07e42f2944e1b126f1e3312cf4f8dffe6281f1f049c5a17d051ef1ded98f9a` |

Windows ZIP 解压后运行 EXE；Android 可直接安装 APK。Web ZIP 用于 HTTPS 托管或本机/局域网预览，尚未发布公网地址。手机网页覆盖目标包括安卓和 iPhone；原生安装包为 Android。

## 本机帧时间

实际设备为 RTX 3060 Laptop GPU，四场景各 240 帧采样。以下是本机结果，不能替代集显或真实手机验收，也不据此宣称所有场景均提速。

| 场景 | P95 帧时间 ms | 显存 MiB |
| --- | ---: | ---: |
| farm_960 | 10.257 | 224.0 |
| town_1280 | 10.27 | 248.2 |
| winter_1920 | 10.287 | 307.6 |
| interior_night | 4.955 | 299.7 |

## 仍待完成的验收与收尾

真实集显笔记本、安卓手机与 iPhone Safari 尚未连接；完整人工年度试玩、实际听感与小时级稳定性仍需实测。10 分钟加速跨年和设备模拟不替代这些证据。

三季夜景仍采用季节原画与专用着色器，复杂动作仍包含连续变形；本轮没有新增独立夜景/动作手绘位图。主状态脚本仍较大，深层业务关系的完整组合审计和对白文学润色继续列为后续工作。

## 证据

- [完整回归报告](artifacts/verification-20261014-232500/report.json)
- [GPU 画面报告](artifacts/continuation-20261014/visual-report.json)
- [连续运行报告](artifacts/continuation-20261014/soak-report.json)
- [移动包验收](artifacts/continuation-20261014/mobile-package-verification.json)
- [Windows 包验收](artifacts/continuation-windows-package-render.json)
- [手机网页存档页](artifacts/continuation-20261014/browser-saves-final.png)
- [竖屏暂停](artifacts/continuation-20261014/browser-portrait-final.png)
- [存储迁移记录](STORAGE_MIGRATION_20261014.md)
