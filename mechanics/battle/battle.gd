extends "res://mechanics/base_mechanic.gd"

const PLAYER_ID := "player"
const ENEMY_ID := "enemy"

var enemy_id: String = ""
var enemy: Dictionary = {}
var action_data: Dictionary = {}
var module_data: Dictionary = {}
var loot_tables: Dictionary = {}
var player: Dictionary = {}
var enemies: Dictionary = {}
var selected_target_id: String = ENEMY_ID
var selected_weapon_id: String = ""
var cooldowns: Dictionary = {}
var enemy_cooldowns: Dictionary = {}
var enemy_ai_timer: float = 0.0
var ui_refresh_timer: float = 0.0
var battle_over: bool = false
var battle_result: String = ""
var obstacles: Array = []
var energy: Dictionary = {}
var arena: Control
var status_label: Label
var target_label: Label
var log_label: Label
var weapon_box: VBoxContainer
var energy_box: HBoxContainer
var end_box: HBoxContainer
var initialized: bool = false


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	initialized = false
	var enemies_data: Variant = _singleton("DataManager").load_data_file("enemies.json", {})
	var actions: Variant = _singleton("DataManager").load_data_file("battle_actions.json", {})
	var modules: Variant = _singleton("DataManager").load_data_file("modules.json", {})
	var loot: Variant = _singleton("DataManager").load_data_file("loot_tables.json", {})
	action_data = actions if actions is Dictionary else {}
	module_data = modules if modules is Dictionary else {}
	loot_tables = loot if loot is Dictionary else {}
	enemy_id = params.get("enemy", "training_drone")
	enemy = enemies_data.get(enemy_id, {}) if enemies_data is Dictionary else {}
	obstacles = params.get("obstacles", [
		{"id": "asteroid_a", "position": [620, 250], "radius": 42},
		{"id": "debris_b", "position": [480, 430], "radius": 30}
	])
	_setup_entities()
	_build_ui()
	initialized = true
	set_process(true)


func _process(delta: float) -> void:
	if not initialized or battle_over:
		return
	_tick_cooldowns(cooldowns, delta)
	_tick_cooldowns(enemy_cooldowns, delta)
	_move_entity(player, delta)
	_update_enemy_ai(delta)
	_check_end_state()
	ui_refresh_timer -= delta
	if ui_refresh_timer <= 0.0:
		ui_refresh_timer = 0.2
		_refresh()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not initialized or battle_over or arena == null:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var arena_origin: Vector2 = arena.global_position - global_position
	var arena_rect := Rect2(arena_origin, arena.size)
	if not arena_rect.has_point(mouse_event.position):
		return
	var local_position: Vector2 = mouse_event.position - arena_origin
	if local_position.distance_to(enemies[ENEMY_ID]["position"]) <= 46.0:
		selected_target_id = ENEMY_ID
		_log("Target locked: %s." % enemy.get("name", "Enemy"))
	else:
		player["destination"] = local_position
		_log("Move order set.")


func _draw() -> void:
	if not initialized or arena == null:
		return
	var offset: Vector2 = arena.global_position - global_position
	var rect := Rect2(offset, arena.size)
	draw_rect(rect, Color(0.010, 0.018, 0.030), true)
	draw_rect(rect, Color(0.16, 0.34, 0.48), false, 2.0)

	for obstacle in obstacles:
		if not (obstacle is Dictionary):
			continue
		var position_data: Array = obstacle.get("position", [0, 0])
		if position_data.size() < 2:
			continue
		var obstacle_position := Vector2(float(position_data[0]), float(position_data[1]))
		var radius := float(obstacle.get("radius", 28))
		draw_circle(offset + obstacle_position, radius, Color(0.25, 0.25, 0.30, 0.85))
		draw_arc(offset + obstacle_position, radius, 0.0, TAU, 32, Color(0.55, 0.58, 0.65), 2.0)

	_draw_ship(offset, player, Color(0.25, 0.72, 1.0), true)
	_draw_ship(offset, enemies[ENEMY_ID], Color(1.0, 0.25, 0.25), false)

	if not selected_weapon_id.is_empty():
		var action: Dictionary = _action(selected_weapon_id)
		draw_arc(offset + player["position"], float(action.get("range", 360)), 0.0, TAU, 64, Color(0.4, 0.75, 1.0, 0.22), 2.0)


func _setup_entities() -> void:
	var ship: Dictionary = _singleton("ShipState").ship_data
	var stats: Dictionary = ship.get("stats", {})
	player = {
		"id": PLAYER_ID,
		"name": ship.get("name", "Player Ship"),
		"position": Vector2(180, 360),
		"destination": Vector2(180, 360),
		"velocity": Vector2.ZERO,
		"hull": float(stats.get("hull", 100)),
		"hull_max": float(stats.get("hull_max", stats.get("hull", 100))),
		"armor": float(stats.get("armor", 0)),
		"armor_max": float(stats.get("armor_max", stats.get("armor", 0))),
		"shield": float(stats.get("shield", 0)),
		"shield_max": float(stats.get("shield_max", stats.get("shield", 0))),
		"max_speed": float(stats.get("engine_speed", 10)) * 16.0
	}

	var enemy_stats: Dictionary = enemy.get("stats", {})
	enemies[ENEMY_ID] = {
		"id": ENEMY_ID,
		"name": enemy.get("name", "Enemy"),
		"position": Vector2(900, 300),
		"destination": Vector2(900, 300),
		"velocity": Vector2.ZERO,
		"hull": float(enemy_stats.get("hull", 50)),
		"hull_max": float(enemy_stats.get("hull", 50)),
		"armor": float(enemy_stats.get("armor", 0)),
		"armor_max": float(enemy_stats.get("armor", 0)),
		"shield": float(enemy_stats.get("shield", 0)),
		"shield_max": float(enemy_stats.get("shield", 0)),
		"max_speed": float(enemy_stats.get("max_speed", 95))
	}

	var ship_stats: Dictionary = _singleton("ShipState").ship_data.get("stats", {})
	energy = {
		"engines": int(ship_stats.get("energy_engines", 30)),
		"shields": int(ship_stats.get("energy_shields", 20)),
		"weapons": int(ship_stats.get("energy_weapons", 50))
	}

	for weapon_id in _player_weapon_ids():
		cooldowns[weapon_id] = 0.0
	if selected_weapon_id.is_empty() and not _player_weapon_ids().is_empty():
		selected_weapon_id = _player_weapon_ids()[0]
	for weapon_id in _enemy_weapon_ids():
		enemy_cooldowns[weapon_id] = 1.0


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.025, 0.018, 0.030)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var arena_panel := PanelContainer.new()
	arena_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(arena_panel)

	arena = Control.new()
	arena.clip_contents = true
	arena.custom_minimum_size = Vector2(820, 620)
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_panel.add_child(arena)

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(390, 0)
	root.add_child(side_panel)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side_panel.add_child(side)

	var title := Label.new()
	title.text = "TACTICAL COMBAT"
	title.add_theme_font_size_override("font_size", 32)
	side.add_child(title)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(status_label)

	target_label = Label.new()
	target_label.add_theme_font_size_override("font_size", 21)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(target_label)

	energy_box = HBoxContainer.new()
	energy_box.add_theme_constant_override("separation", 6)
	side.add_child(energy_box)

	weapon_box = VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 8)
	side.add_child(weapon_box)

	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 20)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(log_label)

	end_box = HBoxContainer.new()
	end_box.add_theme_constant_override("separation", 8)
	side.add_child(end_box)
	_log("Click space to move. Select a weapon when target is in range.")
	_refresh()


func _refresh() -> void:
	if status_label == null:
		return
	status_label.text = "PLAYER\nHull %.0f/%.0f  Armor %.0f  Shield %.0f\nEnergy: E%s S%s W%s" % [
		player.get("hull", 0.0),
		player.get("hull_max", 0.0),
		player.get("armor", 0.0),
		player.get("shield", 0.0),
		energy.get("engines", 0),
		energy.get("shields", 0),
		energy.get("weapons", 0)
	]

	var target: Dictionary = enemies.get(selected_target_id, enemies[ENEMY_ID])
	var distance: float = player["position"].distance_to(target["position"])
	target_label.text = "TARGET\n%s\nRange: %.0f\nHull %.0f/%.0f  Armor %.0f  Shield %.0f" % [
		target.get("name", "Enemy"),
		distance,
		target.get("hull", 0.0),
		target.get("hull_max", 0.0),
		target.get("armor", 0.0),
		target.get("shield", 0.0)
	]

	_rebuild_energy_controls()
	_rebuild_weapon_controls()
	_rebuild_end_controls()


func _rebuild_energy_controls() -> void:
	for child in energy_box.get_children():
		child.queue_free()
	for channel in ["engines", "shields", "weapons"]:
		var button := Button.new()
		button.text = "%s\n%s" % [channel.substr(0, 1).to_upper(), energy[channel]]
		button.custom_minimum_size = Vector2(72, 54)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void: _cycle_energy(channel))
		energy_box.add_child(button)


func _rebuild_weapon_controls() -> void:
	for child in weapon_box.get_children():
		child.queue_free()
	for weapon_id in _player_weapon_ids():
		var action: Dictionary = _action(weapon_id)
		var button := make_button(_weapon_label(weapon_id, action))
		button.disabled = not _can_fire(weapon_id, action)
		button.pressed.connect(func() -> void: _fire_player_weapon(weapon_id))
		weapon_box.add_child(button)


func _rebuild_end_controls() -> void:
	for child in end_box.get_children():
		child.queue_free()
	if not battle_over:
		return
	if battle_result == "victory":
		var claim := make_button("Salvage Victory")
		claim.pressed.connect(_finish_victory)
		end_box.add_child(claim)
	else:
		var retry := make_button("Emergency Reset")
		retry.pressed.connect(_retry)
		end_box.add_child(retry)


func _cycle_energy(channel: String) -> void:
	var channels := ["engines", "shields", "weapons"]
	var donor := ""
	for candidate in channels:
		if candidate != channel and int(energy[candidate]) >= 10:
			donor = candidate
			break
	if donor.is_empty():
		return
	energy[channel] = int(energy[channel]) + 10
	energy[donor] = int(energy[donor]) - 10
	_sync_energy_to_ship()
	_log("Energy shifted to %s." % channel)
	_refresh()


func _fire_player_weapon(weapon_id: String) -> void:
	var action: Dictionary = _action(weapon_id)
	if not _can_fire(weapon_id, action):
		return
	selected_weapon_id = weapon_id
	var target: Dictionary = enemies[selected_target_id]
	var damage: float = float(action.get("damage", 0)) * (0.75 + float(energy.get("weapons", 50)) / 100.0)
	_apply_damage(target, damage)
	cooldowns[weapon_id] = float(action.get("cooldown", 3.0))
	_log("%s hits for %.0f damage." % [action.get("name", weapon_id), damage])
	_check_end_state()
	_refresh()


func _update_enemy_ai(delta: float) -> void:
	enemy_ai_timer -= delta
	var enemy_ship: Dictionary = enemies[ENEMY_ID]
	var distance: float = enemy_ship["position"].distance_to(player["position"])
	var profile: String = enemy.get("ai_profile", "aggressive")
	var preferred_range: float = _enemy_preferred_range()

	if profile == "cowardly" and float(enemy_ship.get("hull", 0.0)) < float(enemy_ship.get("hull_max", 1.0)) * 0.35:
		var away: Vector2 = (enemy_ship["position"] - player["position"]).normalized()
		enemy_ship["destination"] = enemy_ship["position"] + away * 180.0
	elif distance > preferred_range:
		enemy_ship["destination"] = player["position"] + (enemy_ship["position"] - player["position"]).normalized() * preferred_range
	elif profile == "skirmisher" or profile == "missile_boat":
		enemy_ship["destination"] = player["position"] + (enemy_ship["position"] - player["position"]).normalized() * preferred_range
	else:
		enemy_ship["destination"] = enemy_ship["position"]

	_move_entity(enemy_ship, delta)
	if enemy_ai_timer > 0.0:
		return
	enemy_ai_timer = 0.35
	for weapon_id in _enemy_weapon_ids():
		var action: Dictionary = _action(weapon_id)
		var in_range: bool = distance <= float(action.get("range", 360))
		var ready: bool = float(enemy_cooldowns.get(weapon_id, 0.0)) <= 0.0
		if in_range and ready:
			var damage: float = float(action.get("damage", 0)) * 0.85
			_apply_damage(player, damage)
			enemy_cooldowns[weapon_id] = float(action.get("cooldown", 4.0))
			_log("%s fires %s for %.0f damage." % [enemy.get("name", "Enemy"), action.get("name", weapon_id), damage])
			return


func _move_entity(entity: Dictionary, delta: float) -> void:
	var position: Vector2 = entity["position"]
	var destination: Vector2 = entity.get("destination", position)
	var distance: float = position.distance_to(destination)
	if distance < 4.0:
		entity["velocity"] = Vector2.ZERO
		return
	var direction: Vector2 = (destination - position).normalized()
	var speed_multiplier: float = 1.0
	if entity.get("id", "") == PLAYER_ID:
		speed_multiplier = 0.65 + float(energy.get("engines", 30)) / 70.0
	entity["velocity"] = direction * float(entity.get("max_speed", 120.0)) * speed_multiplier
	entity["position"] = position + entity["velocity"] * delta
	entity["position"] = _clamp_to_arena(entity["position"])


func _apply_damage(entity: Dictionary, damage: float) -> void:
	var remaining: float = damage
	var shield: float = float(entity.get("shield", 0.0))
	if shield > 0.0:
		var absorbed: float = min(shield, remaining)
		entity["shield"] = shield - absorbed
		remaining -= absorbed
	var armor: float = float(entity.get("armor", 0.0))
	if remaining > 0.0 and armor > 0.0:
		var armor_absorbed: float = min(armor, remaining * 0.65)
		entity["armor"] = armor - armor_absorbed
		remaining -= armor_absorbed
	if remaining > 0.0:
		entity["hull"] = max(0.0, float(entity.get("hull", 0.0)) - remaining)


func _check_end_state() -> void:
	if battle_over:
		return
	if float(enemies[ENEMY_ID].get("hull", 0.0)) <= 0.0:
		battle_over = true
		battle_result = "victory"
		_log("Enemy disabled. Salvage teams can move in.")
	if float(player.get("hull", 0.0)) <= 0.0:
		battle_over = true
		battle_result = "defeat"
		_log("Hull failure. Use emergency reset to retry this prototype encounter.")


func _finish_victory() -> void:
	_sync_energy_to_ship()
	_singleton("ShipState").ship_data["stats"]["hull"] = max(1, int(player.get("hull", 1.0)))
	_singleton("ShipState").ship_data["stats"]["armor"] = max(0, int(player.get("armor", 0.0)))
	_singleton("ShipState").ship_data["stats"]["shield"] = max(0, int(player.get("shield", 0.0)))
	var rewards: Dictionary = _battle_rewards()
	finish({
		"success": true,
		"battle_result": "victory",
		"enemy": enemy_id,
		"resources_found": rewards,
		"changes": [
			{
				"path": "world.flags.defeated_%s" % enemy_id,
				"operation": "set",
				"value": true
			},
			{
				"path": "world.flags.salvaged_%s" % enemy_id,
				"operation": "set",
				"value": true
			}
		]
	})


func _retry() -> void:
	for child in get_children():
		child.queue_free()
	cooldowns.clear()
	enemy_cooldowns.clear()
	battle_over = false
	battle_result = ""
	_setup_entities()
	_build_ui()


func _battle_rewards() -> Dictionary:
	var rewards: Dictionary = {}
	var reward_data: Dictionary = enemy.get("rewards", {})
	for resource_id in reward_data.get("resources", {}).keys():
		rewards[resource_id] = int(rewards.get(resource_id, 0)) + int(reward_data["resources"][resource_id])
	var loot_table_id: String = reward_data.get("loot_table", "")
	var loot_table: Dictionary = loot_tables.get(loot_table_id, {})
	for resource_id in loot_table.get("drops", {}).keys():
		rewards[resource_id] = int(rewards.get(resource_id, 0)) + int(loot_table["drops"][resource_id])
	return rewards


func _can_fire(weapon_id: String, action: Dictionary) -> bool:
	var target: Dictionary = enemies.get(selected_target_id, {})
	if target.is_empty():
		return false
	var distance: float = player["position"].distance_to(target["position"])
	var has_energy: bool = int(energy.get("weapons", 0)) >= int(action.get("energy_cost", 0))
	return distance <= float(action.get("range", 360)) and float(cooldowns.get(weapon_id, 0.0)) <= 0.0 and has_energy


func _weapon_label(weapon_id: String, action: Dictionary) -> String:
	var distance: float = player["position"].distance_to(enemies[selected_target_id]["position"])
	return "%s\nR%.0f / %.0f  CD %.1f" % [
		action.get("name", weapon_id.capitalize()),
		distance,
		float(action.get("range", 360)),
		float(cooldowns.get(weapon_id, 0.0))
	]


func _player_weapon_ids() -> Array:
	var ids: Array = []
	for ability in _singleton("ShipState").ship_data.get("abilities", []):
		if action_data.has(ability) and not ids.has(ability):
			ids.append(ability)
	for module in _singleton("ShipState").ship_data.get("modules", {}).values():
		if module is Dictionary and module.has("action") and not ids.has(module["action"]):
			ids.append(module["action"])
		var module_id: String = module.get("id", "") if module is Dictionary else ""
		var definition: Dictionary = module_data.get(module_id, {})
		if definition.has("action") and not ids.has(definition["action"]):
			ids.append(definition["action"])
	return ids


func _enemy_weapon_ids() -> Array:
	var ids: Array = enemy.get("weapons", [])
	if ids.is_empty():
		ids = ["main_cannon"]
	return ids


func _enemy_preferred_range() -> float:
	var preferred: float = 340.0
	for weapon_id in _enemy_weapon_ids():
		var action: Dictionary = _action(weapon_id)
		preferred = max(preferred, float(action.get("range", 360)) * 0.8)
	return preferred


func _action(action_id: String) -> Dictionary:
	if action_data.has(action_id):
		return action_data[action_id]
	for module_id in module_data.keys():
		var definition: Dictionary = module_data[module_id]
		if definition.get("action", "") == action_id:
			var action: Dictionary = definition.get("stats", {}).duplicate(true)
			action["name"] = definition.get("name", action_id.capitalize())
			action["type"] = "attack"
			return action
	return {
		"name": action_id.capitalize(),
		"type": "attack",
		"damage": 10,
		"range": 320,
		"cooldown": 4.0,
		"energy_cost": 10
	}


func _tick_cooldowns(target_cooldowns: Dictionary, delta: float) -> void:
	for key in target_cooldowns.keys():
		target_cooldowns[key] = max(0.0, float(target_cooldowns[key]) - delta)


func _draw_ship(offset: Vector2, entity: Dictionary, color: Color, points_up: bool) -> void:
	var position: Vector2 = offset + entity["position"]
	var points: PackedVector2Array
	if points_up:
		points = PackedVector2Array([position + Vector2(0, -28), position + Vector2(-24, 24), position + Vector2(24, 24)])
	else:
		points = PackedVector2Array([position + Vector2(0, 28), position + Vector2(-24, -24), position + Vector2(24, -24)])
	draw_colored_polygon(points, color)
	draw_arc(position, 34.0, 0.0, TAU, 28, Color(1, 1, 1, 0.42), 2.0)


func _clamp_to_arena(position: Vector2) -> Vector2:
	if arena == null:
		return position
	return Vector2(
		clamp(position.x, 40.0, max(40.0, arena.size.x - 40.0)),
		clamp(position.y, 40.0, max(40.0, arena.size.y - 40.0))
	)


func _sync_energy_to_ship() -> void:
	_singleton("ShipState").ship_data["stats"]["energy_engines"] = energy.get("engines", 30)
	_singleton("ShipState").ship_data["stats"]["energy_shields"] = energy.get("shields", 20)
	_singleton("ShipState").ship_data["stats"]["energy_weapons"] = energy.get("weapons", 50)


func _log(message: String) -> void:
	if log_label != null:
		log_label.text = message


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
