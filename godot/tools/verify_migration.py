"""Run the existing migration checks with isolated saves and strict error gates."""
import argparse, concurrent.futures, hashlib, json, os, re, subprocess, time, threading
from pathlib import Path
from project_temporary import temporary_directory

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot"
CASES = [
 ("item_art", None), ("character_art", None),
 ("legacy_furniture", "legacy_furniture"),
 ("building_geometry", "building_geometry"), ("building_draft", None),
 ("source_normalization", "source_normalization"), ("source_save_validation", "source_save_validation"), ("ranch_orders", "ranch_orders"), ("building_config", "building_config"), ("ui_operation_routes", None),
 ("building_task", "building_task"), ("farm_queue", "farm_queue"),
 ("ranch_queue", "ranch_queue"), ("kitchen_task", "kitchen_task"),
 ("economy_task", "economy_task"), ("museum_task", "museum_task"),
 ("npc_task", "npc_task"), ("fishing_session", "fishing_session"),
 ("integrated_overnight", "integrated_overnight"),
 ("inventory_storage_fidelity", "inventory_storage"),
 ("storage_sort_fidelity", "storage_sort"),
 ("kitchen_management", "kitchen_management"),
 ("ranch_tend", "ranch_tend"), ("tool_transactions", "tool_transactions"),
 ("skill_choice", "skill_choice"), ("stamina_source", "stamina"),
 ("source_audio", "audio"), ("notification_error", "notification_error"),
 ("panel_confirmation", "panel_confirmation"),
 ("operation_audio", "operation_audio"),
 ("legacy_save", None), ("save_precision", None), ("save_atomic", None),
 ("new_game", None), ("feedback_action", None),
 ('environment_fidelity', 'building_task'),
 ('forage_status', 'forage_status'),
 ('npc_world_source', 'npc_world'),
 ('npc_story_source', 'npc_story'),
 ('npc_conversation_fidelity', 'npc_conversation'),
 ('ranch_continuous_source', 'ranch_continuous'),
 ('atlas_save_source', 'atlas_save'),
 ('atlas_utf16_ui', 'atlas_pin'),
 ('appearance_form', 'appearance_form'),
 ('hotkey_dispatch_source', 'hotkey_dispatch'),
 ('input_mode_source', 'input_mode'),
 ('gamepad_poll_source', 'gamepad_poll'),
 ('player_motion_source', 'player_motion'),
 ('action_art', 'action_art'),
 ('atlas_map_art_source', 'atlas_map_art'),
 ('ranch_family_ui', 'ranch_family'),
 ('kitchen_research_ui', 'kitchen_management'),
 ('market_ui', None),
 ('context_actions_ui', None),
 ('hud_layout', None),
 ('keybindings', None),
]
SECONDARY_EXPORTERS={"wedding_ui":{"RELATIONSHIP_ACTION_FIXTURE":"relationship_action"}}

def exporter_path(name):
 standard=PROJECT/"tools"/("export_"+name+"_fixture.cjs")
 return standard if standard.is_file() else PROJECT/"tools"/("export_"+name+".cjs")

def extended_cases():
 known={name:exporter for name,exporter in CASES}
 variables={}
 for name,exporter in CASES:
  if exporter:
   script=(PROJECT/"tools"/(name+"_smoke.gd")).read_text(encoding="utf8")
   for var in re.findall(r'OS\.get_environment\("([A-Z0-9_]+_FIXTURE)"\)',script):variables[var]=exporter
 variables["NPC_POSITION_FIXTURE"]="npc_position_save"
 included=list(CASES);excluded=[]
 for script in sorted((PROJECT/"tools").glob("*_smoke.gd")):
  name=script.stem.removesuffix("_smoke")
  if name in known:continue
  if name in {"export_package","art_ui_render"}:
   excluded.append({"test":name,"reason":"package or GPU rendering requires a separate authorized invocation"});continue
  text=script.read_text(encoding="utf-8-sig")
  fixtures=set(re.findall(r'OS\.get_environment\("([A-Z0-9_]+_FIXTURE)"\)',text))
  if name in SECONDARY_EXPORTERS:
   included.append((name,"wedding"));continue
  if len(fixtures)>1:
   excluded.append({"test":name,"reason":"multiple fixture inputs require explicit configuration"});continue
  exporter=None
  if fixtures:
   variable=next(iter(fixtures));candidate=variable.removesuffix("_FIXTURE").lower()
   exporter=candidate if exporter_path(candidate).is_file() else variables.get(variable)
   if not exporter:
    excluded.append({"test":name,"reason":"fixture exporter not identified: "+variable});continue
  included.append((name,exporter))
 return included,excluded

def fingerprint():
 h=hashlib.sha256()
 files=[]
 for directory in ["src","godot/scripts","godot/scenes","godot/data","godot/art","godot/audio"]:
  files.extend(p for p in (ROOT/directory).rglob("*") if p.is_file())
 files.append(PROJECT/"project.godot")
 for p in sorted(files):
  h.update(p.relative_to(ROOT).as_posix().encode("utf8"));h.update(p.read_bytes())
 return h.hexdigest()

def original_source_fingerprint():
 h=hashlib.sha256()
 for p in sorted((ROOT/"src").rglob("*")):
  if p.is_file():h.update(p.relative_to(ROOT).as_posix().encode("utf8"));h.update(p.read_bytes())
 return h.hexdigest()

def checked_process(cmd, env, timeout, live_log=None):
 """Retain the full log, but stop an owned engine immediately on a fatal log."""
 chunks=[];fatal=threading.Event()
 proc=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
   creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
 def read_output():
  stream=Path(live_log).open("wb") if live_log else None
  try:
   for line in iter(proc.stdout.readline,b""):
    chunks.append(line)
    if stream:stream.write(line);stream.flush()
    if re.search(rb"SCRIPT ERROR:|^ERROR:|WARNING: ObjectDB|resources still in use",line):fatal.set()
  finally:
   if stream:stream.close()
 reader=threading.Thread(target=read_output,daemon=True);reader.start()
 deadline=time.monotonic()+timeout;reason=""
 while proc.poll() is None:
  if fatal.is_set():reason="Runtime error or leaked resources in live log";proc.kill();break
  if time.monotonic()>=deadline:reason="Owned test process timed out";proc.kill();break
  try:proc.wait(timeout=0.1)
  except subprocess.TimeoutExpired:pass
 proc.wait();reader.join(timeout=5)
 return proc.returncode,b"".join(chunks).decode("utf8",errors="replace"),reason

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument("--godot",required=True)
 parser.add_argument("--only",nargs="*")
 parser.add_argument("--extended",action="store_true",help="Include additional existing headless checks with identifiable fixtures")
 parser.add_argument("--resume",type=Path,help="Reuse proven cases only if production, engine, test, exporter and log still match")
 parser.add_argument("--workers",type=int,default=1,choices=[1,2,4])
 parser.add_argument("--timeout",type=int,default=1200)
 args=parser.parse_args()
 engine=Path(args.godot).resolve()
 if not engine.is_file():parser.error("Godot executable does not exist")
 # The Windows console wrapper spawns a child. Own the engine directly so
 # subprocess timeouts cannot leave that child running after its wrapper exits.
 if os.name=="nt" and engine.name.endswith("_console.exe"):
  direct=engine.with_name(engine.name.replace("_console.exe",".exe"))
  if direct.is_file():engine=direct
 available,excluded=extended_cases() if args.extended else (CASES,[])
 cases=[c for c in available if not args.only or c[0] in args.only]
 if args.only and set(args.only)-{c[0] for c in cases}:parser.error("Unknown test")
 if not cases:parser.error("No tests selected")
 output=PROJECT/"artifacts"/("verification-"+time.strftime("%Y%m%d-%H%M%S"))
 output.mkdir(parents=True,exist_ok=False)
 baseline=fingerprint(); original_baseline=original_source_fingerprint()
 report={"godot":str(engine),"godot_sha256":hashlib.sha256(engine.read_bytes()).hexdigest(),"source_sha256":baseline,"production_sha256":baseline,"original_source_sha256":original_baseline,"scope":("all registered tests" if not args.only else "selected registered tests")+"; not proof of full migration","excluded_checks":excluded,"cases":[]}
 def save_report():
  (output/"report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf8")
 save_report()
 print("REPORT "+str(output/"report.json"),flush=True)
 reused=set()
 if args.resume:
  prior_path=args.resume.resolve()
  prior=json.loads(prior_path.read_text(encoding="utf8"))
  if prior.get("source_unchanged") is True and prior.get("source_sha256")==baseline and prior.get("godot_sha256")==report["godot_sha256"]:
   for test,exporter in cases:
    if test in SECONDARY_EXPORTERS:continue
    old=next((r for r in prior.get("cases",[]) if r.get("test")==test and r.get("status")=="passed"),None)
    if not old:continue
    script=PROJECT/"tools"/(test+"_smoke.gd")
    if old.get("test_sha256")!=hashlib.sha256(script.read_bytes()).hexdigest():continue
    if exporter and old.get("exporter_sha256")!=hashlib.sha256(exporter_path(exporter).read_bytes()).hexdigest():continue
    logfile=Path(old.get("log","")).resolve()
    if logfile.parent!=prior_path.parent or not logfile.is_file():continue
    raw=logfile.read_bytes();text=raw.decode("utf8",errors="replace")
    digest=hashlib.sha256(raw).hexdigest()
    if old.get("log_sha256",digest)!=digest:continue
    counts=re.findall(r"(\d+)\s+passed,\s*(\d+)\s+failed",text)
    if not counts or any(int(f)!=0 for _,f in counts) or sum(int(n) for n,_ in counts)!=old.get("checks"):continue
    if re.search(r"SCRIPT ERROR:|(?m:^ERROR:)|WARNING: ObjectDB|resources still in use",text):continue
    cached_log=output/(test+".log");cached_log.write_bytes(raw)
    row=dict(old);row["cached_from"]=str(prior_path);row["log_sha256"]=digest;row["log"]=str(cached_log)
    report["cases"].append(row);reused.add(test)
    print("REUSED "+test,flush=True)
   save_report()
  else:print("Resume invalidated: production or engine changed",flush=True)
 def run_isolated(case,isolated):
  test,exporter=case;started=time.monotonic()
  script=PROJECT/"tools"/(test+"_smoke.gd")
  fixture_vars=set(re.findall(r'OS\.get_environment\("([A-Z0-9_]+_FIXTURE)"\)',script.read_text(encoding="utf8")))
  row={"test":test,"log":str(output/(test+".log")),"status":"failed","test_sha256":hashlib.sha256(script.read_bytes()).hexdigest()}
  if exporter:row["exporter_sha256"]=hashlib.sha256(exporter_path(exporter).read_bytes()).hexdigest()
  env=os.environ.copy()
  env.update(TEMP=str(isolated),TMP=str(isolated),APPDATA=str(isolated/'appdata'),LOCALAPPDATA=str(isolated/'localappdata'))
  commands=[]
  if exporter:
   secondary=SECONDARY_EXPORTERS.get(test,{})
   primary_vars=fixture_vars-set(secondary)
   if len(primary_vars)!=1 or not set(secondary).issubset(fixture_vars):
    row["reason"]="Ambiguous fixture environment: "+str(sorted(fixture_vars));return row
   fixture=isolated/"fixture.json"
   env[next(iter(primary_vars))]=str(fixture)
   commands.append(["node",str(exporter_path(exporter)),str(fixture)])
   if secondary:
    row["secondary_exporters"]={}
    for variable,secondary_name in sorted(secondary.items()):
     extra_fixture=isolated/(variable.lower()+".json")
     env[variable]=str(extra_fixture)
     commands.append(["node",str(exporter_path(secondary_name)),str(extra_fixture)])
     row["secondary_exporters"][variable]=hashlib.sha256(exporter_path(secondary_name).read_bytes()).hexdigest()
  elif fixture_vars:
   row["reason"]="Missing exporter configuration";return row
  if re.search(r"(?m)^extends (?:Node|Node2D|Control)\s*$",script.read_text(encoding="utf8")):
   scene=isolated/"probe.tscn"
   scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tools/'+script.name+'" id="1"]\n[node name="MigrationProbe" type="Node"]\nscript = ExtResource("1")\n',encoding="utf8")
   commands.append([str(engine),"--headless","--path",str(PROJECT),str(scene)])
  else:
   commands.append([str(engine),"--headless","--path",str(PROJECT),"--script","res://tools/"+script.name])
  stage_logs=[]
  for i,cmd in enumerate(commands):
   print("START %s stage %d"%(test,i),flush=True)
   returncode,text,reason=checked_process(cmd,env,args.timeout,output/(test+"-stage-%d.live.log"%i))
   stage_logs.append(text)
   if reason:
    row["reason"]=reason;break
   if returncode!=0:
    row["reason"]="Stage %d exited %d"%(i,returncode);break
   if re.search(r"SCRIPT ERROR:|(?m:^ERROR:)|WARNING: ObjectDB|resources still in use",text):
    row["reason"]="Runtime error or leaked resources in log";break
  else:
   last=stage_logs[-1]
   counts=re.findall(r"(\d+)\s+passed,\s*(\d+)\s+failed",last)
   if counts and all(int(f)==0 for _,f in counts):
    row["status"]="passed";row["checks"]=sum(int(p) for p,_ in counts)
   else:
    row["reason"]="Missing explicit completion summary"
  Path(row["log"]).write_text("\n".join(stage_logs),encoding="utf8")
  row["log_sha256"]=hashlib.sha256(Path(row["log"]).read_bytes()).hexdigest()
  row["seconds"]=round(time.monotonic()-started,2)
  return row
 def run(case):
  with temporary_directory(prefix="zrz-verify-"+case[0]+"-") as temporary:
   return run_isolated(case,Path(temporary))
 with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
  futures={pool.submit(run,c):c for c in cases if c[0] not in reused}
  for future in concurrent.futures.as_completed(futures):
   try:row=future.result()
   except Exception as exc:row={"test":futures[future][0],"status":"failed","reason":str(exc)}
   report["cases"].append(row);save_report()
   print("%s %s %s"%(row["status"].upper(),row["test"],row.get("checks",row.get("reason"))),flush=True)
 report["source_unchanged"]=fingerprint()==baseline
 report["production_unchanged"]=report["source_unchanged"]
 report["original_source_unchanged"]=original_source_fingerprint()==original_baseline
 report["passed"]=sum(r["status"]=="passed" for r in report["cases"])
 report["failed"]=len(report["cases"])-report["passed"]
 report["checks"]=sum(r.get("checks",0) for r in report["cases"] if r["status"]=="passed")
 save_report()
 print("BATCH %d passed, %d failed; %d checks; source unchanged=%s"%(
  report["passed"],report["failed"],report["checks"],report["source_unchanged"]),flush=True)
 return 0 if report["failed"]==0 and report["source_unchanged"] else 1

if __name__=="__main__":raise SystemExit(main())
