"""Serve the exported game with WebAssembly MIME and precompressed transfer."""
import argparse,http.server,mimetypes
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=4174);parser.add_argument('--lan',action='store_true');args=parser.parse_args()
root=Path(__file__).resolve().parents[1]/'build/web'
mimetypes.add_type('application/wasm','.wasm')
mimetypes.add_type('application/octet-stream','.pck')
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(root),**kwargs)
    def do_GET(self):
        clean=self.path.split('?')[0]
        target=Path(self.translate_path(clean))
        if 'gzip' in self.headers.get('Accept-Encoding','') and target.suffix in ['.pck','.wasm','.js'] and target.with_suffix(target.suffix+'.gz').is_file():
            compressed=target.with_suffix(target.suffix+'.gz')
            self.send_response(200)
            self.send_header('Content-Type',self.guess_type(str(target)))
            self.send_header('Content-Encoding','gzip')
            self.send_header('Vary','Accept-Encoding')
            self.send_header('Content-Length',str(compressed.stat().st_size))
            self.end_headers()
            with compressed.open('rb') as stream:self.copyfile(stream,self.wfile)
        else:super().do_GET()
print('Web preview http://127.0.0.1:'+str(args.port),flush=True)
http.server.ThreadingHTTPServer(('0.0.0.0' if args.lan else '127.0.0.1',args.port),Handler).serve_forever()
