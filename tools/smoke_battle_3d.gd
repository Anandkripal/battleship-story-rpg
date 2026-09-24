extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var packed: PackedScene = load("res://scenes/combat/battle_3d.tscn")
	if packed == null:
		print("3D battle smoke failed: missing battle scene")
		quit(1)
		return

	var battle: Node = packed.instantiate()
	root.add_child(battle)
	await process_frame
	if not battle.has_method("setup"):
		errors.append("Battle scene has no setup(payload).")
	else:
		battle.setup({"battle_config": "prototype_fire_warship_trial"})
		for index in range(12):
			await process_frame
		if battle.get("player_ships").is_empty():
			errors.append("No player ships spawned.")
		if battle.get("enemy_ships").size() < 3:
			errors.append("Expected at least 3 enemy ships.")
		if battle.get("selected_ship") == null:
			errors.append("No selected player ship.")
		if battle.get("enemy_ships").size() > 0:
			var enemy: Variant = battle.get("enemy_ships")[0]
			battle.set("target_ship", enemy)
			if battle.has_method("_fire_selected_weapon"):
				battle.call("_fire_selected_weapon", 0)
				await process_frame
		if battle.has_signal("battle_finished"):
			battle.call("_finish_battle", "retreat")
			await process_frame
			var result: Variant = battle.get("result")
			if not (result is Dictionary):
				errors.append("Battle result was not a Dictionary.")
			elif result.get("result", "") != "retreat":
				errors.append("Retreat result was not returned.")

	if errors.is_empty():
		print("3D battle smoke test passed.")
		quit(0)
		return

	print("3D battle smoke test failed:")
	for error in errors:
		print("- %s" % error)
	quit(1)
