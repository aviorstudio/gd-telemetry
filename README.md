<!-- Generated from private documentation source. Do not edit directly. Source SHA256: 7d3ea14e62ebbf1b880404b266689d74b27c68e0dfdd4337d1fc2e9a67ed4839 -->

# gd-telemetry

Build and batch telemetry events in Godot 4.

Use this addon to collect structured game events and flush them through your own callback, HTTP client, file writer, or analytics bridge.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-telemetry`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-telemetry/` and enable the plugin.

## Quick Start

```gdscript
const TelemetryModule = preload("res://addons/@aviorstudio_gd-telemetry/src/telemetry_module.gd")

var telemetry := TelemetryModule.new()
telemetry.configure(TelemetryModule.TelemetryConfig.new(
	true, 50, 0.5, 50, Callable(self, "_send_batch_to_backend")
))

telemetry.add_event(telemetry.build_event(
	Time.get_ticks_msec(),
	"INFO",
	"session-1",
	"player-1",
	"level_started",
	{"level": 3}
))

if telemetry.should_flush():
	var outcome := await telemetry.flush()
	if outcome != TelemetryModule.FlushResult.ACKNOWLEDGED:
		push_warning("Telemetry remains queued: %s" % outcome)

func _send_batch_to_backend(batch: Array[Dictionary]) -> bool:
	# Return true only after the transport acknowledges this batch.
	return await transport.send(batch)
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
- `flush`: deliver one FIFO batch and remove it only after a boolean `true`
  callback acknowledgement.
- Explicit `AddResult`, `FlushResult`, and `counters()` diagnostics.

## Delivery And Backpressure Contract

- Memory only; this addon does not provide durable delivery.
- The maximum and default cap is 1,000 events across queued and in-flight data. At
  capacity, the oldest queued event is dropped for a new event. An in-flight
  batch is never changed; if it alone consumes capacity, the newest event is
  rejected. Both cases have separate counters and `add_event` results.
- One batch may be in flight. Concurrent `flush` calls return `BUSY`.
- A callback returns or asynchronously resolves to boolean `true` to
  acknowledge. `false`, an invalid return, or a 10 second timeout fails an
  attempt. Defaults are three retries after the initial attempt with capped
  exponential delays of 0.5, 1, and 2 seconds.
- A permanently unserializable head event remains queued and reports
  `SERIALIZATION_FAILED`; the caller may explicitly discard it with
  `discard_oldest_event()`.
- `shutdown(true)` stops the owned timer, attempts a final flush, and returns
  the observable outcome. If another flush is pending, shutdown cancels it,
  restores its batch, and returns `CANCELLED`. No new events are accepted
  afterward.

## Notes

- No project settings are required.
- This addon does not choose a telemetry vendor or network transport.
- Avoid sending private user data unless your game has explicit consent and retention policy.


## License

See `LICENSE`.
