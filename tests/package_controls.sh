#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ARCHIVE="${1:?release ZIP required}"
GODOT="${GODOT_BIN:-godot}"
python3 "$ROOT/scripts/package_addon.py" verify "$ARCHIVE"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 - "$ARCHIVE" "$tmp" <<'PY'
import pathlib, stat, sys, zipfile
archive, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for name, member, symlink in (("traversal.zip", "../escape", False), ("undeclared.zip", "extra.txt", False), ("symlink.zip", "link", True)):
    out = root / name
    with zipfile.ZipFile(out, "w") as z:
        if name == "undeclared.zip":
            with zipfile.ZipFile(archive) as source:
                for info in source.infolist():
                    z.writestr(info, source.read(info.filename))
        info = zipfile.ZipInfo(member)
        if symlink:
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
        z.writestr(info, b"x")
PY
for bad in "$tmp"/*.zip; do
    if python3 "$ROOT/scripts/package_addon.py" verify "$bad"; then
        echo "unsafe package unexpectedly passed: $bad" >&2
        exit 1
    fi
    echo "EXPECTED_PACKAGE_FAILURE:$(basename "$bad")"
done
project="$tmp/project"
addon="$project/addons/@aviorstudio_gd-telemetry"
mkdir -p "$addon"
unzip -q "$ARCHIVE" -d "$addon"
cat > "$project/project.godot" <<'EOF'
[application]
config/name="gd-telemetry package fixture"
[editor_plugins]
enabled=PackedStringArray("@aviorstudio_gd-telemetry")
[consumer]
marker="preserve-me"
EOF
cat > "$project/smoke.gd" <<'EOF'
extends SceneTree
const Telemetry = preload("res://addons/@aviorstudio_gd-telemetry/src/telemetry_module.gd")
func _initialize() -> void:
	var telemetry := Telemetry.new()
	var event := telemetry.build_event(1, "info", "c", "s", "installed", {})
	if telemetry.to_dict(event).get("message") != "installed":
		quit(1)
		return
	print("PACKAGE_SMOKE_REACHED")
	quit(0)
EOF
run_editor() { timeout --foreground 60s "$GODOT" --headless --editor --path "$project" --quit; }
run_editor
run_editor
timeout --foreground 60s "$GODOT" --headless --path "$project" --script "$project/smoke.gd" | tee "$tmp/smoke.log"
grep -Fq PACKAGE_SMOKE_REACHED "$tmp/smoke.log"
python3 - "$project/project.godot" <<'PY'
import pathlib, sys
p=pathlib.Path(sys.argv[1])
p.write_text(p.read_text().replace('enabled=PackedStringArray("@aviorstudio_gd-telemetry")', 'enabled=PackedStringArray()'))
PY
run_editor
run_editor
grep -Fq 'marker="preserve-me"' "$project/project.godot"
! grep -Fq '@aviorstudio_gd-telemetry' "$project/project.godot"
python3 - "$addon" "$ROOT/dist/installed-tree.sha256" <<'PY'
import hashlib, pathlib, sys
root, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
h=hashlib.sha256()
for p in sorted(x for x in root.rglob('*') if x.is_file()):
    h.update(p.relative_to(root).as_posix().encode()+b'\0'+hashlib.sha256(p.read_bytes()).digest())
output.write_text(h.hexdigest()+"\n")
print("INSTALLED_TREE_SHA256="+h.hexdigest())
PY
