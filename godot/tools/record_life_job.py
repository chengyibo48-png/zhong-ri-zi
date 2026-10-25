from pathlib import Path
import json
r=Path(__file__).resolve().parents[1];b=r/'artifacts/optimization-20261014';p=b/'generation-jobs.json'
data=json.loads(p.read_text(encoding='utf-8-sig'));job=json.loads((b/'incoming-generation-job.json').read_text(encoding='utf-8-sig'));data['jobs']=[j for j in data['jobs'] if j['id']!=job['id']]+[job];p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('Recorded',job['id'])
