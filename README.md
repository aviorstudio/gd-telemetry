# gd-telemetry

Game-agnostic telemetry event batching for Godot 4.

- Package: `@aviorstudio/gd-telemetry`
- Godot: `4.x` (tested on `4.4`)

## Install

Place this folder under `res://addons/<addon-dir>/` (for example `res://addons/@aviorstudio_gd-telemetry/`).

- With `gdpm`: install/link into your project's `addons/`.
- Manually: copy or symlink this repo folder into `res://addons/<addon-dir>/`.

## Files

- `plugin.cfg` / `plugin.gd`: editor plugin entry (no runtime behavior).
- `src/telemetry_module.gd`: typed telemetry events + in-memory batching.

## Usage

```gdscript
const TelemetryModule = preload("res://addons/<addon-dir>/src/telemetry_module.gd")

TelemetryModule.configure(TelemetryModule.TelemetryConfig.new(true, 50, 0.5))
TelemetryModule.add_event(
	TelemetryModule.create_event(
		Time.get_ticks_msec(),
		"INFO",
		"match-123",
		"user-abc",
		"something happened",
		{"foo": "bar"}
	)
)

if TelemetryModule.should_flush():
	var batch := TelemetryModule.drain_serialized_batch()
	# send batch somewhere
```

## Notes

- Serialization returns dictionaries safe for network transport; metadata keys are coerced to strings.
- When disabled, add/flush operations are no-ops and batches clear automatically.
