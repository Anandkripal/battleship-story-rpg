extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var start_msec: int = Time.get_ticks_msec()
	var packed: PackedScene = load("res://scenes/combat/battle_3d.tscn")
	if packed == null:
		print("3D battle performance smoke failed: missing battle scene")
		quit(1)
		return

	var battle: Node = packed.instantiate()
	root.add_child(battle)
	battle.setup({"battle_config": "prototype_performance_swarm"})
	await process_frame
	for index in range(180):
		await process_frame

	if battle.get("enemy_ships").size() < 10:
		errors.append("Expected 10 enemy ships in performance smoke.")
	if battle.get("player_ships").is_empty():
		errors.append("No player ship spawned.")
	var elapsed_msec: int = Time.get_ticks_msec() - start_msec
	if elapsed_msec > 6500:
		errors.append("Performance smoke exceeded 6.5 seconds headless runtime: %sms." % elapsed_msec)

	if errors.is_empty():
		print("3D battle performance smoke passed in %sms." % elapsed_msec)
		quit(0)
		return

	print("3D battle performance smoke failed:")
	for error in errors:
		print("- %s" % error)
	quit(1)
