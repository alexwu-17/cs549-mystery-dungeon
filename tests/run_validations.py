#!/usr/bin/env python3
"""Run focused gameplay checks or the full Godot validation suite."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
GAMEPLAY = (
    "drapion_moves", "terrain_visibility",
    "status_moves", "status_duration",
    "recovery", "repopulation",
    "enemy_moves", "damage_numbers", "pokemon_moves", "starter_selection", "battle_state", "combat", "sequential_rounds", "held_movement", "hud",
    "move_panel", "boss", "drapion_swing", "enemy_defeat", "modes",
    "floor_introduction", "invincibility",
)
FAILURE = re.compile(r"SCRIPT ERROR|Assertion failed|Parse Error")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--suite", choices=("gameplay", "full"), default="gameplay")
    parser.add_argument("--log-dir", type=Path, default=ROOT / ".godot" / "validation")
    parser.add_argument("--timeout", type=float, default=180.0)
    args = parser.parse_args()
    executable = shutil.which(args.godot)
    if executable is None:
        parser.error("Godot executable not found; supply --godot PATH or GODOT_BIN")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    tests = (sorted((ROOT / "tests").glob("validate_*.gd")) if args.suite == "full"
             else [ROOT / "tests" / f"validate_{name}.gd" for name in GAMEPLAY])
    args.log_dir = args.log_dir.resolve()
    args.log_dir.mkdir(parents=True, exist_ok=True)
    failed = []
    for test in tests:
        log = args.log_dir / f"{test.stem}.log"
        start = time.monotonic()
        interrupted = False
        with log.open("w", encoding="utf-8") as output:
            process = subprocess.Popen(
                [executable, "--headless", "--path", str(ROOT), "--script",
                 f"res://tests/{test.name}", "--quit-after", "600", "--log-file",
                 str(args.log_dir / f"{test.stem}-engine.log")],
                cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
            )
            try:
                while process.poll() is None:
                    if (FAILURE.search(log.read_text(errors="replace")) or
                            time.monotonic() - start > args.timeout):
                        interrupted = True
                        process.terminate()
                        break
                    time.sleep(0.1)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            except KeyboardInterrupt:
                process.terminate()
                process.wait()
                raise
        text = log.read_text(errors="replace")
        passed = (not interrupted and process.returncode == 0 and
                  "PASS:" in text and not FAILURE.search(text))
        print(f"{'PASS' if passed else 'FAIL'} {test.stem} ({time.monotonic() - start:.1f}s)", flush=True)
        if not passed:
            failed.append(test.name)
            print(f"  Inspect {log}", flush=True)
    print(f"{len(tests) - len(failed)}/{len(tests)} PASS", flush=True)
    return bool(failed)


if __name__ == "__main__":
    sys.exit(main())
