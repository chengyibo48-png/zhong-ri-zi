"""Configure local exports without altering an installed editor or sharing signing secrets."""
import configparser, json, shutil, subprocess
from pathlib import Path
from release_config import VERSION, VERSION_CODE, RELEASE_DATE

project=Path(__file__).resolve().parents[1]
build=project/'.build'
engine=Path(r'D:\.codex\小游戏\西行八十一难\Godot工具\Godot_v4.7.2-stable_win64.exe')
local=build/'export-engine';local.mkdir(exist_ok=True)
copy=local/'Godot.exe'
if not copy.exists():shutil.copy2(engine,copy)
console=local/'Godot_console.exe'
if not console.exists():shutil.copy2(engine.with_name('Godot_v4.7.2-stable_win64_console.exe'),console)
(local/'_sc_').touch()
settings=local/'editor_data';settings.mkdir(exist_ok=True)
config='''[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = %s
export/android/android_sdk_path = %s
'''%(json.dumps(str(build/'jdk17').replace('\\','/'),ensure_ascii=False),json.dumps(str(build/'android-sdk').replace('\\','/'),ensure_ascii=False))
(settings/'editor_settings-4.7.tres').write_text(config,encoding='utf8')
path=project/'export_presets.cfg'
text=path.read_text(encoding='utf8')
if '[preset.1]' in text:text=text.split('[preset.1]')[0]
excludes=next(line for line in text.splitlines() if line.startswith('exclude_filter='))
base='''
[preset.{index}]
name="{name}"
platform="{platform}"
runnable=true
export_filter="all_resources"
include_filter="data/*.json,data/atlas_navigation/*.json,art/fonts/*.txt"
{excludes}
export_path="{output}"
script_export_mode=1

[preset.{index}.options]
custom_template/debug=""
custom_template/release="res://.build/templates/{template}"
'''
text+=base.format(index=1,name='Web',platform='Web',excludes=excludes,output='build/web/index.html',template='web_nothreads_release.zip')+'''
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/head_include="<meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>"
progressive_web_app/enabled=false
'''
text+=base.format(index=2,name='Android',platform='Android',excludes=excludes,output=f'build/android/ZhongRiZi-{VERSION}.apk',template='android_release.apk')+f'''
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code={VERSION_CODE}
version/name="{VERSION}"
package/unique_name="org.zhongrizi.game"
package/name="种日子"
package/signed=true
screen/orientation=0
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
texture_format/s3tc_bptc=false
texture_format/etc2_astc=true
permissions/internet=false
'''
path.write_text(text,encoding='utf8')
for directory in ['web','android']:(project/'build'/directory).mkdir(parents=True,exist_ok=True)
print('LOCAL_EXPORT_ENGINE '+str(copy))
