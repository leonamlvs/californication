"""Preserve successful V4 checks, real browser capture, and asset integrity."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build/island-transition-preview'
OUT = ROOT / 'docs/evidence/island_intro/v4'
SOURCE_HASH = '3775cdc7a3a680d4ece5ca7578b52e7ad55e4107f8053697421acaf8d4619866'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    native = json.loads((BUILD / 'validation/results.json').read_text())
    browser = json.loads((BUILD / 'browser/results.json').read_text())
    assert len(native) == 11 and all(c['passed'] for c in native)
    assert len(browser['checks']) == 12 and all(c['passed'] for c in browser['checks'])
    assert digest(BUILD / 'web/index.island-intro.mp4') == SOURCE_HASH
    assert (OUT / 'review/browser-handoff.mp4').is_file()
    for folder in ['validation', 'browser']:
        destination = OUT / folder
        destination.mkdir(parents=True, exist_ok=True)
        for path in (BUILD / folder).iterdir():
            # Raw screencast frames/profiles and stale failure diagnostics stay in build.
            if path.is_file() and (path.suffix in ['.txt', '.png'] or path.name in ['results.json', 'recording.json']):
                shutil.copyfile(path, destination / path.name)
    for name in ['import.txt', 'web-export.txt', 'media-manifest.json']:
        shutil.copyfile(BUILD / name, OUT / 'validation' / ('build-' + name))
    expected = {}
    for milestone in ['v2', 'v3']:
        manifest = json.loads((ROOT / f'docs/evidence/island_intro/{milestone}/asset-manifest.json').read_text())
        expected.update({item['path']: item['sha256'] for item in manifest['files']})
    v3 = json.loads((ROOT / 'docs/evidence/island_intro/v3/integrity.json').read_text())
    expected.update({item['path']: item['sha256'] for item in v3['files'] if item['path'].startswith('dev/island_scene/')})
    preserved = []
    for name, expected_hash in sorted(expected.items()):
        actual = digest(ROOT / name)
        assert actual == expected_hash, 'Approved asset/study changed: ' + name
        preserved.append(dict(path=name, sha256=actual, unchanged=True))
    save('preservation.json', preserved)
    save('commands.json', [
        ['python', 'tools/build_island_transition_preview.py', '--web'],
        ['python', 'tools/validate_island_transition.py'],
        ['node', 'tools/test_island_transition_web.mjs'],
        ['C:/Program Files/Blender Foundation/Blender 4.2/blender.exe', '--background', '--factory-startup', '--python-exit-code', '1', '--python', 'tools/capture_island_transition_review.py'],
        ['python', 'tools/finalize_island_transition_evidence.py'],
    ])
    sources = list((ROOT / 'dev/island_transition').rglob('*')) + list(OUT.rglob('*'))
    sources += list((ROOT / 'tests/cli').glob('IslandHandoff*'))
    sources += [ROOT / name for name in [
        'tests/cli/IslandScenePackAudit.gd',
        'data/definitions/CinematicFXProfile.gd',
        'presentation/cinematic_fx/CinematicTransitionFX.gd',
    ]]
    sources += [ROOT / 'tools' / name for name in [
        'build_island_transition_preview.py', 'validate_island_transition.py',
        'test_island_transition_web.mjs', 'serve_island_transition.mjs',
        'capture_island_transition_review.py', 'finalize_island_transition_evidence.py',
    ]]
    files = [dict(path=p.relative_to(ROOT).as_posix(), bytes=p.stat().st_size, sha256=digest(p))
             for p in sorted(set(sources)) if p.is_file() and p != OUT / 'integrity.json']
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    save('integrity.json', dict(head=head, working_changes='V0-V4 uncommitted; V4 visual approval pending; production integration not started', files=files))
    print('ISLAND_HANDOFF_EVIDENCE_PASS', len(files), 'files; 11 CLI/native/package and 12 browser checks; approved V2/V3 assets unchanged')


if __name__ == '__main__':
    main()
