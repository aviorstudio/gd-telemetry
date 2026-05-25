# gd-telemetry

Build and batch telemetry events in Godot 4.

Use this addon to collect structured game events and flush them through your own callback, HTTP client, file writer, or analytics bridge.

## Installation

### Via gdpm

`gdpm install @aviorstudio/gd-telemetry`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-telemetry/` and enable the plugin.

## Quick Start

```gdscript
const TelemetryModule = preload("res://addons/@aviorstudio_gd-telemetry/src/telemetry_module.gd")

var telemetry := TelemetryModule.new()
telemetry.configure(TelemetryModule.TelemetryConfig.new(true, 50, 0.5))

telemetry.add_event(telemetry.build_event(
	Time.get_ticks_msec(),
	"INFO",
	"session-1",
	"player-1",
	"level_started",
	{"level": 3}
))

if telemetry.should_flush():
	var batch: Array = telemetry.drain_serialized_batch()
	_send_batch_to_backend(batch)
```

## Event Shape

Serialized events use this dictionary shape:

- `timestamp`: event time in milliseconds.
- `level`: caller-defined severity or category.
- `context_id`: session, match, screen, level, or other grouping ID.
- `subject_id`: player, device, actor, or other subject ID.
- `message`: caller-defined event name.
- `metadata`: JSON-compatible event details.

## What You Get

- `TelemetryConfig`: enable flag, batch size, interval, and flush callback.
- `TelemetryEvent`: typed event container.
- `build_event`: create consistent events.
- `add_event`: queue events.
- `should_flush`: check batch size/time thresholds.
- `drain_serialized_batch` / `flush`: hand events to your transport layer.

## Notes

- No project settings are required.
- This addon does not choose a telemetry vendor or network transport.
- Avoid sending private user data unless your game has explicit consent and retention policy.

## Testing

`./tests/test.sh`

## License

MIT
