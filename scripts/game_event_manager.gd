extends Node

## Clean bridge between story/menus and reusable gameplay scenes.
## Chapters should call this layer conceptually, not manipulate combat internals.

const BATTLE_3D_SCENE := "res://scenes/combat/battle_3d.tscn"


func start_battle(config: Dictionary = {}) -> Dictionary:
	var payload := config.duplicate(true)
	if not payload.has("battle_config"):
		payload["battle_config"] = "prototype_fire_warship_trial"
	var scene: Node = await _singleton("UIManager").show_scene(BATTLE_3D_SCENE, payload)
	if scene == null:
		return {"result": "error", "error": "Could not load 3D battle scene."}
	if scene.has_signal("battle_finished"):
		var result: Variant = await scene.battle_finished
		if result is Dictionary:
			_apply_battle_result(result)
			return result
	return {"result": "error", "error": "3D battle did not return a Dictionary result."}


func launch_battle(config: Dictionary = {}) -> void:
	var result: Dictionary = await start_battle(config)
	await _singleton("UIManager").show_story_event({
		"kind": "narration",
		"title": "Battle Report",
		"text": _format_battle_report(result),
		"next": ""
	})
	await _singleton("UIManager").show_main_menu()


func start_alternate_space_test() -> void:
	_singleton("WorldState").state["alternate_space"]["current_expedition"] = {
		"battle_config": "prototype_fire_warship_trial",
		"started_at_day": _absolute_day()
	}
	await launch_battle({"battle_config": "prototype_fire_warship_trial", "alternate_space": true})


func skip_alternate_space_cooldown() -> void:
	_singleton("WorldState").state["alternate_space"]["last_entry_day"] = -9999
	_singleton("WorldState").state["alternate_space"]["available"] = true
	_singleton("SaveManager").save_game()


func advance_game_days(days: int) -> void:
	var calendar: Dictionary = _singleton("WorldState").state.get("calendar", {})
	calendar["day"] = int(calendar.get("day", 1)) + days
	while int(calendar.get("day", 1)) > 30:
		calendar["day"] = int(calendar["day"]) - 30
		calendar["month"] = int(calendar.get("month", 1)) + 1
	while int(calendar.get("month", 1)) > 12:
		calendar["month"] = int(calendar["month"]) - 12
		calendar["year"] = int(calendar.get("year", 10103)) + 1
	_singleton("WorldState").state["calendar"] = calendar
	_update_alternate_space_availability()
	_singleton("SaveManager").save_game()


func upgrade_fire_warship_module(module_id: String) -> Dictionary:
	var modules: Variant = _singleton("DataManager").load_data_file("fire_warship_modules.json", {})
	if not (modules is Dictionary) or not modules.has(module_id):
		return {"success": false, "error": "Unknown module: %s" % module_id}

	var module: Dictionary = modules[module_id]
	var fire_warship: Dictionary = _singleton("ShipState").ship_data.get("fire_warship", {})
	var levels: Dictionary = fire_warship.get("module_levels", {})
	var module_type: String = module.get("module_type", "")
	var current_level: int = int(levels.get(module_type, module.get("level", 1)))
	if current_level >= int(module.get("max_level", 1)):
		return {"success": false, "error": "Module is already at max level."}

	if not _can_afford_module(module):
		return {"success": false, "error": "Insufficient resources."}

	_spend_module_cost(module)
	levels[module_type] = current_level + 1
	fire_warship["module_levels"] = levels
	_singleton("ShipState").ship_data["fire_warship"] = fire_warship
	_apply_module_stats(module)
	_singleton("SaveManager").save_game()
	return {"success": true, "module": module_id, "level": current_level + 1}


func _apply_battle_result(result: Dictionary) -> void:
	_singleton("WorldState").state["last_battle_result"] = result.duplicate(true)
	var rewards: Dictionary = result.get("rewards", {})
	for resource_id in rewards.keys():
		_singleton("StatePathUtil").apply_change({
			"path": "player.resources.%s" % resource_id,
			"operation": "add",
			"value": rewards[resource_id]
		})

	var ship_damage: Dictionary = result.get("player_ship_state", {})
	for stat_id in ["hull", "armor", "shield"]:
		if ship_damage.has(stat_id):
			_singleton("ShipState").ship_data["stats"][stat_id] = ship_damage[stat_id]

	if result.get("alternate_space", false):
		_singleton("WorldState").state["alternate_space"]["last_entry_day"] = _absolute_day()
		_singleton("WorldState").state["alternate_space"]["available"] = false
		_singleton("WorldState").state["alternate_space"]["current_expedition"] = {}
	_singleton("SaveManager").save_game()


func _format_battle_report(result: Dictionary) -> String:
	var rewards: Dictionary = result.get("rewards", {})
	var reward_lines: Array[String] = []
	for resource_id in rewards.keys():
		reward_lines.append("%s: %s" % [resource_id.capitalize().replace("_", " "), rewards[resource_id]])
	return "Result: %s\nEnemies destroyed: %s\nDamage dealt: %s\nDamage received: %s\nRewards:\n%s" % [
		result.get("result", "unknown"),
		result.get("ships_destroyed", 0),
		result.get("damage_dealt", 0),
		result.get("damage_received", 0),
		"\n".join(reward_lines) if not reward_lines.is_empty() else "None"
	]


func _can_afford_module(module: Dictionary) -> bool:
	var resources: Dictionary = _singleton("PlayerState").state.get("resources", {})
	if int(resources.get("source_points", 0)) < int(module.get("source_point_cost", 0)):
		return false
	for resource_id in module.get("material_cost", {}).keys():
		if int(resources.get(resource_id, 0)) < int(module["material_cost"][resource_id]):
			return false
	return true


func _spend_module_cost(module: Dictionary) -> void:
	_singleton("StatePathUtil").apply_change({
		"path": "player.resources.source_points",
		"operation": "subtract",
		"value": int(module.get("source_point_cost", 0))
	})
	for resource_id in module.get("material_cost", {}).keys():
		_singleton("StatePathUtil").apply_change({
			"path": "player.resources.%s" % resource_id,
			"operation": "subtract",
			"value": int(module["material_cost"][resource_id])
		})


func _apply_module_stats(module: Dictionary) -> void:
	for stat_id in module.get("upgraded_stats", {}).keys():
		var value: Variant = module["upgraded_stats"][stat_id]
		if value is int or value is float:
			_singleton("ShipState").ship_data["stats"][stat_id] = value


func _update_alternate_space_availability() -> void:
	var alt: Dictionary = _singleton("WorldState").state.get("alternate_space", {})
	var days_since_entry: int = _absolute_day() - int(alt.get("last_entry_day", -9999))
	alt["available"] = days_since_entry >= int(alt.get("cooldown_days", 30))
	_singleton("WorldState").state["alternate_space"] = alt


func _absolute_day() -> int:
	var calendar: Dictionary = _singleton("WorldState").state.get("calendar", {})
	return int(calendar.get("year", 10103)) * 360 + int(calendar.get("month", 1)) * 30 + int(calendar.get("day", 1))


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
