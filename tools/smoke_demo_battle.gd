extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var packed: PackedScene = load("res://scenes/combat/battle_3d.tscn")
	if packed == null:
		print("Demo battle smoke failed: missing battle scene")
		quit(1)
		return

	var battle: Node = packed.instantiate()
	root.add_child(battle)
	battle.setup({"battle_config": "demo_visible_battle"})
	for index in range(20):
		await process_frame

	if battle.get("player_ships").is_empty():
		errors.append("No player ship spawned.")
	if battle.get("enemy_ships").size() < 3:
		errors.append("Expected at least 3 demo enemies.")
	if battle.get("target_ship") == null:
		errors.append("Demo did not auto-select an enemy target.")
	if battle.get("camera_distance") > 7000.0:
		errors.append("Demo camera starts too far away.")
	if battle.get("intro_active"):
		errors.append("Demo battle should skip the cinematic intro.")

	var camera: Camera3D = battle.get("camera")
	var selected_ship: Variant = battle.get("selected_ship")
	var target_ship: Variant = battle.get("target_ship")
	if camera != null and selected_ship != null and target_ship != null:
		if not camera.is_position_in_frustum(selected_ship.global_position):
			errors.append("Player ship is outside the opening camera frustum.")
		if not camera.is_position_in_frustum(target_ship.global_position):
			errors.append("Selected target is outside the opening camera frustum.")

	if errors.is_empty():
		print("Demo battle smoke test passed.")
		quit(0)
		return

	print("Demo battle smoke test failed:")
	for error in errors:
		print("- %s" % error)
	quit(1)
