class_name TelemetryModule
extends RefCounted

class TelemetryConfig extends RefCounted:
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

func configure(config: TelemetryConfig) -> void:
	_config = config if config else TelemetryConfig.new()

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
		var serialized_batch: Array[Dictionary] = drain_serialized_batch()
		_config.flush_callback.call(serialized_batch)

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

