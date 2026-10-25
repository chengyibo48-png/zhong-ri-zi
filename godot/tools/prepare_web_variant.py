"""Create a compact browser import variant without changing authored source files."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
project=Path(__file__).resolve().parents[1]
variant=project/'.build/web-project';variant.mkdir(exist_ok=True)
for folder in ['scripts','scenes','data','art','audio']:shutil.copytree(project/folder,variant/folder,dirs_exist_ok=True)
for filename in ['project.godot','export_presets.cfg']:shutil.copy2(project/filename,variant/filename)
changes=[]
for image in (variant/'art').rglob('*.png'):
    relative=image.relative_to(variant).as_posix()
    if relative.startswith('art/icons/') or relative.startswith('art/world/ui/') or relative=='art/app_icon.png':continue
    sidecar=Path(str(image)+'.import')
    if not sidecar.exists():continue
    text=sidecar.read_text(encoding='utf8')
    settings=[('compress/mode','1'),('compress/lossy_quality','0.82')]
    limit=256 if relative.startswith('art/world/buildings/') else 512 if relative.startswith('art/world/interiors/') else 0
    if limit:settings.append(('process/size_limit',str(limit)))
    for key,value in settings:text=re.sub(r'(?m)^'+re.escape(key)+r'=.*$',key+'='+value,text)
    sidecar.write_text(text,encoding='utf8');changes.append({'file':relative,'size_limit':limit})
presets=(variant/'export_presets.cfg').read_text(encoding='utf8').replace('res://.build/templates/',str(project/'.build/templates').replace('\\','/')+'/')
(variant/'export_presets.cfg').write_text(presets,encoding='utf8')
original=(variant/'project.godot').read_text(encoding='utf8')
(variant/'project.godot').write_text(original.replace('theme/custom_font="res://art/fonts/NotoSansCJKsc-Regular.otf"',''),encoding='utf8')
log=project/'artifacts/quality-web-variant-import-20261014.log'
with log.open('wb') as stream:
    result=subprocess.run([str(project/'.build/export-engine/Godot.exe'),'--headless','--path',str(variant),'--editor','--import','--quit'],stdout=stream,stderr=subprocess.STDOUT,timeout=1800,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
(variant/'project.godot').write_text(original,encoding='utf8')
content=log.read_text(encoding='utf8',errors='replace')
if result.returncode or 'SCRIPT ERROR:' in content or '\nERROR:' in content:print(content[-8000:]);raise SystemExit(result.returncode or 1)
assert all(hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256((variant/p.relative_to(project)).read_bytes()).digest() for folder in ['scripts','data','scenes'] for p in (project/folder).rglob('*') if p.is_file())
(project/'artifacts/quality-20261014/web-variant.json').write_text(json.dumps({'variant':str(variant),'changes':changes,'source_png_changed':False,'sprite_atlas_dimensions_changed':False,'scripts_data_scenes_identical':True,'format':'WebP quality 0.82; buildings <=256, room backgrounds <=512; all other dimensions preserved'},ensure_ascii=False,indent=2),encoding='utf8')
print('WEB_VARIANT_READY '+str(len(changes)))
