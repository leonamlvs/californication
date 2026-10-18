"""Preserve successful V5 production checks and approved asset provenance."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/island_intro/v5'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    validation = ROOT / 'build/island-production/validation'
    browser = ROOT / 'build/rehabilitation/browser'
    checks = json.loads((validation / 'results.json').read_text())
    web = json.loads((browser / 'results.json').read_text())
    assert len(checks) == 13 and all(c['passed'] for c in checks)
    assert web['passed'] and len(web['checks']) >= 6
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copytree(validation, OUT / 'validation', dirs_exist_ok=True)
    (OUT / 'browser').mkdir(exist_ok=True)
    for name in ['results.json', 'console.json', *web['captures']]:
        shutil.copyfile(browser / name, OUT / 'browser' / name)
    for path in browser.glob('*.txt'):
        shutil.copyfile(path, OUT / 'browser' / path.name)
    preserved = []
    for name in ['island.glb', 'island-color.png', 'ocean-shore.png', 'ocean-ripple.png']:
        original = ROOT / 'dev/island_scene/assets' / name
        runtime = ROOT / 'frontend/island/live/assets' / name
        assert digest(original) == digest(runtime), name
        preserved.append(dict(source=str(original.relative_to(ROOT)), runtime=str(runtime.relative_to(ROOT)), sha256=digest(runtime)))
    clip = ROOT / 'build/web/index.island-intro.mp4'
    assert digest(clip) == '3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866'
    baseline = OUT / 'baseline-before'
    baseline.mkdir(exist_ok=True)
    for folder in ['validation', 'browser']:
        source = ROOT / 'build/island-transition-preview' / folder / 'results.json'
        shutil.copyfile(source, baseline / (folder + '-results.json'))
    manifest = dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    date='2026-10-18', milestone='23.V5', clip_sha256=digest(clip), preserved=preserved,
                    commands=['python tools/validate_island_production.py', 'node tools/smoke_web.mjs', 'python tools/finalize_island_production_evidence.py'],
                    limitations=['V6 actual device measurements and visual review 3 pending'])
    paths = list((ROOT / 'frontend/island/live').rglob('*'))
    manifest['runtime_files'] = [dict(path=str(p.relative_to(ROOT)), sha256=digest(p)) for p in sorted(paths) if p.is_file()]
    (OUT / 'integrity.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('V5 evidence preserved; approved runtime asset copies match.')


if __name__ == '__main__':
    main()
