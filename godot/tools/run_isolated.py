"""Run one native check with temporary saves, bounded time and a retained log."""
import argparse, json, os, re, subprocess, time
from verify_migration import fingerprint
from pathlib import Path
from project_temporary import temporary_directory

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-dir',type=Path)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--script')
    parser.add_argument('--import-project', action='store_true')
    parser.add_argument('--name', required=True)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--timeout', type=int, default=240)
    parser.add_argument('--env', action='append', default=[])
    args = parser.parse_args()
    base_project = Path(__file__).resolve().parents[1]
    project = args.project_dir.resolve() if args.project_dir else base_project
    if args.project_dir and not project.is_relative_to(base_project/'.build'):parser.error('Variant must be inside project .build')
    log_path = base_project / 'artifacts' / (args.name + '.log')
    before_hash = fingerprint()
    with temporary_directory(prefix='zrz-check-') as temporary:
        env = os.environ.copy()
        env.update(TEMP=temporary, TMP=temporary, APPDATA=str(Path(temporary)/'appdata'), LOCALAPPDATA=str(Path(temporary)/'localappdata'))
        for entry in args.env:
            key, value = entry.split('=', 1)
            env[key] = value
        command = [args.godot, '--path', str(project)]
        if args.import_project:
            command += ['--headless', '--editor', '--import', '--quit']
        elif args.script:
            command += ['--script', args.script]
            if args.headless: command.insert(1, '--headless')
        else:
            parser.error('--script or --import-project is required')
        with log_path.open('wb') as output:
            process = subprocess.Popen(command, env=env, cwd=project, stdout=output, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            deadline = time.monotonic()+args.timeout
            while process.poll() is None:
                log = log_path.read_text(encoding='utf8',errors='replace')
                if time.monotonic()>deadline or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)',log):
                    process.kill()
                    break
                time.sleep(0.2)
            returncode = process.wait()
        log = log_path.read_text(encoding='utf8', errors='replace')
        after_hash = fingerprint()
        metadata={'project':str(project),'script':args.script,'source_sha256':before_hash,'source_unchanged':before_hash==after_hash,'returncode':returncode,'log_sha256':__import__('hashlib').sha256(log_path.read_bytes()).hexdigest()}
        log_path.with_suffix('.execution.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf8')
        print(log[-12000:], flush=True)
        if returncode or re.search(r'SCRIPT ERROR:|(?m:^ERROR:)|WARNING: ObjectDB|resources still in use', log):
            return returncode or 1
        if before_hash != after_hash and not args.import_project:print('Production changed during check');return 1
    print('ISOLATED_CHECK: ' + str(log_path), flush=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
