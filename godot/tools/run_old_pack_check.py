"""Run external acceptance scripts against an embedded release/isolated PCK only."""
from pathlib import Path
import os, subprocess, tempfile, time, re, json, argparse

ROOT=Path(__file__).resolve().parents[1]

def run(pack,script,out,*,headless=False,extra=None,limit=440,direct=False,seed_legacy=None):
    if direct:raise RuntimeError("This release template does not expose external script acceptance; use matching engine and embedded pack, plus normal window startup verification")
    out=Path(out).resolve();out.mkdir(parents=True,exist_ok=True)
    profile=Path(tempfile.mkdtemp(prefix='profile-',dir=out));env=os.environ.copy()
    for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
        directory=profile/key if key not in ['TEMP','TMP'] else profile
        directory.mkdir(exist_ok=True);env[key]=str(directory)
    for key in list(env):
        if key.startswith('ZRZ_PIXEL'):env.pop(key)
    env.update(ZRZ_ART_OUTPUT=str(out));env.update(extra or {})
    if seed_legacy:
        import shutil
        saved=profile/"APPDATA/Godot/app_userdata/种日子 · Godot"
        saved.mkdir(parents=True,exist_ok=True)
        shutil.copy2(seed_legacy,saved/"zhenrizhi_godot_save.json")
    command=([str(Path(pack).resolve()),'--script',str(Path(script).resolve())] if direct else [str(ROOT/'.build/export-engine/Godot.exe'),'--path',str(profile),'--main-pack',str(Path(pack).resolve()),'--script',str(Path(script).resolve())])
    if headless:command.insert(1,'--headless')
    print('RUN',out.name,flush=True)
    started=time.monotonic();aborted=None
    log=out/'native.log'
    with log.open('wb') as stream:
        child=subprocess.Popen(command,env=env,cwd=profile,stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        while child.poll() is None:
            text=log.read_text(encoding='utf-8',errors='replace')
            if re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',text):aborted='runtime error'
            if time.monotonic()-started>limit:aborted='timeout'
            if aborted:child.kill();break
            time.sleep(.5)
        code=child.wait()
    text=log.read_text(encoding='utf-8',errors='replace')
    ok=code==0 and not aborted and not re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',text)
    receipt={'ok':bool(ok),'exit_code':code,'abort_reason':aborted,'seconds':round(time.monotonic()-started,2),'pack':str(Path(pack).resolve()),'script':str(Path(script).resolve()),'isolated_profile':str(profile),'direct_binary':direct}
    (out/'check.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(receipt,ensure_ascii=False),flush=True)
    if not ok:print(text[-3000:],flush=True);raise RuntimeError('Old release check failed: '+str(out))
    return receipt

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--pack',type=Path,required=True);parser.add_argument('--script',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--headless',action='store_true')
    args=parser.parse_args();run(args.pack,args.script,args.output,headless=args.headless)
