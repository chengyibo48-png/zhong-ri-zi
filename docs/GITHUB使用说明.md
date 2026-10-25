# GitHub 项目使用说明

## 当前游戏

Godot 主工程位于 `godot/project.godot`，当前版本 0.29.0，Windows x86_64。安装 Godot 4.7.2，导入该工程，等待资源导入完成后按 F5 运行。Godot 会自动生成本地 `.godot/`，无需从仓库下载缓存或引擎。

可玩 Windows ZIP 位于本仓库 [v0.29.0 Release](https://github.com/chengyibo48-png/zhong-ri-zi/releases/tag/v0.29.0)，解压后运行 `ZhongRiZi.exe`。本版没有将历史 Android/Web 导出重新标记为 0.29.0。

## 目录

| 目录 | 内容 |
| --- | --- |
| `godot/scripts/`、`godot/scenes/` | Godot 游戏逻辑、UI 与场景 |
| `godot/data/`、`godot/art/`、`godot/audio/` | 规则数据、美术与音频 |
| `godot/tools/` | 回归、资源验证与导出工具 |
| `src/`、`tests/` | v0.22 浏览器原型源码与测试 |
| `docs/`、`godot/*.md` | 设计、实现及历史验收说明 |

## 检查与构建

浏览器原型无需安装 npm 依赖，安装 Node.js 后运行 `npm test`；`node server.cjs` 启动原型预览。此预览并非 Godot 当前发行版。

Godot 专项验收使用 Python 3，进入 `godot/` 后运行 `python tools/release_validation.py`。引擎路径及脚本参数以工具帮助和现有脚本为准。Windows 导出需安装对应 Godot 导出模板和 PowerShell 7，再从工程根目录运行：

```powershell
./godot/tools/build_windows.ps1 -GodotPath 'C:/Tools/Godot/Godot.exe'
```

构建文件写入忽略的 `godot/build/`。Android SDK、JDK、原签名密钥及其口令均为本地依赖，没有上传。历史文档中的机器路径为开发时记录，不是克隆后必须使用的路径。

## 验收边界

0.29.0 历史记录为 19 组专项共 17,530 个通过断言、0 失败，Windows 成品独立无界面 1,640 项与 GPU 1,641 项通过，并检查实际 EXE 启动。本次 GitHub 上传没有重新宣称跑完全部玩法回归。详见 `godot/RELEASE_20261017.md` 与 `docs/verification-0.29.0/`。

保留资源原有许可及来源记录；没有因上传仓库另行授予开源许可证。
