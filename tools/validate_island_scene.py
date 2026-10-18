"""Island/water CLI, native captures, and production isolation. Build the study first."""
import json
from pathlib import Path
import subprocess
import time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/island-scene-preview/validation'
PROJECT=ROOT/'build/island-scene-preview/project'


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    checks=[]
    def run(name,args,marker=None,timeout=60):
        log=OUT/(name+'.txt')
        split=args.index('--') if '--' in args else len(args)
        command=['godot',*args[:split],'--log-file',str(log),*args[split:]]
        start=time.monotonic()
        result=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=timeout)
        content=log.read_text(encoding='utf-8',errors='replace') if log.exists() else ''
        passed=result.returncode==0 and 'ERROR:' not in content and (marker is None or marker in content)
        checks.append(dict(name=name,command=command,exit_code=result.returncode,passed=passed,seconds=round(time.monotonic()-start,3),log=log.name))
        (OUT/'results.json').write_text(json.dumps(checks,indent=2)+'\n')
        print(name+(': PASS' if passed else ': FAIL'),flush=True)
        if not passed:raise RuntimeError(content+result.stderr.decode(errors='replace'))
    common=['--headless','--path','.']
    run('import',common+['--editor','--import','--quit'])
    run('main',common+['--quit-after','90'])
    for task in [23,24]:run(f'task{task}',common+[f'tests/cli/Task{task}Test.tscn'],f'TASK{task}_PASS')
    run('island-contract',['--headless','--path',str(PROJECT),'tests/cli/IslandSceneTest.tscn'],'ISLAND_SCENE_PASS')
    run('ocean-contract',['--headless','--path',str(PROJECT),'tests/cli/IslandOceanTest.tscn'],'ISLAND_OCEAN_PASS')
    run('native-captures',['--path',str(PROJECT),'--','--capture='+str(PROJECT.parent/'captures')],'ISLAND_SCENE_CAPTURE_PASS')
    run('ocean-captures',['--path',str(PROJECT),'--disable-vsync','--','--capture-ocean='+str(PROJECT.parent/'ocean-captures')],'ISLAND_OCEAN_CAPTURE_PASS',240)
    pack=OUT/'production.pck'
    run('production-export',common+['--export-pack','Web',str(pack)])
    run('production-content',common+['--main-pack',str(pack),'--script',str(ROOT/'tests/cli/ExportAudit.gd')],'PACK_CONTENT_PASS')
    run('source-isolation',common+['--main-pack',str(pack),'--script',str(ROOT/'tests/cli/IslandScenePackAudit.gd')],'ISLAND_SCENE_PACK_PASS')
    print('ISLAND_SCENE_VALIDATION_PASS',flush=True)


if __name__=='__main__':main()
