"""Publish factual release evidence only after the final complete verification succeeds."""
import argparse,json,re
from pathlib import Path
project=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--verification',type=Path,required=True);args=parser.parse_args()
args.verification=args.verification.resolve()
report=json.loads(args.verification.read_text(encoding='utf8'))
if report.get('failed')!=0 or not report.get('source_unchanged') or not report.get('original_source_unchanged'):raise SystemExit('Final verification is incomplete or changed')
quality=project/'artifacts/quality-20261014'
soak=json.loads((quality/'soak-report.json').read_text(encoding='utf8'))
execution=json.loads((project/'artifacts/quality-final-all-soak-20261014.execution.json').read_text(encoding='utf8'))
assert soak['failed']==0 and soak['days_advanced']==112
assert execution['source_unchanged'] and execution['source_sha256']==report['production_sha256']
release=project/'build/releases/20261014-0.26.0'
manifest=json.loads((release/'manifest.json').read_text(encoding='utf8'))
rows='\n'.join('| '+entry['name']+' | '+f"{entry['bytes']/1048576:.1f} MiB"+' | `'+entry['sha256']+'` |' for entry in manifest['files'])
before=json.loads((project/'artifacts/runtime-profile-baseline-20261014.json').read_text(encoding='utf8'))
after=json.loads((project/'artifacts/runtime-profile-final-20261014.json').read_text(encoding='utf8'))
metrics='\n'.join('| '+a['scenario']+' | '+str(b['frame_p95_ms'])+' | '+str(a['frame_p95_ms'])+' | '+f"{b['video_memory_bytes']/1048576:.1f} → {a['video_memory_bytes']/1048576:.1f}"+' |' for b,a in zip(before['measurements'],after['measurements']))
code=(project/'scripts/game_state.gd').read_text(encoding='utf8')
body=f'''# 0.26.0 六项优化与交付记录（2026-10-14）

Windows、手机网页和 Android APK 已生成；旧 0.24.1/0.25.0 保留为历史版本。详细六项实现见 [当前状态](CURRENT_STATUS_20261014.md)。

项目检查临时数据已迁移至 D 盘：2,351 个目录、8,167 个文件、23.97 GiB 均逐文件核对 SHA-256，后续检查使用项目 `.build/runtime-tmp/` 并自动清理。详见 [存储迁移记录](STORAGE_MIGRATION_20261014.md)。

## 发行文件

目录：`build/releases/20261014-0.26.0/`。Windows ZIP 解压后运行 EXE；安卓可直接安装 APK，压缩 ZIP 适合传输；网页 ZIP 用于 HTTPS 静态托管或本机 Python 预览。网页目前没有部署公网地址。

| 文件 | 体量 | SHA-256 |
| --- | ---: | --- |
{rows}

网页 PCK 从 205.4 MiB 降至 {(project/'build/web/index.pck').stat().st_size/1048576:.1f} MiB。WebP 质量 0.82；建筑限 256、室内背景限 512，角色图集尺寸与原始 PNG 保留。安卓采用 GPU 纹理压缩，保留地面、家具及 UI 的无损像素读取；APK 原始体量较大，以 ZIP 分享可缩小传输体量。电脑版保留原画与基础 S3TC 背景格式。

## 最终验收

- 完整注册检查：{report['passed']} 组通过、0 失败，{report['checks']:,} 项断言；验收过程中源代码及原网页规则指纹保持不变。
- 实际 GPU 画面：434 项检查；覆盖 47 栋建筑的四季夜景、室内昼夜亮度、动作板、静止 HUD 事件刷新及 -1 dB 声音峰值限制。
- 手机尺寸实渲染：摇杆移动与释放、背包、存档滚动、大字火候页、竖屏暂停；均通过。
- 浏览器可信触摸、中文显示、存档下载/重新导入、跨端原生读写通过；Chromium 中模拟 iPhone 与安卓尺寸，控制台无新增错误。
- 连续原生运行：{soak['seconds']:.0f} 秒、{soak['frames']:,} 帧、112 天、{soak['roundtrips']} 次存档往返、{soak['passed']} 项通过，跨四季及年度边界。
- Windows ZIP 清单、嵌入 EXE 资源及空目录 GPU 启动检查：1,633 项通过。
- 安卓 APK 的 v2/v3 签名、ARM64/ARMv7、16 KiB 对齐、包名/版本和字体许可证通过；安卓纹理副本实际 GPU 检查 434 项通过。
- 边界修复包括原生 JSON 坏版本类型、农地数值照料、场景退出回调、同帧交互缓存、新手卡/火候页字号及通知标签样式。历史失败日志保留，未作为最终通过证据。

## 本机性能范围

实际适配器：RTX 3060 Laptop GPU。每场景 180 帧预热、240 帧采样，关闭垂直同步及帧上限。数字反映本机四个场景；不使用含义异常的原始 `TIME_PROCESS` 监控值宣称 CPU 提速。

| 场景 | 原始 P95 帧时间 ms | 当前 P95 帧时间 ms | 显存 MiB |
| --- | ---: | ---: | ---: |
{metrics}

HUD 无条件逐帧刷新已改为事件合并与限频，静止时避免无条件查询，移动时限频 20 Hz；明确刷新保留实时查询，避免同帧目标过期。手机为 30 帧上限，Intel 集显检测或强制轻量模式为 60 帧上限。帧上限不构成最低设备帧时间认证。

## 仍需实机或人工证据

本机显卡枚举只有 RTX 3060 与虚拟显示驱动，ADB 没有连接安卓设备。真实集显笔记本、安卓手机、iPhone Safari，以及完整人工年度试玩、实际听感和长期小时级稳定性仍待验收。10 分钟自动运行与加速年度切换不等同这些项目。

四季夜景中，春季为已有独立夜间原画，夏秋冬为对应季节原画与专用夜景着色器；没有新增三季独立夜景位图。陈设和复杂动作采用已有原画加逐帧姿态/连续变形，未宣称所有动作均完成独立逐帧手绘。

GameState 当前仍为 {len(code.splitlines()):,} 行、{len(re.findall(r'^func ',code,re.M))} 个函数。已提取存档仓库、原生校验、外观归一化、交互调度、陈设动作和移动控制；完整深层原生存档审计、玩法子系统继续拆分及对白文学润色仍是后续工作。对白速度/标点停顿、可选首周四季提示和声音峰值控制已落地。

## 证据与维护

- [完整回归报告]({args.verification.relative_to(project).as_posix()})
- [运行报告](artifacts/quality-20261014/soak-report.json)
- [移动包验收](artifacts/quality-20261014/mobile-package-verification.json)
- [纹理副本配置](artifacts/quality-20261014/mobile-variant.json)、[网页压缩配置](artifacts/quality-20261014/web-variant.json)
- [浏览器手机截图](artifacts/quality-20261014/screenshots/browser-android-landscape.png)
- [室内夜景](artifacts/quality-20261014/screenshots/home-an-night.png)

安卓后续更新需要保留 `.build/android-signing/` 的私钥及本地口令文件；它们未包含在分享包里。Noto 中文字体及 OFL 许可证随三端发行。
'''
(project/'QUALITY_RELEASE_20261014.md').write_text(body,encoding='utf8')
print('QUALITY_RELEASE_REPORT_READY')
