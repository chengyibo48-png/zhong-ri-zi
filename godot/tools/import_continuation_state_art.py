from pathlib import Path
import json, hashlib
from PIL import Image

ROOT = Path(r'D:\.codex\游戏2\godot')
BATCH = ROOT / 'artifacts' / 'continuation-art-20261013'
RECEIPTS = BATCH / 'generation-receipts.json'
QUEUE = ROOT / 'artifacts' / 'independent-fine-art-20261011' / 'queue.json'
REMAINING = QUEUE.with_name('remaining.json')
MANIFEST = ROOT / 'data' / 'world_art_manifest.json'
CANVAS = (256, 160)

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))
def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()

receipts, queue, manifest = read(RECEIPTS), read(QUEUE), read(MANIFEST)
imported = 0
for idx, item in enumerate(receipts):
    if item.get('status') != 'approved_static_review':
        continue
    item_id, state = item.get('id', ''), item.get('state', '')
    if state not in {'night', 'focused', 'working'}:
        raise ValueError(f'Unexpected state: {item_id} {state}')
    src = Path(item['master'])
    image = Image.open(src).convert('RGBA')
    alpha = image.getchannel('A')
    bbox = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    if not bbox:
        raise ValueError(f'Empty alpha: {src}')
    left, top, right, bottom = bbox
    if left == 0 or top == 0 or right == image.width or bottom == image.height:
        raise ValueError(f'Artwork touches the image edge: {src} {bbox}')
    crop = image.crop(bbox)
    scale = min((CANVAS[0]-4)/crop.width, (CANVAS[1]-4)/crop.height)
    fitted = crop.resize((max(1, round(crop.width*scale)), max(1, round(crop.height*scale))), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', CANVAS, (0,0,0,0))
    canvas.alpha_composite(fitted, ((CANVAS[0]-fitted.width)//2, CANVAS[1]-fitted.height))
    out_rel = f"res://art/world/interior_props/fine/{Path(item_id).name}-{state}.png"
    out = ROOT / out_rel.removeprefix('res://').replace('/', '\\')
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, format='PNG', optimize=True)
    row = manifest.get('entries', {}).get(item_id)
    if not isinstance(row, dict):
        raise ValueError(f'Missing art manifest entry: {item_id}')
    states = row.setdefault('states', {})
    states[state] = out_rel
    pending = row.setdefault('pendingPaintedStates', [])
    if state in pending:
        pending.remove(state)
    row['plannedPaintedStatesImported'] = not pending
    row['status'] = 'partial'
    row['artBatch'] = 'continuation-art-20261013'
    row['artReview'] = 'Source image statically reviewed; runtime placement and interaction alignment remain pending.'
    row['verification'] = 'Native runtime PNG imported; gameplay not tested in this batch.'
    item['runtimePath'] = out_rel
    item['runtimeSha256'] = sha(out)
    item['sourceDimensions'] = [image.width, image.height]
    item['status'] = 'imported_static_review_only'
    for job in queue.get('jobs', []):
        if job.get('id') == item_id and job.get('state') == state:
            job['master'] = str(src)
            job['sha256'] = item.get('generatedSha256', '')
            job['runtimePath'] = out_rel
            job['status'] = 'imported_not_gameplay_tested'
            job['verification'] = 'Source image statically reviewed and native runtime PNG imported; gameplay not tested.'
    receipts[idx] = item
    imported += 1

counts = queue.setdefault('counts', {})
counts['total'] = len(queue.get('jobs', []))
counts['imported'] = sum(1 for job in queue.get('jobs', []) if job.get('status') == 'imported_not_gameplay_tested')
remaining_jobs = [
    {'id': job.get('id',''), 'name': job.get('name',''), 'state': job.get('state',''), 'reason': job.get('reason','Pending static review or generation')}
    for job in queue.get('jobs', []) if job.get('status') != 'imported_not_gameplay_tested'
]
counts['pending'] = len(remaining_jobs)
write(MANIFEST, manifest)
write(QUEUE, queue)
write(REMAINING, {'updated':'2026-10-13','pendingImages':len(remaining_jobs),'jobs':remaining_jobs})
write(RECEIPTS, receipts)
print(f'Imported {imported} approved state images; queue now has {counts["imported"]} imported and {counts["pending"]} pending.')

