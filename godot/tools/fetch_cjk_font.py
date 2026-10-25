"""Bundle the redistributable Noto CJK font and its upstream license."""
import hashlib,json,urllib.request
from pathlib import Path
project=Path(__file__).resolve().parents[1]
folder=project/'art/fonts';folder.mkdir(exist_ok=True)
base='https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/'
receipts=[]
for name,relative in [('NotoSansCJKsc-Regular.otf','OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf'),('LICENSE-Noto-CJK.txt','LICENSE')]:
    path=folder/name
    if not path.exists():
        with urllib.request.urlopen(base+relative,timeout=120) as response:path.write_bytes(response.read())
    receipts.append({'url':base+relative,'file':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size})
(project/'artifacts/quality-20261014/font-provenance.json').write_text(json.dumps(receipts,indent=2),encoding='utf8')
print('FONT_READY')
