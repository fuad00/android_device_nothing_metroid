#!/usr/bin/env python3
"""Print offset/size of payload.bin and payload_properties.txt inside an A/B OTA zip
(local path or http URL, read via range requests) for update_engine_client."""
import io, sys, zipfile, urllib.request

class HttpFile(io.RawIOBase):
    def __init__(self, url):
        self.url, self.pos = url, 0
        req = urllib.request.Request(url, method="HEAD")
        self.size = int(urllib.request.urlopen(req).headers["Content-Length"])
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, off, whence=0):
        self.pos = {0: off, 1: self.pos + off, 2: self.size + off}[whence]; return self.pos
    def read(self, n=-1):
        if n < 0: n = self.size - self.pos
        if n == 0 or self.pos >= self.size: return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        data = urllib.request.urlopen(req).read(); self.pos += len(data); return data
    def readinto(self, b):
        d = self.read(len(b)); b[:len(d)] = d; return len(d)

src = sys.argv[1]
f = HttpFile(src) if src.startswith("http") else open(src, "rb")
z = zipfile.ZipFile(f)
for name in ("payload.bin", "payload_properties.txt"):
    i = z.getinfo(name)
    f.seek(i.header_offset); h = f.read(30)
    off = i.header_offset + 30 + int.from_bytes(h[26:28], "little") + int.from_bytes(h[28:30], "little")
    print(f"{name} offset={off} size={i.file_size} compress={i.compress_type}")
print(z.read("payload_properties.txt").decode())
print(z.read("META-INF/com/android/metadata").decode())
