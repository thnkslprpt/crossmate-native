#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for script in scripts/*.sh; do
  bash -n "$script"
done

python3 - <<'PY'
from pathlib import Path
import json
import re
import sys

try:
    import yaml
except ImportError:
    print('[crossmate] ERROR: Python package PyYAML is required for source-only validation.', file=sys.stderr)
    print('[crossmate] Install it with: sudo apt-get install -y python3-yaml', file=sys.stderr)
    raise SystemExit(1)

root = Path.cwd()

for path in root.rglob('*.json'):
    json.loads(path.read_text(encoding='utf-8'))
for suffix in ('*.yaml', '*.yml'):
    for path in root.rglob(suffix):
        yaml.safe_load(path.read_text(encoding='utf-8'))

for path in root.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    for match in re.finditer(r"import\s+'([^']+)';", text):
        imported = match.group(1)
        if imported.startswith('.') and not (path.parent / imported).resolve().exists():
            raise SystemExit(f'[crossmate] Missing relative import: {path}: {imported}')
    if re.search(r'\b(?:TODO|FIXME)\b|\b(?:debugPrint|print)\s*\(', text):
        raise SystemExit(f'[crossmate] Unfinished/debug marker: {path}')

icon = root / 'assets/icon/crossmate-icon.png'
if not icon.exists() or icon.stat().st_size < 10000:
    raise SystemExit('[crossmate] App icon is missing or unexpectedly small.')

print('[crossmate] Source-only checks passed.')
print('[crossmate] Next full checks: ./scripts/bootstrap.sh')
PY
