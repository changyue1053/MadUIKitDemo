"""Bound a subprocess stage with explicit start/end and retained full log; no env dump."""
import datetime,json,os,signal,subprocess,sys,time
from pathlib import Path
name,seconds,log,*command=sys.argv[1:];limit=int(seconds);path=Path(log)
path.parent.mkdir(parents=True,exist_ok=True)
start=time.monotonic();stamp=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
print(f'STAGE START {name} {stamp()} budget={limit}s',flush=True)
status='unknown';code=1
with path.open('wb') as out:
 p=subprocess.Popen(command,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
 try:code=p.wait(timeout=limit);status='passed' if code==0 else 'failed'
 except subprocess.TimeoutExpired:
  status='timeout';os.killpg(p.pid,signal.SIGTERM)
  try:p.wait(timeout=10)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
  code=124
receipt={'stage':name,'status':status,'exitCode':code,'durationSeconds':round(time.monotonic()-start,2),'finishedUtc':stamp()}
path.with_suffix('.status.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('STAGE END '+json.dumps(receipt),flush=True)
if code:print(path.read_text(errors='replace')[-8000:])
sys.exit(code)
