"""Validate V1 and preserve command/log evidence. Build the isolated preview first."""
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/island-video-preview/validation"
PROJECT = ROOT / "build/island-video-preview/project"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    checks = []

    def run(name, arguments, marker=None):
        log = OUTPUT / (name + ".txt")
        command = ["godot", *arguments, "--log-file", str(log)]
        # User arguments must follow all engine options.
        if "--" in arguments:
            index = arguments.index("--")
            command = ["godot", *arguments[:index], "--log-file", str(log), *arguments[index:]]
        start = time.monotonic()
        result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=60)
        text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
        passed = result.returncode == 0 and "ERROR:" not in text and (marker is None or marker in text)
        checks.append(dict(name=name, command=command, exit_code=result.returncode, passed=passed,
                           elapsed_seconds=round(time.monotonic() - start, 3), log=log.name))
        (OUTPUT / "results.json").write_text(json.dumps(checks, indent=2) + "\n", encoding="utf-8")
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
        if not passed:
            raise RuntimeError(text + result.stderr.decode(errors="replace"))

    common = ["--headless", "--path", "."]
    run("import", [*common, "--editor", "--import", "--quit"])
    run("main", [*common, "--quit-after", "90"])
    for task in [23, 24]:
        run(f"task{task}", [*common, f"tests/cli/Task{task}Test.tscn"], f"TASK{task}_PASS")
    run("contract", [*common, "tests/cli/IslandVideoNativeTest.tscn"], "ISLAND_VIDEO_CONTRACT_PASS")
    captures = OUTPUT / "native"
    captures.mkdir(exist_ok=True)
    run("native", ["--path", str(PROJECT), "tests/cli/IslandVideoNativeTest.tscn", "--", f"--captures={captures}"], "ISLAND_VIDEO_NATIVE_PASS")
    pack = OUTPUT / "production.pck"
    run("production-export", [*common, "--export-pack", "Web", str(pack)])
    run("production-content", [*common, "--main-pack", str(pack), "--script", str(ROOT / "tests/cli/ExportAudit.gd")], "PACK_CONTENT_PASS")
    audit = str(ROOT / "tests/cli/IslandVideoPackAudit.gd")
    run("production-isolation", [*common, "--main-pack", str(pack), "--script", audit], "ISLAND_VIDEO_PACK_PASS")
    run("preview-isolation", [*common, "--main-pack", str(PROJECT.parent / "web/index.pck"), "--script", audit, "--", "--preview"], "ISLAND_VIDEO_PACK_PASS")
    print("ISLAND_VIDEO_VALIDATION_PASS", flush=True)


if __name__ == "__main__":
    main()
