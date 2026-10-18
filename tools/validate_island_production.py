"""Validate Task 23.V5 production flow and its packaged companion assets."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/island-production/validation'
EXPECTED = '3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    previous = json.loads((OUT/'results.json').read_text()) if '--resume' in sys.argv and (OUT/'results.json').exists() else []
    def run(name, command, marker=None, timeout=120):
        recorded = next((x for x in previous if x['name'] == name and x['command'] == command and x['passed']), None)
        if recorded:
            results.append(recorded)
            print(name + ': prior PASS retained', flush=True)
            return
        options = {}
        if os.name == 'nt':
            options['startupinfo'] = subprocess.STARTUPINFO()
            options['startupinfo'].dwFlags |= subprocess.STARTF_USESHOWWINDOW
            options['startupinfo'].wShowWindow = 0
        start = time.monotonic()
        result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=timeout, **options)
        text = result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')
        (OUT / (name + '.txt')).write_text(text, encoding='utf-8')
        passed = result.returncode == 0 and 'SCRIPT ERROR:' not in text and 'ERROR:' not in text and (not marker or marker in text)
        results.append(dict(name=name, command=command, passed=passed, exit_code=result.returncode, seconds=round(time.monotonic()-start, 3)))
        (OUT / 'results.json').write_text(json.dumps(results, indent=2)+'\n')
        print(name + (': PASS' if passed else ': FAIL'), flush=True)
        if not passed:
            raise RuntimeError(text[-6000:])
    base = ['godot', '--headless', '--path', '.']
    run('import', base + ['--editor', '--import', '--quit'])
    run('main', base + ['--quit-after', '90'])
    for task in [22, 23, 24, 26]:
        run(f'task{task}', base + [f'tests/cli/Task{task}Test.tscn'], f'TASK{task}_PASS')
    for suite in ['task_01', 'task_02', 'task_03']:
        run('shared-' + suite, base + ['tests/cli/TestRunner.tscn', '--', '--suite=' + suite], 'test passed.')
    run('production-flow', base + ['tests/cli/RehabilitationTest.tscn'], 'REHABILITATION_PASS')
    run('web-package', ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'tools/package_web.ps1'], 'WEB_PACKAGE_PASS', 180)
    for name, script, marker in [
        ('pack-content', 'ExportAudit.gd', 'PACK_CONTENT_PASS'),
        ('pack-island', 'IslandProductionPackAudit.gd', 'ISLAND_PRODUCTION_PACK_PASS'),
    ]:
        run(name, base + ['--main-pack', 'build/web/index.pck', '--script', 'tests/cli/' + script], marker)
    with zipfile.ZipFile(ROOT/'build/itch/californication-web.zip') as archive:
        clip = archive.read('index.island-intro.mp4')
        assert hashlib.sha256(clip).hexdigest() == EXPECTED
        assert all('/' not in name and name.startswith('index.') for name in archive.namelist())
        assert not any(name.endswith(('.ogv', '.blend')) for name in archive.namelist())
        package = dict(clip_sha256=EXPECTED, files=archive.namelist(), bytes=sum(x.file_size for x in archive.infolist()))
    (OUT/'package.json').write_text(json.dumps(package, indent=2)+'\n')
    print('ISLAND_PRODUCTION_VALIDATION_PASS exact companion verified inside ZIP', flush=True)


if __name__ == '__main__':
    main()
