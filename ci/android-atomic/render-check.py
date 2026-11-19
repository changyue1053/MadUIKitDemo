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
expected=[[((0,128,191) if any(a<=x<a+4 and b<=y<b+8 for a,b in [(1,1),(6,3),(11,1)]) else (255,255,255)) for x in range(40)] for y in range(24)]
found=[]
for y in range(h-24+1):
 for x in range(w-40+1):
  if rows[y+1][x+1]!=(0,128,191):continue
  if all(rows[y+dy][x:x+40]==expected[dy] for dy in range(24)):found.append((x,y))
assert len(found)==1,found
print(f'PASS: native {w}x{h}; exact 960/960 RGB pixels at {found[0]} for 40x24 synthetic generated frame.')
