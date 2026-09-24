extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var packed: PackedScene = load("res://scenes/ship_management.tscn")
	if packed == null:
		print("Ship management smoke failed: missing scene")
		quit(1)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for index in range(10):
		await process_frame

	if scene.get("preview_ship") == null:
		errors.append("Preview ship did not instantiate.")
	if scene.get("module_list") == null:
		errors.append("Module list did not instantiate.")
	if scene.get("detail_label") == null:
		errors.append("Detail label did not instantiate.")

	if errors.is_empty():
		print("Ship management smoke test passed.")
		quit(0)
		return

	print("Ship management smoke test failed:")
	for error in errors:
		print("- %s" % error)
	quit(1)
