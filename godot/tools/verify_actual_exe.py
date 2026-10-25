"""Launch the actual distributable in an empty folder and isolated save environment."""
import os,re,subprocess
from pathlib import Path
from project_temporary import temporary_directory
from release_config import VERSION
project=Path(__file__).resolve().parents[1]
exe=project/'build/windows/ZhongRiZi.exe'
log=project/'artifacts'/f'actual-exe-{VERSION}.log'
with temporary_directory(prefix='zrz-actual-exe-') as temporary:
    env=os.environ.copy();env.update(TEMP=temporary,TMP=temporary,APPDATA=str(Path(temporary)/'appdata'),LOCALAPPDATA=str(Path(temporary)/'localappdata'))
    with log.open('wb') as output:
        result=subprocess.run([str(exe),'--quit-after','180'],cwd=temporary,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=120,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    content=log.read_text(encoding='utf8',errors='replace')
    print(content[-3000:])
    if result.returncode or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)|WARNING: ObjectDB|resources still in use',content):raise SystemExit(result.returncode or 1)
print('ACTUAL_EXE_STARTUP_VERIFIED')
