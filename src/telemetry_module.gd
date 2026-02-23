class_name TelemetryModule
extends RefCounted
## Telemetry batching module with configurable flush behavior.

class TelemetryConfig extends RefCounted:
## Telemetry runtime configuration.
	var enabled: bool
	var batch_size: int
	var batch_interval_s: float
	var max_debug_messages: int
	var flush_callback: Callable

	func _init(
		enabled: bool = false,
		batch_size: int = 50,
		batch_interval_s: float = 0.5,
		max_debug_messages: int = 50,
		flush_callback: Callable = Callable()
	) -> void:
		self.enabled = enabled
		self.batch_size = batch_size
		self.batch_interval_s = batch_interval_s
		self.max_debug_messages = max_debug_messages
		self.flush_callback = flush_callback

class TelemetryEvent extends RefCounted:
## Typed telemetry event payload.
	var timestamp_msec: int
	var level: String
	var match_id: String
	var player_id: String
	var message: String
	var metadata: Dictionary

	func _init(
		timestamp_msec: int = 0,
		level: String = "",
		match_id: String = "",
		player_id: String = "",
		message: String = "",
		metadata: Dictionary = {}
	) -> void:
		self.timestamp_msec = timestamp_msec
		self.level = level
		self.match_id = match_id
		self.player_id = player_id
		self.message = message
		self.metadata = metadata.duplicate(true)

var _config: TelemetryConfig = TelemetryConfig.new()
var _event_batch: Array[TelemetryEvent] = []
var _auto_flush_timer: Timer = null

func configure(config: TelemetryConfig) -> void:
	_config = config if config else TelemetryConfig.new()
	if _auto_flush_timer and is_instance_valid(_auto_flush_timer):
		_auto_flush_timer.wait_time = maxf(_config.batch_interval_s, 0.01)

func is_enabled() -> bool:
	return _config.enabled

func create_event(
	timestamp_msec: int,
	level: String,
	match_id: String,
	player_id: String,
	message: String,
	metadata: Dictionary
) -> TelemetryEvent:
	return TelemetryEvent.new(timestamp_msec, level, match_id, player_id, message, metadata)

func add_event(event: TelemetryEvent) -> void:
	if not _config.enabled or event == null:
		return
	_event_batch.append(event)
	if should_flush() and _config.flush_callback.is_valid():
		flush()

func should_flush() -> bool:
	if not _config.enabled:
		return false
	if _config.batch_size <= 0:
		return false
	return _event_batch.size() >= _config.batch_size

func drain_serialized_batch() -> Array[Dictionary]:
	if not _config.enabled or _event_batch.is_empty():
		_event_batch.clear()
		return []

	var serialized_events: Array[Dictionary] = []
	for event in _event_batch:
		serialized_events.append(to_dict(event))

	_event_batch.clear()
	return serialized_events

func flush() -> void:
	if not _config.enabled:
		return
	if not _config.flush_callback.is_valid():
		return
	var serialized_batch: Array[Dictionary] = drain_serialized_batch()
	if serialized_batch.is_empty():
		return
	_config.flush_callback.call(serialized_batch)

func start_auto_flush(owner: Node) -> void:
	if owner == null:
		return
	stop_auto_flush()
	var timer := Timer.new()
	timer.name = "TelemetryAutoFlushTimer"
	timer.one_shot = false
	timer.autostart = true
	timer.wait_time = maxf(_config.batch_interval_s, 0.01)
	owner.add_child(timer)
	timer.timeout.connect(Callable(self, "_on_auto_flush_timeout"))
	_auto_flush_timer = timer

func stop_auto_flush() -> void:
	if _auto_flush_timer and is_instance_valid(_auto_flush_timer):
		_auto_flush_timer.stop()
		_auto_flush_timer.queue_free()
	_auto_flush_timer = null

func _on_auto_flush_timeout() -> void:
	flush()

func to_dict(event: TelemetryEvent) -> Dictionary:
	if event == null:
		return {}
	var serialized_metadata: Dictionary = {}
	if event.metadata is Dictionary:
		for key in event.metadata.keys():
			serialized_metadata[str(key)] = event.metadata[key]

	return {
		"timestamp": event.timestamp_msec,
		"level": event.level,
		"match_id": event.match_id,
		"player_id": event.player_id,
		"message": event.message,
		"metadata": serialized_metadata
	}

func get_config() -> TelemetryConfig:
	return _config

