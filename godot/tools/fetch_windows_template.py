"""Fetch only the official Windows release template from its ZIP archive."""
import io, os, sys, urllib.request, zipfile
from pathlib import Path

URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
BLOCK = 2 * 1024 * 1024

class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        response = urllib.request.urlopen(urllib.request.Request(url, headers={"Range": "bytes=0-0"}), timeout=45)
        self.url = response.url
        header = response.headers.get("Content-Range", "")
        if response.status != 206 or "/" not in header:
            response.close()
            raise RuntimeError("Official download does not support bounded HTTP ranges")
        self.length = int(header.rsplit("/", 1)[1])
        response.close()
        self.position = 0
        self.cache = {}
    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position
    def read(self, size=-1):
        size = self.length - self.position if size < 0 else min(size, self.length - self.position)
        result = bytearray()
        while size > 0:
            block = self.position // BLOCK
            if block not in self.cache:
                start = block * BLOCK
                end = min(self.length - 1, start + BLOCK - 1)
                request = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end}"})
                with urllib.request.urlopen(request, timeout=45) as response:
                    if response.status != 206: raise RuntimeError("Range response was not partial")
                    self.cache[block] = response.read()
                print(f"Downloaded range {block + 1}, {start}-{end}", flush=True)
            offset = self.position % BLOCK
            segment = self.cache[block][offset:offset + size]
            if not segment: raise EOFError("Incomplete remote ZIP range")
            result.extend(segment)
            self.position += len(segment)
            size -= len(segment)
        return bytes(result)

if __name__ == "__main__":
    destination = Path(sys.argv[1]).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteZip(URL)) as archive:
        name = next(n for n in archive.namelist() if n.endswith("/windows_release_x86_64.exe"))
        target = destination / "windows_release_x86_64.exe"
        with archive.open(name) as source, target.open("wb") as output:
            while chunk := source.read(1024 * 1024): output.write(chunk)
        print(f"CRC verified official template: {target} ({target.stat().st_size} bytes)", flush=True)
