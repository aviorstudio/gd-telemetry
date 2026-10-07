#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
tools="$(python3 scripts/engineering-bootstrap.py)"
export XDG_DATA_HOME="$PWD/.artifacts/godot-data"
python3 "$tools/helpers/godot-setup.py" \
  --version 4.7.2 --expected-version 4.7.2.stable.official.ed1daf0bf \
  --binary-checksum sha256:cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4 \
  --root "$PWD/.artifacts/godot" --origin godot
