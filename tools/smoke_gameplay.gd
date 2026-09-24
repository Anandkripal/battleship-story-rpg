extends SceneTree

## Headless mechanic smoke test. This instantiates gameplay scenes and calls
## start(params) with representative data so parser and setup errors surface.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests: Array[Dictionary] = [
		{
			"id": "scan",
			"scene": "res://mechanics/scan/scan.tscn",
			"params": {"target": "training_ship"}
		},
		{
			"id": "mining",
			"scene": "res://mechanics/mining/mining.tscn",
			"params": {"scans": 1}
		},
		{
			"id": "battle",
			"scene": "res://mechanics/battle/battle.tscn",
			"params": {"enemy": "training_drone"}
		},
		{
			"id": "exploration",
			"scene": "res://mechanics/exploration/exploration.tscn",
			"params": {
				"sector": "training_sector",
				"start_node": "training_planet",
				"objective_node": "asteroid_field"
			}
		},
		{
			"id": "loadout",
			"scene": "res://mechanics/loadout/loadout.tscn",
			"params": {
				"available_modules": [
					{"slot": "scanner", "module": "basic_scanner", "cost": {}}
				]
			}
		}
	]

	var errors: Array[String] = []
	for test in tests:
		var packed: PackedScene = load(test["scene"])
		if packed == null:
			errors.append("Missing scene for %s: %s" % [test["id"], test["scene"]])
			continue
		var instance: Node = packed.instantiate()
		root.add_child(instance)
		await process_frame
		if not instance.has_method("start"):
			errors.append("Mechanic %s has no start(params)." % test["id"])
		else:
			instance.start(test["params"])
			await process_frame
		instance.queue_free()
		await process_frame

	if errors.is_empty():
		print("Gameplay smoke test passed.")
		quit(0)
		return

	print("Gameplay smoke test failed:")
	for error in errors:
		print("- %s" % error)
	quit(1)
