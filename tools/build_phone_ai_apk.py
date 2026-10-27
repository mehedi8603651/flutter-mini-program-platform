"""Build the explicitly opted-in personal phone AI test APK, without logging its key."""

import argparse
import base64
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from test_foreground_ai import read_key


def redact_build_output(line, key):
    # Some Windows Gradle wrappers echo -Pdart-defines, including base64 values.
    for secret in (key, base64.b64encode(('OPENROUTER_API_KEY=' + key).encode()).decode(),
                   base64.b64encode(key.encode()).decode()):
        line = line.replace(secret, '[test-key-redacted]')
    return line


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=repo / 'hosts/mp_only_host')
    parser.add_argument('--env-file', type=Path, default=repo / '.env')
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--model', default='openai/gpt-6-luna')
    args = parser.parse_args()
    if not args.flutter:
        parser.error('Flutter was not found. Pass --flutter with its executable path.')
    if not re.fullmatch(r'[A-Za-z0-9._-]+/[A-Za-z0-9._:-]+', args.model):
        parser.error('Pass a provider/model ID for --model.')
    key = read_key(args.env_file)
    descriptor, name = tempfile.mkstemp(prefix='mini_program_phone_ai_', suffix='.json')
    os.close(descriptor)
    defines = Path(name)
    try:
        defines.write_text(json.dumps({
            'MINI_PROGRAM_PHONE_AI_TEST': True,
            'OPENROUTER_API_KEY': key,
            'MINI_PROGRAM_AI_MODEL': args.model,
        }), encoding='utf-8')
        command = [
            args.flutter, 'build', 'apk', '--release',
            '--target-platform', 'android-arm64,android-x64',
            '--build-name', '1.0.0-shared-ai', '--build-number', '6',
            '--dart-define-from-file=' + str(defines),
        ]
        with subprocess.Popen(command, cwd=args.project_root, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True,
                              encoding='utf-8', errors='replace') as process:
            for line in process.stdout:
                print(redact_build_output(line, key), end='', flush=True)
            result = process.wait()
        if result:
            raise subprocess.CalledProcessError(result, command)
        apk = args.project_root / 'build/app/outputs/flutter-apk/app-release.apk'
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(apk, args.output)
            apk = args.output
        print('Personal AI test APK: ' + str(apk.resolve()))
        print('AI model: ' + args.model)
        print('Includes the authorized test key; keep this APK for personal testing.')
    finally:
        defines.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
