extends SceneTree

const Telemetry = preload("res://addon/src/telemetry_module.gd")
signal callback_ack(value: bool)
signal callback_never(value: bool)

var failures: Array[String] = []
var callback_mode := "success"
var callback_calls := 0
var batches: Array = []

func _initialize() -> void:
	await _test_acknowledgement_and_retry()
	await _test_queue_pressure_and_pending_isolation()
	await _test_duplicate_timeout_serialization_shutdown()
	await _test_timer_ownership()
	if failures.is_empty():
		print("TEST_REACHED:telemetry_module_test.gd")
		print("PASS gd-telemetry telemetry_module_test")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _config(callback: Callable, cap := 1000, batch := 50, retries := 3, timeout := 0.02) -> Telemetry.TelemetryConfig:
	return Telemetry.TelemetryConfig.new(true, batch, 0.01, 50, callback, cap, retries, 0.001, 0.002, timeout)

func _event(id: int, metadata := {}) -> Telemetry.TelemetryEvent:
	return Telemetry.TelemetryEvent.new(id, "info", "context", "subject", "event-%d" % id, metadata)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _reset_callback(mode: String) -> void:
	callback_mode = mode
	callback_calls = 0
	batches.clear()

func _callback(batch: Array[Dictionary]) -> Variant:
	callback_calls += 1
	batches.append(batch.duplicate(true))
	match callback_mode:
		"success": return true
		"failure": return false
		"invalid": return "not-an-ack"
		"async":
			call_deferred("_emit_callback_ack", true)
			return callback_ack
		"pending": return callback_ack
		"timeout": return callback_never
	return false

func _emit_callback_ack(value: bool) -> void:
	callback_ack.emit(value)

func _test_acknowledgement_and_retry() -> void:
	_reset_callback("failure")
	var telemetry := Telemetry.new()
	_check(telemetry.configure(_config(Callable(self, "_callback"), 10, 2)), "valid configuration rejected")
	telemetry.add_event(_event(1))
	var result: Telemetry.FlushResult = await telemetry.flush()
	_check(result == Telemetry.FlushResult.FAILED_AFTER_RETRIES, "failed callback did not report exhausted retries")
	_check(callback_calls == 4, "expected initial callback plus three retries")
	_check(batches.size() == 4 and batches.all(func(batch): return batch[0].timestamp == 1), "retry changed FIFO batch identity")
	_check(telemetry.event_count() == 1 and telemetry.in_flight_count() == 0, "failed batch was not restored")
	_check(telemetry.counters().retry_attempts == 3, "retry counter mismatch")
	_reset_callback("success")
	result = await telemetry.flush()
	_check(result == Telemetry.FlushResult.ACKNOWLEDGED and telemetry.event_count() == 0, "acknowledged batch was not removed")

func _test_queue_pressure_and_pending_isolation() -> void:
	_reset_callback("invalid")
	var telemetry := Telemetry.new()
	telemetry.configure(_config(Callable(), 1000, 1000))
	for id in range(1000): telemetry.add_event(_event(id))
	var add_result := telemetry.add_event(_event(1000))
	_check(add_result == Telemetry.AddResult.DROPPED_OLDEST_AND_ADDED, "oldest-first overflow result missing")
	_check(telemetry.counters().dropped_oldest == 1 and telemetry.event_count() == 1000, "queue cap/drop counter mismatch")
	_check(await telemetry.flush() == Telemetry.FlushResult.INVALID_CALLBACK and telemetry.event_count() == 1000, "invalid callback pressure was not retained/observable")
	telemetry.configure(_config(Callable(self, "_callback"), 1000, 1000))
	_reset_callback("success")
	await telemetry.flush()
	_check(batches[0][0].timestamp == 1 and batches[0][-1].timestamp == 1000, "oldest-first FIFO order mismatch")

	telemetry = Telemetry.new()
	telemetry.configure(_config(Callable(), 2, 2))
	telemetry.add_event(_event(10)); telemetry.add_event(_event(11))
	telemetry.configure(_config(Callable(self, "_callback"), 2, 2, 0))
	_reset_callback("pending")
	telemetry._flush_requested.emit()
	_check(telemetry.in_flight_count() == 2, "batch was not isolated in flight")
	_check(telemetry.add_event(_event(12)) == Telemetry.AddResult.REJECTED_IN_FLIGHT_CAPACITY, "newest event was not rejected when only in-flight capacity remained")
	_check(telemetry.counters().dropped_newest == 1, "newest rejection counter mismatch")
	callback_ack.emit(false)
	await process_frame
	_check(telemetry.queued_count() == 2 and telemetry.in_flight_count() == 0, "failed pending batch was not restored in isolation")

func _test_duplicate_timeout_serialization_shutdown() -> void:
	var telemetry := Telemetry.new()
	telemetry.configure(_config(Callable(self, "_callback"), 3, 2, 0))
	_reset_callback("pending")
	telemetry.add_event(_event(1))
	telemetry._flush_requested.emit()
	var duplicate: Telemetry.FlushResult = await telemetry.flush()
	_check(duplicate == Telemetry.FlushResult.BUSY, "duplicate concurrent flush was not rejected")
	callback_ack.emit(true)
	await process_frame
	_check(telemetry.event_count() == 0 and telemetry.counters().acknowledged_batches == 1, "async true acknowledgement failed")

	_reset_callback("timeout")
	telemetry.add_event(_event(2))
	var timed: Telemetry.FlushResult = await telemetry.flush()
	_check(timed == Telemetry.FlushResult.FAILED_AFTER_RETRIES and telemetry.counters().callback_timeouts == 1, "callback timeout was not observable")

	telemetry = Telemetry.new()
	telemetry.configure(_config(Callable(self, "_callback"), 3, 2, 0))
	_reset_callback("invalid")
	telemetry.add_event(_event(20))
	_check(await telemetry.flush() == Telemetry.FlushResult.FAILED_AFTER_RETRIES and telemetry.event_count() == 1, "invalid callback acknowledgement was not a visible failure")

	telemetry = Telemetry.new()
	telemetry.configure(_config(Callable(self, "_callback"), 3, 2, 0))
	_reset_callback("success")
	telemetry.add_event(_event(3, {"bad": Callable(self, "_callback")}))
	_check(await telemetry.flush() == Telemetry.FlushResult.SERIALIZATION_FAILED, "serialization failure was not reported")
	_check(telemetry.event_count() == 1 and telemetry.counters().serialization_failures == 1, "serialization failure did not preserve pending event")
	_check(telemetry.discard_oldest_event(), "explicit poison-event discard failed")
	telemetry.add_event(_event(4))
	_check(await telemetry.shutdown(true) == Telemetry.FlushResult.ACKNOWLEDGED, "shutdown flush outcome mismatch")
	_check(telemetry.add_event(_event(5)) == Telemetry.AddResult.DISABLED, "shutdown accepted a new event")

	telemetry = Telemetry.new()
	telemetry.configure(_config(Callable(self, "_callback"), 3, 2, 0))
	_reset_callback("pending")
	telemetry.add_event(_event(6))
	telemetry._flush_requested.emit()
	_check(await telemetry.shutdown(true) == Telemetry.FlushResult.CANCELLED, "shutdown did not cancel and observe an existing flush")
	_check(telemetry.event_count() == 1 and telemetry.add_event(_event(7)) == Telemetry.AddResult.DISABLED, "cancelled shutdown lost pending data or stayed enabled")

func _test_timer_ownership() -> void:
	_reset_callback("success")
	var telemetry := Telemetry.new()
	telemetry.configure(_config(Callable(self, "_callback"), 10, 10))
	var owner := Node.new()
	get_root().add_child(owner)
	_check(telemetry.start_auto_flush(owner), "valid auto-flush owner rejected")
	telemetry.add_event(_event(1))
	await create_timer(0.04).timeout
	_check(callback_calls > 0, "auto-flush timer did not invoke callback")
	var replacement := _config(Callable(self, "_callback"), 10, 10)
	replacement.batch_interval_s = 0.02
	_check(telemetry.configure(replacement) and telemetry.has_auto_flush_timer(), "reconfigure lost timer ownership")
	var disabled := _config(Callable(self, "_callback"), 10, 10)
	disabled.enabled = false
	_check(telemetry.configure(disabled) and telemetry.add_event(_event(2)) == Telemetry.AddResult.DISABLED, "disabled reconfigure still accepted events")
	_check(telemetry.configure(replacement) and telemetry.has_auto_flush_timer(), "reenable did not preserve timer ownership")
	owner.queue_free()
	await process_frame
	_check(not telemetry.has_auto_flush_timer(), "owner destruction retained timer")
	telemetry.stop_auto_flush()
	telemetry.stop_auto_flush()
