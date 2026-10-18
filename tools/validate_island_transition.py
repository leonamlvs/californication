"""V4 CLI regressions, simulated-clock contract, native playback, and pack audit."""
from pathlib import Path
import json, os, subprocess, time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/island-transition-preview/validation'
PROJECT=ROOT/'build/island-transition-preview/project'


def main():
    OUT.mkdir(parents=True,exist_ok=True);checks=[]
    def run(name,args,marker=None):
        log=OUT/(name+'.txt');split=args.index('--') if '--' in args else len(args)
        command=['godot',*args[:split],'--log-file',str(log),*args[split:]]
        start=time.monotonic();options={}
        if os.name=='nt':
            options['startupinfo']=subprocess.STARTUPINFO();options['startupinfo'].dwFlags|=subprocess.STARTF_USESHOWWINDOW
            options['startupinfo'].wShowWindow=0
        result=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=90,**options)
        content=log.read_text(encoding='utf-8',errors='replace') if log.exists() else ''
        passed=result.returncode==0 and 'ERROR:' not in content and (not marker or marker in content)
        checks.append(dict(name=name,command=command,exit_code=result.returncode,passed=passed,seconds=round(time.monotonic()-start,3),log=log.name))
        (OUT/'results.json').write_text(json.dumps(checks,indent=2)+'\n');print(name+(': PASS' if passed else ': FAIL'),flush=True)
        if not passed:raise RuntimeError(content+result.stderr.decode(errors='replace'))
    common=['--headless','--path','.']
    run('import',common+['--editor','--import','--quit'])
    run('main',common+['--quit-after','90'])
    for task in [22,23,24,26]:run(f'task{task}',common+[f'tests/cli/Task{task}Test.tscn'],f'TASK{task}_PASS')
    run('handoff-contract',['--headless','--path',str(PROJECT),'tests/cli/IslandHandoffTest.tscn'],'ISLAND_HANDOFF_PASS')
    run('native-preview',['--path',str(PROJECT),'--','--capture-native='+str(OUT/'native-attract.png')],'ISLAND_HANDOFF_NATIVE_PASS')
    pack=OUT/'production.pck'
    run('production-export',common+['--export-pack','Web',str(pack)])
    run('production-content',common+['--main-pack',str(pack),'--script',str(ROOT/'tests/cli/ExportAudit.gd')],'PACK_CONTENT_PASS')
    run('source-isolation',common+['--main-pack',str(pack),'--script',str(ROOT/'tests/cli/IslandScenePackAudit.gd')],'ISLAND_SCENE_PACK_PASS')
    print('ISLAND_HANDOFF_VALIDATION_PASS')


if __name__=='__main__': main()
