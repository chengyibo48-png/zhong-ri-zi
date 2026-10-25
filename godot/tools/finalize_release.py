"""Collect final deliverables and retained public hashes; signing keys stay local."""
import hashlib,json,shutil,zipfile
from verify_migration import fingerprint
from pathlib import Path
from release_config import VERSION, VERSION_CODE, RELEASE_DATE
project=Path(__file__).resolve().parents[1]
release=project/f'build/releases/{RELEASE_DATE}-{VERSION}';release.mkdir(parents=True,exist_ok=True)
windows=release/f'种日子-Windows-{VERSION}.zip'
shutil.copy2(project/'build/ZhongRiZi-Windows.zip',windows)
apk=release/f'种日子-Android-{VERSION}.apk'
shutil.copy2(project/f'build/android/ZhongRiZi-{VERSION}.apk',apk)
readme=f'种日子 {VERSION} 安卓版\n\n将 APK 传到安卓手机后安装；支持 ARM64 和 ARMv7，系统最低 Android 7.0。\n横屏游玩：左侧摇杆移动，右侧互动/背包/种子，底部切换工具，右上角菜单。\n存档保存在应用专属目录；卸载或清除应用数据前，请在存档簿导出 JSON。\n导入导出使用系统文件选择器，可与电脑版和网页版交换存档。\n建议保留原 APK；后续更新需使用相同签名密钥。\n当前包经过签名、架构、对齐、源码对照和纹理副本 GPU 检查；仍需真实安卓设备验收。\n'
(release/'安卓使用说明.txt').write_text(readme,encoding='utf8')
with zipfile.ZipFile(release/f'种日子-Android-{VERSION}.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    archive.write(apk,apk.name)
    archive.write(release/'安卓使用说明.txt','使用说明.txt')
    archive.write(project/'art/fonts/LICENSE-Noto-CJK.txt','LICENSE-Noto-CJK.txt')
files=[windows,release/f'种日子-Web-{VERSION}.zip',apk,release/f'种日子-Android-{VERSION}.zip']
entries=[{'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
(release/'manifest.json').write_text(json.dumps({'version':f'{VERSION}','engine':'4.7.2-stable.ed1daf0bf','production_sha256':fingerprint(),'files':entries,'physical_integrated_gpu_verified':False,'physical_android_verified':False,'physical_iphone_safari_verified':False},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(entries,ensure_ascii=False,indent=2))
