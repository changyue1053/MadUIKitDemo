"""Decode native Android RGB/RGBA PNG and require exact synthetic 40x24 ROI."""
import struct,zlib,sys
from pathlib import Path
b=Path(sys.argv[1]).read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n'
pos=8;raw=b''
while pos<len(b):
 n=struct.unpack('>I',b[pos:pos+4])[0];tag=b[pos+4:pos+8];data=b[pos+8:pos+8+n];pos+=n+12
 if tag==b'IHDR': w,h,depth,color,_,_,interlace=struct.unpack('>IIBBBBB',data)
 if tag==b'IDAT':raw+=data
assert depth==8 and color in (2,6) and interlace==0
channels=3 if color==2 else 4;stride=w*channels;raw=zlib.decompress(raw);rows=[];prior=bytearray(stride)
for y in range(h):
 f=raw[y*(stride+1)];r=bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
 for i in range(stride):
  a=r[i-channels] if i>=channels else 0;b=prior[i];c=prior[i-channels] if i>=channels else 0
  if f==1:v=a
  elif f==2:v=b
  elif f==3:v=(a+b)//2
  elif f==4:
   p=a+b-c;pa,pb,pc=abs(p-a),abs(p-b),abs(p-c);v=a if pa<=pb and pa<=pc else b if pb<=pc else c
  elif f==0:v=0
  else:raise ValueError(f)
  r[i]=(r[i]+v)&255
 rows.append([tuple(r[x*channels:x*channels+3]) for x in range(w)]);prior=r
# Logical host padding24dp ->48px. Generated image16x12dp ->32x24px.
# Check interiors away from resampled boundaries; report nearest-reference error separately.
x=48;scale=2
rects=[(2,2,8,16),(12,6,8,16),(22,2,8,16)]
def expected(px,py):
 return (0,128,191) if any(a<=px<a+rw and b<=py<b+rh for a,b,rw,rh in rects) else (255,255,255)
def stable(px,py):
 return len({expected(px+dx,py+dy) for dx in (-1,0,1) for dy in (-1,0,1)})==1
samples=[(px,py,expected(px,py)) for py in range(48) for px in range(80) if stable(px,py)]
candidates=[]
for y in range(min(h-48,400)):
 if rows[y+5][x+5]!=(0,128,191):continue
 if not all(max(abs(a-b) for a,b in zip(rows[y+py][x+px],rgb))<=2 for px,py,rgb in samples):continue
 error=sum(sum(abs(a-b) for a,b in zip(rows[y+py][x+px],expected(px,py))) for py in range(48) for px in range(80))
 candidates.append((error,y))
assert candidates,'No 2x logical geometry/interior-color match'
error,y=min(candidates)
print(f'PASS: native{w}x{h}, density320; logical40x24 frame ->80x48px, image16x12 ->32x24px; stable interior/background samples={len(samples)} within2RGB at({x},{y}).')
print(f'Nearest-neighbor reference absolute RGB error={error}; MAE={error/(80*48*3):.6f}; candidates={len(candidates)}. Edges permit resampling; not exact RGB parity.')
