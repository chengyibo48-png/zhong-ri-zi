"""Decorate and compress a completed official web export; keep artifacts reproducible."""
import gzip,hashlib,json,shutil,zipfile
from pathlib import Path
from release_config import VERSION, VERSION_CODE, RELEASE_DATE
project=Path(__file__).resolve().parents[1]
web=project/'build/web'
html=web/'index.html'
text=html.read_text(encoding='utf8').replace('<html lang="en">','<html lang="zh-CN">')
text=text.replace('<title>种日子 · Godot</title>','<title>种日子</title>')
text=text.replace('width=device-width, user-scalable=no, initial-scale=1.0','width=device-width, initial-scale=1.0, viewport-fit=cover')
if 'zrz-safe-area' not in text:
    text=text.replace('</style>', '''/* zrz-safe-area */
body {background:#253b30;}
#canvas {position:fixed;left:env(safe-area-inset-left);top:env(safe-area-inset-top);}
#status {font-family:system-ui,sans-serif;}
</style>''',1)
    # Resize the actual render target instead of covering controls with a notch.
    text=text.replace("'onProgress': function", "'onProgress': function")
    text=text.replace('setStatusMode(\'hidden\');', '''setStatusMode('hidden');
            const fitSafeArea = () => {
                const probe=document.createElement('div');
                probe.style.cssText='position:fixed;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
                document.body.appendChild(probe);const s=getComputedStyle(probe);
                const x=parseFloat(s.paddingLeft)+parseFloat(s.paddingRight);
                const y=parseFloat(s.paddingTop)+parseFloat(s.paddingBottom);probe.remove();
                const canvas=document.getElementById('canvas');
                canvas.width=Math.max(1,innerWidth-x);canvas.height=Math.max(1,innerHeight-y);
                canvas.style.maxWidth=(innerWidth-x)+'px';canvas.style.maxHeight=(innerHeight-y)+'px';
            };
            window.addEventListener('resize',fitSafeArea);fitSafeArea();''')
html.write_text(text,encoding='utf8')
shutil.copy2(project/'tools/serve_web.py',web/'serve_web.py')
# The distributable launcher resolves its directory; project tooling resolves build/web.
server=(web/'serve_web.py').read_text(encoding='utf8').replace("root=Path(__file__).resolve().parents[1]/'build/web'", "root=Path(__file__).resolve().parent")
(web/'serve_web.py').write_text(server,encoding='utf8')
(web/'开始网页游戏.cmd').write_text('@echo off\r\ncd /d "%~dp0"\r\nstart "" http://127.0.0.1:4174\r\npython serve_web.py\r\npause\r\n',encoding='ascii')
(web/'使用说明.txt').write_text(f'种日子 {VERSION} 网页版\n\n电脑、安卓浏览器、iPhone Safari：使用 WebGL 2 和 WebAssembly，建议横屏。\n首次加载需要下载完整美术资源；请使用稳定网络。\n电脑本地预览需 Python 3：双击“开始网页游戏.cmd”。不能直接通过 file:// 打开。\n手机同局域网预览：电脑运行 python serve_web.py --lan，手机访问电脑 IP 的 4174 端口。\n正式托管：上传本目录到 HTTPS 静态服务器，.wasm MIME 设为 application/wasm；启用 gzip/Brotli。\n单线程构建不要求 COOP/COEP；音频首次需要点按画面。\n浏览器存档保存在当前网站的 IndexedDB；清除站点数据会移除本地档。请定期在存档簿导出 JSON 备份。\n安卓 APK 和电脑版可通过存档簿导入同一份 JSON。\n',encoding='utf8')
shutil.copy2(project/'art/fonts/LICENSE-Noto-CJK.txt',web/'LICENSE-Noto-CJK.txt')
for file in web.iterdir():
    if file.suffix in ['.pck','.wasm','.js']:
        with file.open('rb') as source,gzip.open(str(file)+'.gz','wb',compresslevel=9) as target:shutil.copyfileobj(source,target)
files=[p for p in web.iterdir() if p.is_file() and p.suffix!='.gz' and p.name!='manifest.json']
manifest={'version':f'{VERSION}','thread_support':False,'files':[{'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]}
(web/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
release=project/f'build/releases/{RELEASE_DATE}-{VERSION}';release.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(release/f'种日子-Web-{VERSION}.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for file in files+[web/'manifest.json']:archive.write(file,file.name)
print('WEB_PACKAGE_READY '+str(release))
