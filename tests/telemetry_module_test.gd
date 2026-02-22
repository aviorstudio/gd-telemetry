extends SceneTree

const TelemetryModule = preload("res://src/telemetry_module.gd")

var _flush_call_count: int = 0
var _last_batch_size: int = 0

func _initialize() -> void:
	var failures: Array[String] = []
	await _test_auto_flush_lifecycle(failures)

	if failures.is_empty():
		print("PASS gd-telemetry telemetry_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_auto_flush_lifecycle(failures: Array[String]) -> void:
	_flush_call_count = 0
	_last_batch_size = 0

	var telemetry := TelemetryModule.new()
	var config := TelemetryModule.TelemetryConfig.new(true, 50, 0.01, 50, Callable(self, "_capture_flush"))
	telemetry.configure(config)

	var owner := Node.new()
	get_root().add_child(owner)
	telemetry.start_auto_flush(owner)

	telemetry.add_event(telemetry.create_event(Time.get_ticks_msec(), "info", "m1", "p1", "message", {"ok": true}))
	await create_timer(0.05).timeout

	if _flush_call_count <= 0:
		failures.append("Expected auto flush timer to invoke flush callback")
	if _last_batch_size != 1:
		failures.append("Expected flushed batch to include queued event")

	telemetry.stop_auto_flush()
	telemetry.add_event(telemetry.create_event(Time.get_ticks_msec(), "info", "m1", "p1", "message2", {}))
	var calls_before_wait: int = _flush_call_count
	await create_timer(0.03).timeout
	if _flush_call_count != calls_before_wait:
		failures.append("Expected stop_auto_flush to stop timer-driven callbacks")

	owner.queue_free()

func _capture_flush(batch: Array[Dictionary]) -> void:
	_flush_call_count += 1
	_last_batch_size = batch.size()
