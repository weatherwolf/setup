import sys, struct, re
def read(path):
    roles=[]
    for line in open(path):
        m=re.match(r'^(\w+)=(#[0-9A-Fa-f]{6})',line.strip())
        if m: roles.append((m.group(1),m.group(2)))
    return roles
def hx(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))
files=sys.argv[1:-1]; out=sys.argv[-1]
W=60; H=40; cols=21
width=W*cols; height=H*len(files)*2
rows=[]
for f in files:
    roles=read(f); bg=hx(roles[0][1])
    for y in range(H):
        row=[]
        for name,h in roles:
            row += [hx(h)]*W
        rows.append(row)
    # second band: each colour as text-ish stripe on bg
    for y in range(H):
        row=[]
        for name,h in roles:
            c=hx(h)
            for x in range(W):
                row.append(c if (y%8<3 and 6<x<W-6) else bg)
        rows.append(row)
rowsize=(width*3+3)//4*4; pad=rowsize-width*3
data=bytearray()
for row in reversed(rows):
    for (r,g,b) in row: data+=bytes((b,g,r))
    data+=b'\0'*pad
hdr=struct.pack('<2sIHHI',b'BM',54+len(data),0,0,54)+struct.pack('<IiiHHIIiiII',40,width,height,1,24,0,len(data),2835,2835,0,0)
open(out,'wb').write(hdr+data)
