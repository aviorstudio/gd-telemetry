class_name TelemetryModule
extends RefCounted
## Bounded, acknowledged, in-memory telemetry delivery.

signal _ack_completed(generation: int, acknowledged: bool)
signal _flush_requested
signal flush_finished(result)

enum AddResult { ADDED, DISABLED, INVALID_EVENT, DROPPED_OLDEST_AND_ADDED, REJECTED_IN_FLIGHT_CAPACITY }
enum FlushResult { ACKNOWLEDGED, EMPTY, DISABLED, INVALID_CALLBACK, BUSY, SERIALIZATION_FAILED, FAILED_AFTER_RETRIES, CANCELLED }

const MAX_QUEUE_EVENTS := 1000
const MAX_RETRIES := 3
const MAX_RETRY_INITIAL_DELAY_S := 0.5
const MAX_RETRY_DELAY_S := 2.0
const MAX_CALLBACK_TIMEOUT_S := 10.0

class TelemetryConfig extends RefCounted:
	var enabled: bool
	var batch_size: int
	var batch_interval_s: float
	var max_debug_messages: int
	var flush_callback: Callable
	var max_queue_events: int
	var max_retries: int
	var retry_initial_delay_s: float
	var retry_max_delay_s: float
	var callback_timeout_s: float

	func _init(
		enabled: bool = false,
		batch_size: int = 50,
		batch_interval_s: float = 0.5,
		max_debug_messages: int = 50,
		flush_callback: Callable = Callable(),
		max_queue_events: int = 1000,
		max_retries: int = 3,
		retry_initial_delay_s: float = 0.5,
		retry_max_delay_s: float = 2.0,
		callback_timeout_s: float = 10.0
	) -> void:
		self.enabled = enabled
		self.batch_size = batch_size
		self.batch_interval_s = batch_interval_s
		self.max_debug_messages = max_debug_messages
		self.flush_callback = flush_callback
		self.max_queue_events = max_queue_events
		self.max_retries = max_retries
		self.retry_initial_delay_s = retry_initial_delay_s
		self.retry_max_delay_s = retry_max_delay_s
		self.callback_timeout_s = callback_timeout_s

class TelemetryEvent extends RefCounted:
	var timestamp_msec: int
	var level: String
	var context_id: String
	var subject_id: String
	var message: String
	var metadata: Dictionary

	func _init(timestamp_msec: int = 0, level: String = "", context_id: String = "", subject_id: String = "", message: String = "", metadata: Dictionary = {}) -> void:
		self.timestamp_msec = timestamp_msec
		self.level = level
		self.context_id = context_id
		self.subject_id = subject_id
		self.message = message
		self.metadata = metadata.duplicate(true)

var _config: TelemetryConfig = TelemetryConfig.new()
var _event_queue: Array[TelemetryEvent] = []
var _in_flight: Array[TelemetryEvent] = []
var _flushing := false
var _cancel_requested := false
var _stopped := false
var _auto_flush_timer: Timer = null
var _auto_flush_owner: Node = null
var _ack_generation := 0
var _ack_pending_generation := 0
var _counters := {
	"acknowledged_batches": 0,
	"callback_failures": 0,
	"callback_timeouts": 0,
	"dropped_oldest": 0,
	"dropped_newest": 0,
	"retry_attempts": 0,
	"serialization_failures": 0,
}

func _init() -> void:
	_flush_requested.connect(Callable(self, "flush"))

## Rejects invalid limits without replacing the active configuration.
func configure(config: TelemetryConfig) -> bool:
	if config == null or config.batch_size <= 0 or config.max_queue_events <= 0 or config.max_queue_events > MAX_QUEUE_EVENTS:
		return false
	if config.batch_size > config.max_queue_events or config.batch_interval_s <= 0.0 or event_count() > config.max_queue_events:
		return false
	if config.max_retries < 0 or config.max_retries > MAX_RETRIES or config.retry_initial_delay_s < 0.0 or config.retry_initial_delay_s > MAX_RETRY_INITIAL_DELAY_S:
		return false
	if config.retry_max_delay_s < config.retry_initial_delay_s or config.retry_max_delay_s > MAX_RETRY_DELAY_S or config.callback_timeout_s <= 0.0 or config.callback_timeout_s > MAX_CALLBACK_TIMEOUT_S:
		return false
	_config = config
	_stopped = false
	if _auto_flush_timer and is_instance_valid(_auto_flush_timer):
		_auto_flush_timer.wait_time = _config.batch_interval_s
		if _config.enabled:
			_auto_flush_timer.start()
		else:
			_auto_flush_timer.stop()
	return true

func is_enabled() -> bool:
	return _config.enabled

func build_event(timestamp_msec: int, level: String, context_id: String, subject_id: String, message: String, metadata: Dictionary) -> TelemetryEvent:
	return TelemetryEvent.new(timestamp_msec, level, context_id, subject_id, message, metadata)

## Queue capacity includes queued and in-flight events. In-flight data is immutable.
func add_event(event: TelemetryEvent) -> AddResult:
	if not _config.enabled or _stopped:
		return AddResult.DISABLED
	if event == null:
		return AddResult.INVALID_EVENT
	var result := AddResult.ADDED
	if event_count() >= _config.max_queue_events:
		if not _event_queue.is_empty():
			_event_queue.pop_front()
			_counters.dropped_oldest += 1
			result = AddResult.DROPPED_OLDEST_AND_ADDED
		else:
			_counters.dropped_newest += 1
			return AddResult.REJECTED_IN_FLIGHT_CAPACITY
	_event_queue.append(event)
	if should_flush() and _config.flush_callback.is_valid() and not _flushing:
		_flush_requested.emit()
	return result

func should_flush() -> bool:
	return _config.enabled and not _stopped and _event_queue.size() >= _config.batch_size

func event_count() -> int:
	return _event_queue.size() + _in_flight.size()

func queued_count() -> int:
	return _event_queue.size()

func in_flight_count() -> int:
	return _in_flight.size()

func counters() -> Dictionary:
	return _counters.duplicate(true)

## Explicit recovery for a permanently unserializable head event.
func discard_oldest_event() -> bool:
	if _event_queue.is_empty():
		return false
	_event_queue.pop_front()
	_counters.dropped_oldest += 1
	return true

## Flushes one FIFO batch. Only a true callback acknowledgement removes it.
func flush() -> FlushResult:
	if _flushing:
		return FlushResult.BUSY
	if not _config.enabled or _stopped:
		return FlushResult.DISABLED
	if _event_queue.is_empty():
		return FlushResult.EMPTY
	if not _config.flush_callback.is_valid():
		return FlushResult.INVALID_CALLBACK

	var take := mini(_config.batch_size, _event_queue.size())
	for index in range(take):
		_in_flight.append(_event_queue[index])
	_event_queue = _event_queue.slice(take)
	var serialized := _serialize_in_flight()
	if serialized.is_empty() and not _in_flight.is_empty():
		_restore_in_flight()
		_counters.serialization_failures += 1
		return FlushResult.SERIALIZATION_FAILED

	_flushing = true
	_cancel_requested = false
	for attempt in range(_config.max_retries + 1):
		if attempt > 0:
			_counters.retry_attempts += 1
			var delay := minf(_config.retry_initial_delay_s * pow(2.0, attempt - 1), _config.retry_max_delay_s)
			if delay > 0.0:
				await Engine.get_main_loop().create_timer(delay).timeout
		var acknowledged := await _call_with_timeout(serialized)
		if _cancel_requested:
			_restore_in_flight()
			_flushing = false
			flush_finished.emit(FlushResult.CANCELLED)
			return FlushResult.CANCELLED
		if acknowledged:
			_in_flight.clear()
			_flushing = false
			_counters.acknowledged_batches += 1
			flush_finished.emit(FlushResult.ACKNOWLEDGED)
			return FlushResult.ACKNOWLEDGED
		_counters.callback_failures += 1
	_restore_in_flight()
	_flushing = false
	flush_finished.emit(FlushResult.FAILED_AFTER_RETRIES)
	return FlushResult.FAILED_AFTER_RETRIES

func shutdown(flush_pending: bool = true) -> FlushResult:
	stop_auto_flush()
	if _flushing:
		call_deferred("cancel_pending_flush")
		var cancelled: FlushResult = await flush_finished
		_stopped = true
		return cancelled
	if flush_pending and _config.enabled and event_count() > 0:
		var result: FlushResult = await flush()
		_stopped = true
		return result
	_stopped = true
	return FlushResult.EMPTY

func cancel_pending_flush() -> bool:
	if not _flushing:
		return false
	_cancel_requested = true
	if _ack_pending_generation != 0:
		var generation := _ack_pending_generation
		_ack_pending_generation = 0
		_ack_completed.emit(generation, false)
	return true

func start_auto_flush(owner: Node) -> bool:
	if owner == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		return false
	stop_auto_flush()
	_stopped = false
	var timer := Timer.new()
	timer.name = "TelemetryAutoFlushTimer"
	timer.one_shot = false
	timer.wait_time = _config.batch_interval_s
	owner.add_child(timer)
	timer.timeout.connect(Callable(self, "_on_auto_flush_timeout"))
	owner.tree_exiting.connect(Callable(self, "_on_auto_flush_owner_exiting"), CONNECT_ONE_SHOT)
	_auto_flush_owner = owner
	_auto_flush_timer = timer
	if _config.enabled:
		timer.start()
	return true

func stop_auto_flush() -> void:
	if _auto_flush_owner and is_instance_valid(_auto_flush_owner) and _auto_flush_owner.tree_exiting.is_connected(Callable(self, "_on_auto_flush_owner_exiting")):
		_auto_flush_owner.tree_exiting.disconnect(Callable(self, "_on_auto_flush_owner_exiting"))
	if _auto_flush_timer and is_instance_valid(_auto_flush_timer):
		_auto_flush_timer.stop()
		_auto_flush_timer.queue_free()
	_auto_flush_timer = null
	_auto_flush_owner = null

func has_auto_flush_timer() -> bool:
	return _auto_flush_timer != null and is_instance_valid(_auto_flush_timer)

func to_dict(event: TelemetryEvent) -> Dictionary:
	if event == null:
		return {}
	var metadata := {}
	for key in event.metadata:
		metadata[str(key)] = event.metadata[key]
	return {"timestamp": event.timestamp_msec, "level": event.level, "context_id": event.context_id, "subject_id": event.subject_id, "message": event.message, "metadata": metadata}

func get_config() -> TelemetryConfig:
	return _config

func _serialize_in_flight() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for event in _in_flight:
		var item := to_dict(event)
		if not _is_json_compatible(item):
			return []
		output.append(item)
	return output

func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item in value:
				if not _is_json_compatible(item): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not key is String or not _is_json_compatible(value[key]): return false
			return true
		_:
			return false

func _restore_in_flight() -> void:
	var restored: Array[TelemetryEvent] = []
	restored.append_array(_in_flight)
	restored.append_array(_event_queue)
	_event_queue = restored
	_in_flight.clear()

func _call_with_timeout(batch: Array[Dictionary]) -> bool:
	var response: Variant = _config.flush_callback.call(batch.duplicate(true))
	if response is bool:
		return response
	if not response is Signal:
		return false
	_ack_generation += 1
	var generation := _ack_generation
	_ack_pending_generation = generation
	response.connect(Callable(self, "_on_async_ack").bind(generation), CONNECT_ONE_SHOT)
	Engine.get_main_loop().create_timer(_config.callback_timeout_s).timeout.connect(Callable(self, "_on_ack_timeout").bind(generation), CONNECT_ONE_SHOT)
	var resolved: Array = await _ack_completed
	if resolved[0] != generation:
		return false
	return resolved[1]

func _on_async_ack(value: Variant, generation: int) -> void:
	if generation == _ack_pending_generation:
		_ack_pending_generation = 0
		_ack_completed.emit(generation, value is bool and value)

func _on_ack_timeout(generation: int) -> void:
	if generation == _ack_pending_generation:
		_ack_pending_generation = 0
		_counters.callback_timeouts += 1
		_ack_completed.emit(generation, false)

func _on_auto_flush_timeout() -> void:
	if not _flushing:
		_flush_requested.emit()

func _on_auto_flush_owner_exiting() -> void:
	if _auto_flush_timer and is_instance_valid(_auto_flush_timer):
		_auto_flush_timer.stop()
	_auto_flush_timer = null
	_auto_flush_owner = null
