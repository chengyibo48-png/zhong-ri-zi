"""Describe the current economy without silently changing gameplay values."""
import json
from pathlib import Path
project=Path(__file__).resolve().parents[1]
data=json.loads((project/'data/content.json').read_text(encoding='utf8'))
rows=[]
for key,crop in data['crops'].items():
    rows.append({'id':key,'name':crop['name'],'days':crop['days'],'seed_cost':crop['cost'],'ordinary_unit_sale':crop['price'],'ordinary_two_unit_net_per_day':round((2*crop['price']-crop['cost'])/crop['days'],4),'seasons':crop['seasons'],'labor_model':'sow + harvest; watering and care depend on actual weather and soil; not guaranteed realized profit'})
report={'scope':'Baseline price and nominal two-unit yield comparison, not a claim about simulated realized income','milestones':[{'day':1,'focus':'harvest, prepare greens, visit granny'},{'day':7,'focus':'repeat production and optional neighbor invitations'},{'day':28,'focus':'seasonal seed choice and processing'},{'day':112,'focus':'year review, lasting relationships and museum records'}],'crops':rows,'decision':'Preserve prices and growth times. No dominant-strategy or scarcity change is supported by this nominal calculation alone; UI now exposes materials, time and linked uses.'}
out=project/'artifacts/quality-redesign-20261015/balance-baseline.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print('BALANCE_BASELINE',len(rows),'crops')
