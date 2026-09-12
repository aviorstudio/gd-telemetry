extends SceneTree
func _initialize() -> void:
	push_error("intentional gate control")
	print("TEST_REACHED:runtime_error_zero.gd")
	quit(0)
