"""Conservative export audit. Keep dynamic path prefixes and all production references."""
import argparse, hashlib, json, re
from pathlib import Path
project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apply',action='store_true')
args = parser.parse_args()
texts = [project/'project.godot',project/'export_presets.cfg']
for folder in ['scripts','scenes','data']:
    texts.extend(p for p in (project/folder).rglob('*') if p.suffix in ['.gd','.tscn','.tres','.json'])
texts.extend(p for p in (project/'art').rglob('*') if p.suffix in ['.tres','.gdshader'])
paths = set()
prefixes = set()
for source in texts:
    text = source.read_text(encoding='utf-8-sig')
    for match in re.findall(r'''res://art/[^"'\r\n]*''',text):
        if match.endswith(('.png','.svg','.gdshader','.tres','.ico')) and '%' not in match:
            paths.add(match)
        else:
            prefix = match.split('%')[0].split('{')[0]
            prefixes.add(prefix)
assets = [p for p in (project/'art').rglob('*') if p.suffix in ['.png','.svg']]
unused = []
groups = {}
for path in assets:
    resource = 'res://'+path.relative_to(project).as_posix()
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    groups.setdefault(digest,[]).append(resource)
    if resource not in paths and not any(resource.startswith(prefix) for prefix in prefixes):
        unused.append({'path':path.relative_to(project).as_posix(),'bytes':path.stat().st_size,'sha256':digest})
report = {'assets':len(assets),'production_references':len(paths),'dynamic_prefixes':sorted(prefixes),
          'unreferenced_count':len(unused),'unreferenced_bytes':sum(x['bytes'] for x in unused),
          'unreferenced':unused,'duplicate_groups':[v for v in groups.values() if len(v)>1],
          'policy':'Exclude conservatively unreferenced assets from export only. Preserve source assets, originals and old packages.'}
output = project/'artifacts/quality-20261014/asset-audit.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
if args.apply:
    preset = project/'export_presets.cfg'
    text = preset.read_text(encoding='utf8')
    match = re.search(r'^exclude_filter="([^"]*)"',text,re.M)
    exclusions = match.group(1).split(',')
    exclusions += [row['path'] for row in unused if row['path'] not in exclusions]
    text = text[:match.start()]+('exclude_filter="'+','.join(exclusions)+'"')+text[match.end():]
    text = text.replace('0.25.0.0','0.26.0.0')
    preset.write_text(text,encoding='utf8')
print(json.dumps({k:report[k] for k in ['assets','production_references','unreferenced_count','unreferenced_bytes']},ensure_ascii=False))
