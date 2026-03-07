# gd-telemetry

Telemetry event batching for Godot 4 with configurable flush behavior.

This addon is intentionally focused on event queueing/flush boundaries.

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
telemetry.add_event(telemetry.build_event(Time.get_ticks_msec(), "INFO", "match-1", "player-1", "connected", {}))
```

## API Reference

- `TelemetryConfig`: enable flag, batch size, interval, and flush callback.
- `TelemetryEvent`: typed telemetry payload container.
- `add_event`, `should_flush`, `drain_serialized_batch`, `flush`: batching and output pipeline.

## Scope Boundary

- In scope: telemetry event modeling, batching, and flush callback invocation.
- Out of scope: destination-specific transport clients and product analytics orchestration.

## Configuration

No project settings are required.

## Testing

`./tests/test.sh`

## License

MIT
