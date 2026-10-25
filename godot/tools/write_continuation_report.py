"""Record the continuation release only after matching complete evidence exists."""
import argparse, hashlib, json, re
from pathlib import Path
from release_config import PROJECT, VERSION, RELEASE_DIR
from verify_migration import fingerprint

parser=argparse.ArgumentParser();parser.add_argument('--verification',type=Path,required=True);args=parser.parse_args()
verification=args.verification.resolve()
report=json.loads(verification.read_text(encoding='utf8'))
assert report['failed']==0 and report['source_unchanged'] and report['original_source_unchanged']
source=report['production_sha256'];assert source==fingerprint()
manifest=json.loads((RELEASE_DIR/'manifest.json').read_text(encoding='utf8'))
assert manifest['version']==VERSION and manifest['production_sha256']==source
quality=PROJECT/'artifacts/continuation-20261014'
def execution(name):
    data=json.loads((PROJECT/'artifacts'/f'{name}.execution.json').read_text(encoding='utf8'))
    assert data['source_unchanged'] and data['source_sha256']==source and data['returncode']==0
    log=(PROJECT/'artifacts'/f'{name}.log').read_bytes()
    assert hashlib.sha256(log).hexdigest()==data['log_sha256']
    return log.decode('utf8',errors='replace')
assert '434 passed, 0 failed' in execution('continuation-visual-final-20261014')
assert 'MOBILE_QUALITY failures=0' in execution('continuation-mobile-final-20261014')
assert 'BROWSER_SAVE_ROUNDTRIP: 4 passed, 0 failed' in execution('continuation-browser-native-save-20261014')
execution('continuation-soak-final-20261014')
execution('continuation-runtime-profile-final-20261014')
soak=json.loads((quality/'soak-report.json').read_text(encoding='utf8'))
assert soak['failed']==0 and soak['days_advanced']==112 and soak['seconds']>=600
mobile=json.loads((quality/'mobile-package-verification.json').read_text(encoding='utf8'))
assert mobile['web_files_verified']==16 and mobile['alignment_verified']
windows=json.loads((PROJECT/'artifacts/continuation-windows-package-render.json').read_text(encoding='utf8'))
assert windows['failed']==0 and windows['checks']==1633
assert windows['archive_sha256']==manifest['files'][0]['sha256']
for row in manifest['files']:
    path=RELEASE_DIR/row['name']
    assert path.stat().st_size==row['bytes'] and hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']
code=(PROJECT/'scripts/game_state.gd').read_text(encoding='utf8')
lines=len(code.splitlines());functions=len(re.findall(r'^func ',code,re.M))
packages='\n'.join(f"| [{row['name']}]({(RELEASE_DIR/row['name']).relative_to(PROJECT).as_posix()}) | {row['bytes']/1048576:.1f} MiB | `{row['sha256']}` |" for row in manifest['files'])
profile=json.loads((PROJECT/'artifacts/continuation-runtime-profile-final-20261014.json').read_text(encoding='utf8'))
metrics='\n'.join(f"| {m['scenario']} | {m['frame_p95_ms']} | {m['video_memory_bytes']/1048576:.1f} |" for m in profile['measurements'])
body=f'''# {VERSION} 继续优化与验收（2026-10-15）

本轮工作始于 10 月 14 日，最终验收于 10 月 15 日完成；发行目录沿用 `20261014-0.26.1` 批次名。在 0.26.0 基础上补齐存档保护、模块拆分和电脑/手机设置。旧发行文件与历史失败记录保留。主清单见 [当前状态](CURRENT_STATUS_20261014.md)。

## 本轮修改

- 原生存档增加深层结构、有限数值、品质索引、库存数量、深度与节点预算检查。主要玩法字段损坏时，在修改内存或写导入回退档前拒绝。
- 保留原有可恢复字段的归一化语义：损坏的邻里手记按条重置，坏 NPC 位置恢复安全位置，旧标量钓鱼表和 Unicode 厨房任务标识保持可读；钓鱼界面与结算增加安全访问。
- 读写文件统一限制 16 MiB；浮点精度附加记录最多 20,000 条，路径最多 64 层。超过读取器能力时拒绝写入，保护现有文件。
- 提取 `native_save_snapshot.gd`、`npc_social_profile.gd` 和玩家设置归一化。主状态脚本从 8,824 行降至 {lines:,} 行，现有 {functions} 个调用入口保留。后续仍可按玩法子系统继续拆分。
- 设置页新增“画面模式：自动 / 省电”。省电模式上限 30 帧，修改及读档后立即生效；自动模式对 Intel/常见 AMD 集显名称采用 60 帧上限，手机维持 30 帧上限。
- 网页设备判断缓存，避免反复跨 JavaScript 查询。Windows 触屏笔记本保持电脑布局，iPad 桌面 UA 按触屏设备识别。设置页正确显示保存的对话文字速度。
- 发行工具统一读取导出配置中的版本，并记录生产代码指纹。导出临时文件与浏览器检查配置也写入 D 盘，私有签名文件保持在本地。

## 最终验证

- 完整注册回归：{report['passed']} 组通过、0 失败，{report['checks']:,} 项断言；源代码及原网页规则在运行中保持不变。
- 实际 GPU 画面：434 项通过；手机尺寸的触控、菜单、存档滚动、大字界面和竖屏暂停通过。
- Chromium 中模拟 iPhone/Android：可信触摸、中文显示、存档下载与导入通过，控制台无新增错误；下载的 JSON 在原生版读写 4 项通过。
- 连续运行 {soak['seconds']:.0f} 秒、{soak['frames']:,} 帧，跨 112 天、{soak['roundtrips']} 次存档往返，{soak['passed']} 项通过、0 失败。
- Windows ZIP 清单与独立资源包 GPU 检查 1,633 项通过，实际 EXE 在空目录启动通过。
- Web ZIP 16 个文件逐字节核对；Android 包版本 {VERSION}、包名、v2/v3 签名、ARM64/ARMv7 与 16 KiB 对齐通过。

生产代码 SHA-256：`{source}`。

## 发行文件

| 文件 | 体量 | SHA-256 |
| --- | ---: | --- |
{packages}

Windows ZIP 解压后运行 EXE；Android 可直接安装 APK。Web ZIP 用于 HTTPS 托管或本机/局域网预览，尚未发布公网地址。手机网页覆盖目标包括安卓和 iPhone；原生安装包为 Android。

## 本机帧时间

实际设备为 RTX 3060 Laptop GPU，四场景各 240 帧采样。以下是本机结果，不能替代集显或真实手机验收，也不据此宣称所有场景均提速。

| 场景 | P95 帧时间 ms | 显存 MiB |
| --- | ---: | ---: |
{metrics}

## 仍待完成的验收与收尾

真实集显笔记本、安卓手机与 iPhone Safari 尚未连接；完整人工年度试玩、实际听感与小时级稳定性仍需实测。10 分钟加速跨年和设备模拟不替代这些证据。

三季夜景仍采用季节原画与专用着色器，复杂动作仍包含连续变形；本轮没有新增独立夜景/动作手绘位图。主状态脚本仍较大，深层业务关系的完整组合审计和对白文学润色继续列为后续工作。

## 证据

- [完整回归报告]({verification.relative_to(PROJECT).as_posix()})
- [GPU 画面报告](artifacts/continuation-20261014/visual-report.json)
- [连续运行报告](artifacts/continuation-20261014/soak-report.json)
- [移动包验收](artifacts/continuation-20261014/mobile-package-verification.json)
- [Windows 包验收](artifacts/continuation-windows-package-render.json)
- [手机网页存档页](artifacts/continuation-20261014/browser-saves-final.png)
- [竖屏暂停](artifacts/continuation-20261014/browser-portrait-final.png)
- [存储迁移记录](STORAGE_MIGRATION_20261014.md)
'''
(PROJECT/'CONTINUATION_20261015.md').write_text(body,encoding='utf8')
print('CONTINUATION_REPORT_READY')
