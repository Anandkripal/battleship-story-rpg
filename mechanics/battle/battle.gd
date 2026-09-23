extends "res://mechanics/base_mechanic.gd"

var enemy_id := ""
var enemy: Dictionary = {}
var action_data: Dictionary = {}
var player_hull := 0
var enemy_hull := 0
var defending := false
var status_label: Label
var actions_box: VBoxContainer


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var enemies: Variant = _singleton("DataManager").load_json("res://data/enemies.json", {})
	action_data = _singleton("DataManager").load_json("res://data/battle_actions.json", {})
	enemy_id = params.get("enemy", "training_drone")
	enemy = enemies.get(enemy_id, {}) if enemies is Dictionary else {}
	player_hull = int(_singleton("ShipState").ship_data.get("stats", {}).get("hull", 100))
	enemy_hull = int(enemy.get("stats", {}).get("hull", 50))
	_build_ui()
	_refresh()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.08, 0.04, 0.06)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Ship Battle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	actions_box = VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 10)
	layout.add_child(actions_box)


func _refresh(extra_log: String = "") -> void:
	status_label.text = "Player Hull: %s\n%s Hull: %s\n%s" % [
		player_hull,
		enemy.get("name", "Enemy"),
		enemy_hull,
		extra_log
	]

	for child in actions_box.get_children():
		child.queue_free()

	if enemy_hull <= 0:
		var victory := make_button("Claim Victory")
		victory.pressed.connect(_finish_victory)
		actions_box.add_child(victory)
		return

	if player_hull <= 0:
		var retry := make_button("Retry Battle")
		retry.pressed.connect(_retry)
		actions_box.add_child(retry)
		return

	for action_id in _get_player_action_ids():
		var action: Dictionary = action_data.get(action_id, {})
		var button := make_button(action.get("name", action_id.capitalize()))
		button.pressed.connect(func() -> void: _use_action(action_id))
		actions_box.add_child(button)


func _get_player_action_ids() -> Array:
	var ids: Array = []
	for ability in _singleton("ShipState").ship_data.get("abilities", []):
		if not ids.has(ability):
			ids.append(ability)

	for module in _singleton("ShipState").ship_data.get("modules", {}).values():
		if module is Dictionary and module.has("action") and not ids.has(module["action"]):
			ids.append(module["action"])

	return ids


func _use_action(action_id: String) -> void:
	var action: Dictionary = action_data.get(action_id, {})
	defending = false

	if action.get("type", "attack") == "defense":
		defending = true
		_enemy_turn("%s braces for impact." % _singleton("ShipState").ship_data.get("name", "The ship"))
		return

	var damage := int(action.get("damage", 0))
	enemy_hull = max(0, enemy_hull - damage)
	if enemy_hull <= 0:
		_refresh("%s hits for %s damage." % [action.get("name", action_id), damage])
	else:
		_enemy_turn("%s hits for %s damage." % [action.get("name", action_id), damage])


func _enemy_turn(log: String) -> void:
	var enemy_attack: Dictionary = enemy.get("attack", {"name": "Training Pulse", "damage": 8})
	var damage := int(enemy_attack.get("damage", 0))
	if defending:
		damage = int(ceil(float(damage) * 0.35))
	player_hull = max(0, player_hull - damage)
	_singleton("ShipState").ship_data["stats"]["hull"] = player_hull
	_refresh("%s\n%s deals %s damage." % [log, enemy_attack.get("name", "Enemy attack"), damage])


func _retry() -> void:
	player_hull = int(_singleton("ShipState").ship_data.get("stats", {}).get("hull_max", 100))
	enemy_hull = int(enemy.get("stats", {}).get("hull", 50))
	_singleton("ShipState").ship_data["stats"]["hull"] = player_hull
	_refresh("Systems restored for a training retry.")


func _finish_victory() -> void:
	var rewards: Dictionary = enemy.get("rewards", {})
	_singleton("ShipState").ship_data["stats"]["hull"] = max(player_hull, 1)
	finish({
		"success": true,
		"resources_found": rewards.get("resources", {}),
		"changes": [
			{
				"path": "world.flags.defeated_%s" % enemy_id,
				"operation": "set",
				"value": true
			}
		]
	})


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
