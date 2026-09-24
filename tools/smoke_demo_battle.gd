extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var start_msec: int = Time.get_ticks_msec()
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
	if battle.get("target_box") == null:
		errors.append("Demo battle did not build a target button list.")
	elif battle.get("target_box").get_child_count() < 4:
		errors.append("Expected target title plus 3 enemy target buttons.")
	if battle.get("command_box") == null:
		errors.append("Demo battle did not build command grid.")
	elif battle.get("command_box").get_child_count() < 8:
		errors.append("Expected all command buttons in compact command grid.")
	if _count_loaded_optional_models(battle) > 0:
		errors.append("Demo battle loaded optional model assets instead of fast fallback visuals.")
	if _count_nodes_of_type(battle, "GPUParticles3D") > 0:
		errors.append("Demo battle spawned engine particle nodes in performance mode.")

	var camera: Camera3D = battle.get("camera")
	var selected_ship: Variant = battle.get("selected_ship")
	var target_ship: Variant = battle.get("target_ship")
	if camera != null and selected_ship != null and target_ship != null:
		if not camera.is_position_in_frustum(selected_ship.global_position):
			errors.append("Player ship is outside the opening camera frustum.")
		if not camera.is_position_in_frustum(target_ship.global_position):
			errors.append("Selected target is outside the opening camera frustum.")
	var hud_width: float = _largest_control_right_edge(battle)
	if hud_width > 1280.0:
		errors.append("HUD extends beyond 1280px viewport: %.1f." % hud_width)

	var elapsed_msec: int = Time.get_ticks_msec() - start_msec
	if elapsed_msec > 3000:
		errors.append("Demo battle startup took too long: %sms." % elapsed_msec)

	if errors.is_empty():
		print("Demo battle smoke test passed in %sms." % elapsed_msec)
		quit(0)
		return

	print("Demo battle smoke test failed:")
	for error in errors:
		print("- %s" % error)
	quit(1)


func _count_loaded_optional_models(node: Node) -> int:
	var count := 0
	var value: Variant = node.get("model_loaded")
	if value is bool and value:
		count += 1
	for child in node.get_children():
		count += _count_loaded_optional_models(child)
	return count


func _count_nodes_of_type(node: Node, type_name: String) -> int:
	var count := 0
	if node.get_class() == type_name:
		count += 1
	for child in node.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _largest_control_right_edge(node: Node) -> float:
	var value := 0.0
	if node is Control:
		var control := node as Control
		value = max(value, control.global_position.x + control.size.x)
	for child in node.get_children():
		value = max(value, _largest_control_right_edge(child))
	return value
