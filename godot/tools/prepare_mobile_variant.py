"""Import a mobile texture variant in a separate copy; retain original PNG and desktop imports."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
project=Path(__file__).resolve().parents[1]
variant=project/'.build/mobile-project';variant.mkdir(exist_ok=True)
for folder in ['scripts','scenes','data','art','audio']:
    shutil.copytree(project/folder,variant/folder,dirs_exist_ok=True)
for filename in ['project.godot','export_presets.cfg']:shutil.copy2(project/filename,variant/filename)
changed=[]
for image in (variant/'art').rglob('*.png'):
    path=image.relative_to(variant).as_posix()
    sidecar=Path(str(image)+'.import')
    if not sidecar.exists():continue
    if path.startswith('art/icons/') or path.startswith('art/world/ui/') or path.startswith('art/world/interior_props/') or path in ['art/app_icon.png','art/ground_tiles_handpainted.png']:
        # These textures support pixel reads, alpha crop bounds or precise UI colors.
        original_sidecar=Path(str(project/path)+'.import')
        shutil.copy2(original_sidecar,sidecar)
        continue
    text=sidecar.read_text(encoding='utf8')
    for key,value in [('compress/mode','2'),('compress/high_quality','false')]:
        text=re.sub(r'(?m)^'+re.escape(key)+r'=.*$',key+'='+value,text)
    sidecar.write_text(text,encoding='utf8')
    changed.append(path)
presets=(variant/'export_presets.cfg').read_text(encoding='utf8')
presets=presets.replace('res://.build/templates/',str(project/'.build/templates').replace('\\','/')+'/')
# Keep desktop S3TC and mobile ETC2 alternatives for browser GPU compatibility.
(variant/'export_presets.cfg').write_text(presets,encoding='utf8')
original=(variant/'project.godot').read_text(encoding='utf8')
(variant/'project.godot').write_text(original.replace('theme/custom_font="res://art/fonts/NotoSansCJKsc-Regular.otf"',''),encoding='utf8')
# Keep all authored dimensions: sprite atlas rectangles and interaction geometry remain exact.
log=project/'artifacts/quality-mobile-variant-import-20261014.log'
with log.open('wb') as stream:
    result=subprocess.run([str(project/'.build/export-engine/Godot.exe'),'--headless','--path',str(variant),'--editor','--import','--quit'],stdout=stream,stderr=subprocess.STDOUT,timeout=1800,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
(variant/'project.godot').write_text(original,encoding='utf8')
content=log.read_text(encoding='utf8',errors='replace')
if result.returncode or 'SCRIPT ERROR:' in content or '\nERROR:' in content:print(content[-8000:]);raise SystemExit(result.returncode or 1)
assert all(hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256((variant/p.relative_to(project)).read_bytes()).digest() for folder in ['scripts','data','scenes'] for p in (project/folder).rglob('*') if p.is_file())
(project/'artifacts/quality-20261014/mobile-variant.json').write_text(json.dumps({'variant':str(variant),'compressed_textures':changed,'count':len(changed),'dimensions_changed':False,'source_png_changed':False,'scripts_data_scenes_identical':True,'format':'ETC2'},ensure_ascii=False,indent=2),encoding='utf8')
print('MOBILE_VARIANT_READY '+str(len(changed)))
