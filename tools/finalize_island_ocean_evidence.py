"""Preserve V3 results after all native, browser, and rendered checks pass."""
from pathlib import Path
import hashlib, json, shutil, subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/island_intro/v3'
BUILD=ROOT/'build/island-scene-preview'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    native=json.loads((BUILD/'validation/results.json').read_text())
    browser=json.loads((BUILD/'web-checks/results.json').read_text())
    rendered=json.loads((OUT/'render-checks.json').read_text())
    assert len(native)==11 and all(check['passed'] for check in native)
    assert len(browser['checks'])==8 and all(check['passed'] for check in browser['checks'])
    assert len(rendered['checks'])==16 and all(check['passed'] for check in rendered['checks'])
    for folder, source in [('validation',BUILD/'validation'),('browser',BUILD/'web-checks')]:
        destination=OUT/folder;destination.mkdir(exist_ok=True)
        for p in source.iterdir():
            if p.is_file() and (p.suffix in ['.txt','.png'] or p.name=='results.json'):
                shutil.copyfile(p,destination/p.name)
    for name in ['generate-ocean.txt','import.txt','web-export.txt']:
        shutil.copyfile(BUILD/name,OUT/'validation'/('build-'+name))
    v2=json.loads((ROOT/'docs/evidence/island_intro/v2/asset-manifest.json').read_text())
    preserved=[]
    for item in v2['files']:
        path=ROOT/item['path'];actual=digest(path)
        assert actual==item['sha256'], 'Approved V2 asset changed: '+str(path)
        preserved.append(dict(path=item['path'],sha256=actual,unchanged=True))
    (OUT/'preservation.json').write_text(json.dumps(preserved,indent=2)+'\n')
    commands=[['python','tools/build_island_scene_preview.py','--generate-ocean','--web'],
              ['python','tools/validate_island_scene.py'],['node','tools/test_island_scene_web.mjs'],
              ['C:/Program Files/Blender Foundation/Blender 4.2/blender.exe','--background','--factory-startup','--python-exit-code','1','--python','tools/capture_island_ocean_review.py'],
              ['python','tools/finalize_island_ocean_evidence.py']]
    (OUT/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    sources=list((ROOT/'dev/island_scene').rglob('*'))+list(OUT.rglob('*'))
    sources += list((ROOT/'tests/cli').glob('IslandOcean*'))
    sources += [ROOT/'art/source/island_intro/ocean-authoring.json']
    sources += [ROOT/'tools'/name for name in ['generate_island_ocean.py','capture_island_ocean_review.py','finalize_island_ocean_evidence.py','build_island_scene_preview.py','validate_island_scene.py','test_island_scene_web.mjs']]
    files=[]
    for p in sorted(set(sources)):
        if p.is_file() and p!=OUT/'integrity.json':
            files.append(dict(path=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=digest(p)))
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    (OUT/'integrity.json').write_text(json.dumps(dict(head=head,working_changes='V0-V3 uncommitted; production scenes/controllers/settings unchanged',files=files),indent=2)+'\n')
    print('ISLAND_OCEAN_EVIDENCE_PASS',len(files),'files; 11 CLI/native/package, 8 browser, 16 rendered checks')


if __name__=='__main__':main()
