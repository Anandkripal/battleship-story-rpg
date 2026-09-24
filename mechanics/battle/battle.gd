extends "res://mechanics/base_mechanic.gd"

var enemy_id := ""
var enemy: Dictionary = {}
var action_data: Dictionary = {}
var player_hull := 0
var enemy_hull := 0
var defending := false
var enemy_status: Label
var player_status: Label
var battle_log: Label
var actions_box: HBoxContainer


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var enemies: Variant = _singleton("DataManager").load_data_file("enemies.json", {})
	action_data = _singleton("DataManager").load_data_file("battle_actions.json", {})
	enemy_id = params.get("enemy", "training_drone")
	enemy = enemies.get(enemy_id, {}) if enemies is Dictionary else {}
	player_hull = int(_singleton("ShipState").ship_data.get("stats", {}).get("hull", 100))
	enemy_hull = int(enemy.get("stats", {}).get("hull", 50))
	_build_ui()
	_refresh()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.070, 0.030, 0.045)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 22)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(arena)

	arena.add_child(_build_ship_panel("Enemy Ship", true))
	arena.add_child(_build_ship_panel("Player Ship", false))

	battle_log = Label.new()
	battle_log.add_theme_font_size_override("font_size", 24)
	battle_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_log.custom_minimum_size = Vector2(0, 62)
	root.add_child(battle_log)

	actions_box = HBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 12)
	root.add_child(actions_box)


func _build_ship_panel(title_text: String, is_enemy: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	stack.add_child(title)

	var art := Label.new()
	art.text = "      /\\\n ____/  \\____\n<____________>\n    /____\\"
	art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art.add_theme_font_size_override("font_size", 30)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(art)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 26)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(status)

	if is_enemy:
		enemy_status = status
	else:
		player_status = status

	return panel


func _refresh(extra_log: String = "") -> void:
	enemy_status.text = "%s\nHull: %s  Armor: %s" % [
		enemy.get("name", "Enemy"),
		enemy_hull,
		enemy.get("stats", {}).get("armor", "-")
	]
	player_status.text = "%s\nHull: %s  Armor: %s" % [
		_singleton("ShipState").ship_data.get("name", "Player Ship"),
		player_hull,
		_singleton("ShipState").ship_data.get("stats", {}).get("armor", "-")
	]
	battle_log.text = extra_log

	for child in actions_box.get_children():
		child.queue_free()

	if enemy_hull <= 0:
		var victory := make_button("Claim Victory")
		victory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		victory.pressed.connect(_finish_victory)
		actions_box.add_child(victory)
		return

	if player_hull <= 0:
		var retry := make_button("Retry Battle")
		retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		retry.pressed.connect(_retry)
		actions_box.add_child(retry)
		return

	for action_id in _get_player_action_ids():
		var action: Dictionary = action_data.get(action_id, {})
		var button := make_button(action.get("name", action_id.capitalize()))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
