"""Validate emitted assistant Dart in an already generated disposable Flutter host.

Example: python tools/test_generated_ai_assistant.py --project-root <temp-host>
The host must first be initialized with embed init --android-separate-tasks
--ai-assistant. Only marked generated_ai_* test files are installed or refreshed.
No model/provider or API key is needed.
"""

import argparse
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--flutter", default=shutil.which("flutter") or "flutter")
    args = parser.parse_args()
    host = args.project_root.resolve()
    marker = "// Generated assistant validation fixture. Do not edit.\n"
    if not (host / "lib/mini_program/mini_program_ai.dart").is_file():
        parser.error("Initialize this disposable host with --ai-assistant first.")
    root = Path(__file__).resolve().parent.parent
    fixtures = root / "packages/mini_program_tooling/test/fixtures/ai_assistant"
    package = re.search(r"^name:\s*([a-z][a-z0-9_]*)\s*$",
                        (host / "pubspec.yaml").read_text(encoding="utf-8"), re.MULTILINE)
    if not package:
        parser.error("Expected a Flutter pubspec with an ordinary package name.")
    writes = {}
    for source in sorted(fixtures.glob("*.dart.template")):
        target = host / "test" / source.name.removesuffix(".template")
        if target.exists() and not target.read_text(encoding="utf-8").startswith(marker):
            parser.error(f"Refusing to replace host-owned test: {target}")
        content = source.read_text(encoding="utf-8").replace("'../lib/", f"'package:{package[1]}/")
        writes[target] = marker + content
    for target, content in writes.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8", newline="\n")
    subprocess.run([args.flutter, "analyze", "--fatal-infos", "lib", "test"], cwd=host, check=True)
    subprocess.run([args.flutter, "test", "--no-pub", "--concurrency", "1", "--reporter", "expanded",
                    *[str(path) for path in writes]], cwd=host, check=True)


if __name__ == "__main__":
    main()
