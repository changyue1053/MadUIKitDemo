"""Native adb taps against UIAutomator-observed public synthetic host bounds."""
import json,re,subprocess,sys,time
from pathlib import Path
import xml.etree.ElementTree as ET
out=Path(sys.argv[1]); events=[]
def adb(*args): return subprocess.check_output(['adb',*args])
def dump(state):
    adb('shell','uiautomator','dump','/sdcard/filter.xml')
    adb('pull','/sdcard/filter.xml',str(out/f'{state}.xml'))
    return ET.parse(out/f'{state}.xml').getroot()
def text(root,label):
    found=[n for n in root.iter('node') if n.get('text')==label]
    assert len(found)==1,(label,len(found))
    return found[0]
def state(root,selection,count):
    text(root,'Selected filter: '+selection);text(root,'Selection requests: '+str(count))
def capture(name): (out/f'Android-Books-{name}.png').write_bytes(adb('exec-out','screencap','-p'))
def tap(node):
    b=list(map(int,re.findall(r'\d+',node.attrib['bounds'])))
    assert len(b)==4 and b[2]>b[0] and b[3]>b[1]
    xy=[(b[0]+b[2])//2,(b[1]+b[3])//2]
    adb('shell','input','tap',*map(str,xy));return xy
root=dump('before');state(root,'All books',0);capture('before')
fav=text(root,'Favorites');assert fav.get('enabled')=='true'
events.append({'tap':'Favorites','center':tap(fav)})
for attempt in range(8):
    time.sleep(.5);root=dump('after')
    if any(n.get('text')=='Selected filter: Favorites' for n in root.iter('node')):break
state(root,'Favorites',1);capture('after')
unavailable=text(root,'Unavailable')
parents={c:p for p in root.iter() for c in p}
chain=[unavailable]
while chain[-1] in parents:chain.append(parents[chain[-1]])
assert any(n.get('enabled')=='false' for n in chain),'Disabled semantics absent'
events.append({'tap':'Unavailable','center':tap(unavailable),'disabled_semantics':True})
time.sleep(2);root=dump('disabled');state(root,'Favorites',1);capture('disabled')
assert not any(n.get('text')=='Selected filter: Unavailable' for n in root.iter('node'))
(out/'interaction.json').write_text(json.dumps({'passed':True,'events':events,'selection':'Favorites','requests':1},indent=2)+'\n')
print('Native filter interaction passed: selection callback once; disabled tap no-op.')
