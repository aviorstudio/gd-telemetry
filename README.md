# gd-telemetry

Telemetry event batching for Godot 4 with configurable flush behavior.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-telemetry`

### Manual
Copy this directory into `addons/@aviorstudio_gd-telemetry/` and enable the plugin.

## Quick Start

```gdscript
const TelemetryModule = preload("res://addons/@aviorstudio_gd-telemetry/src/telemetry_module.gd")

var telemetry := TelemetryModule.new()
telemetry.configure(TelemetryModule.TelemetryConfig.new(true, 50, 0.5))
telemetry.add_event(telemetry.create_event(Time.get_ticks_msec(), "INFO", "match-1", "player-1", "connected", {}))
```

## API Reference

- `TelemetryConfig`: enable flag, batch size, interval, and flush callback.
- `TelemetryEvent`: typed telemetry payload container.
- `add_event`, `should_flush`, `drain_serialized_batch`, `flush`: batching and output pipeline.

## Configuration

No project settings are required.

## Testing

`./run_tests.sh`

## License

MIT
