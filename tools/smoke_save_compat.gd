extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var save_path := ProjectSettings.globalize_path("user://savegame.json")
	var backup_path := "%s.smoke_backup" % save_path
	var had_save := FileAccess.file_exists(save_path)
	if had_save:
		DirAccess.copy_absolute(save_path, backup_path)

	var state_path_util := root.get_node("/root/StatePathUtil")
	var save_manager := root.get_node("/root/SaveManager")
	var player_state := root.get_node("/root/PlayerState")
	var ship_state := root.get_node("/root/ShipState")

	save_manager.reset_game()
	state_path_util.apply_change({
		"path": "player.resources.source_points",
		"operation": "add",
		"value": 11
	})
	state_path_util.apply_change({
		"path": "player.resources.iron",
		"operation": "add",
		"value": 7
	})
	ship_state.ship_data["fire_warship"]["module_levels"]["main_gun"] = 2
	if not save_manager.save_game():
		errors.append("SaveManager.save_game() returned false.")

	player_state.reset()
	ship_state.reset()
	if not save_manager.load_game():
		errors.append("SaveManager.load_game() returned false.")

	if int(player_state.state.get("resources", {}).get("source_points", 0)) < 16:
		errors.append("Source Points did not persist.")
	if int(player_state.state.get("resources", {}).get("iron", 0)) < 7:
		errors.append("Iron did not persist.")
	if int(ship_state.ship_data.get("fire_warship", {}).get("module_levels", {}).get("main_gun", 0)) != 2:
		errors.append("Fire Warship module level did not persist.")

	if errors.is_empty():
		print("Save compatibility smoke test passed.")
		_restore_save(save_path, backup_path, had_save)
		quit(0)
		return

	print("Save compatibility smoke test failed:")
	for error in errors:
		print("- %s" % error)
	_restore_save(save_path, backup_path, had_save)
	quit(1)


func _restore_save(save_path: String, backup_path: String, had_save: bool) -> void:
	if had_save and FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(backup_path, save_path)
		DirAccess.remove_absolute(backup_path)
	elif not had_save and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
