"""Check the distributable without falling back to the source project."""
import argparse, hashlib, json, os, re, subprocess, zipfile
from pathlib import Path
from project_temporary import temporary_directory

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--package-dir", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--receipt-prefix",default="windows-package")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9-]+",args.receipt_prefix):parser.error("Invalid receipt prefix")
    project = Path(__file__).resolve().parents[1]
    engine = Path(args.godot).resolve()
    if engine.name.endswith("_console.exe"):
        direct = engine.with_name(engine.name.replace("_console.exe", ".exe"))
        if direct.is_file(): engine = direct
    executable = (args.package_dir or project / "build/windows").resolve() / "ZhongRiZi.exe"
    archive_path = (args.archive or project / "build/ZhongRiZi-Windows.zip").resolve()
    with zipfile.ZipFile(archive_path) as archive:
        manifest = json.loads(archive.read("manifest.json").decode("utf-8-sig"))
        for entry in manifest["files"]:
            raw = archive.read(entry["name"])
            if len(raw) != entry["bytes"] or hashlib.sha256(raw).hexdigest() != entry["sha256"]:
                raise RuntimeError("Archive mismatch: " + entry["name"])
        if set(archive.namelist()) != {"manifest.json", *(f["name"] for f in manifest["files"])}:
            raise RuntimeError("Unexpected archive contents")
        if archive.read("ZhongRiZi.exe") != executable.read_bytes():
            raise RuntimeError("Archive executable differs from build")
    print("ZIP manifest verified: %d files" % len(manifest["files"]), flush=True)
    output = project / "artifacts"
    output.mkdir(exist_ok=True)
    with temporary_directory(prefix="zrz-package-") as temporary:
        env = os.environ.copy()
        env.update(TEMP=temporary, TMP=temporary, APPDATA=str(Path(temporary)/"appdata"), LOCALAPPDATA=str(Path(temporary)/"localappdata"))
        command = [str(engine), "--path", temporary, "--main-pack", str(executable)]
        command += ["--script", str(project / "tools/export_package_smoke.gd")]
        if args.render:
            env["EXPORT_SCREENSHOT"] = str(output / "windows-package.png")
        else:
            command.insert(1, "--headless")
        completed = subprocess.run(command, cwd=temporary, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, timeout=180,
                                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        log = completed.stdout.decode("utf8", errors="replace")
        (output / (args.receipt_prefix+("-render.log" if args.render else ".log"))).write_text(log, encoding="utf8")
        print(log, flush=True)
        if completed.returncode or not re.search(r"Export package: [1-9][0-9]* passed, 0 failed", log) or re.search(r"SCRIPT ERROR:|(?m:^ERROR:)|WARNING: ObjectDB|resources still in use", log):
            raise RuntimeError("Packaged runtime verification failed")
        if args.render and not Path(env["EXPORT_SCREENSHOT"]).is_file():
            raise RuntimeError("Packaged screenshot missing")
    receipt = {"archive":str(archive_path.resolve()),"archive_sha256":hashlib.sha256(archive_path.read_bytes()).hexdigest(),"executable_sha256":hashlib.sha256(executable.read_bytes()).hexdigest(),"render":args.render,"checks":int(re.search(r"Export package: ([0-9]+) passed",log).group(1)),"failed":0,"manifest":manifest}
    (output / (args.receipt_prefix+("-render.json" if args.render else ".json"))).write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+"\n",encoding="utf8")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
