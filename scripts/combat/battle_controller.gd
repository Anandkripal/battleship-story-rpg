extends Node3D

signal battle_finished(result: Dictionary)

const SHIP_SCENE := "res://scenes/combat/ship_3d.tscn"
const PROJECTILE_SCENE := "res://scenes/combat/projectile_3d.tscn"
const MISSILE_SCENE := "res://scenes/combat/missile_3d.tscn"
const EXPLOSION_SCENE := "res://scenes/combat/explosion_3d.tscn"
const TARGETING := preload("res://scripts/combat/targeting_system.gd")
const WEAPONS := preload("res://scripts/combat/weapon_system.gd")
const AI := preload("res://scripts/combat/combat_ai.gd")

var config: Dictionary = {}
var payload: Dictionary = {}
var ship_definitions: Dictionary = {}
var weapon_definitions: Dictionary = {}
var module_definitions: Dictionary = {}
var player_ships: Array = []
var enemy_ships: Array = []
var selected_ship: Variant
var target_ship: Variant
var camera: Camera3D
var camera_target := Vector3.ZERO
var camera_yaw := 0.0
var camera_pitch := -0.55
var camera_distance := 920.0
var follow_selected := true
var rotating_camera := false
var panning_camera := false
var last_mouse_position := Vector2.ZERO
var hud_layer: CanvasLayer
var player_label: Label
var target_label: Label
var log_label: Label
var weapon_box: VBoxContainer
var command_box: HBoxContainer
var result: Dictionary = {}
var battle_started := false
var battle_ended := false
var ai_timer := 0.0
var hud_timer := 0.0
var special_cooldowns: Dictionary = {}


func _ready() -> void:
	call_deferred("_start_default_if_needed")


func setup(new_payload: Dictionary = {}) -> void:
	payload = new_payload.duplicate(true)
	_start_battle()


func _process(delta: float) -> void:
	if not battle_started or battle_ended:
		return
	_tick_ships(delta)
	_tick_ai(delta)
	_update_camera(delta)
	_try_enemy_fire()
	_check_battle_end()
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.16
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not battle_started or battle_ended:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			rotating_camera = mouse_event.pressed
			last_mouse_position = mouse_event.position
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			panning_camera = mouse_event.pressed
			last_mouse_position = mouse_event.position
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			camera_distance = max(180.0, camera_distance * 0.88)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			camera_distance = min(2600.0, camera_distance * 1.12)
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_left_click(mouse_event.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if rotating_camera:
			camera_yaw -= motion.relative.x * 0.006
			camera_pitch = clamp(camera_pitch - motion.relative.y * 0.004, -1.25, -0.12)
		elif panning_camera:
			var right := camera.global_transform.basis.x
			var forward := -camera.global_transform.basis.z
			forward.y = 0
			camera_target += (-right * motion.relative.x + -forward.normalized() * motion.relative.y) * camera_distance * 0.001
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_reset_camera()
			KEY_F:
				follow_selected = not follow_selected
			KEY_ESCAPE:
				_finish_battle("retreat")


func _start_default_if_needed() -> void:
	if not battle_started:
		payload = {"battle_config": "prototype_fire_warship_trial"}
		_start_battle()


func _start_battle() -> void:
	if battle_started:
		return
	battle_started = true
	ship_definitions = _load_data("ship_definitions.json")
	weapon_definitions = _load_data("weapon_definitions.json")
	module_definitions = _load_data("fire_warship_modules.json")
	var configs := _load_data("battle_3d_configs.json")
	config = configs.get(payload.get("battle_config", "prototype_fire_warship_trial"), {})
	_build_world()
	_spawn_fleet(config.get("player_fleet", {}), player_ships)
	_spawn_fleet(config.get("enemy_fleet", {}), enemy_ships)
	if not player_ships.is_empty():
		selected_ship = player_ships[0]
		selected_ship.set_selected(true)
		camera_target = selected_ship.global_position
	result = {
		"result": "running",
		"ships_destroyed": 0,
		"damage_dealt": 0,
		"damage_received": 0,
		"rewards": {},
		"modules_recovered": [],
		"alternate_space": bool(payload.get("alternate_space", false))
	}
	_refresh_hud()


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.006, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.28, 0.38)
	environment.environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 2.0
	add_child(light)

	camera = Camera3D.new()
	camera.fov = 48
	add_child(camera)
	_reset_camera()

	_add_grid()
	_build_hud()


func _add_grid() -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2600, 2600)
	mesh_instance.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.07, 0.11, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	mesh_instance.position.y = -3
	add_child(mesh_instance)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	root.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	layout.add_child(top)

	player_label = _hud_label()
	player_label.custom_minimum_size = Vector2(350, 130)
	top.add_child(player_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	target_label = _hud_label()
	target_label.custom_minimum_size = Vector2(390, 150)
	top.add_child(target_label)

	var lower_spacer := Control.new()
	lower_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(lower_spacer)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	layout.add_child(bottom)

	weapon_box = VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 8)
	bottom.add_child(weapon_box)

	command_box = HBoxContainer.new()
	command_box.add_theme_constant_override("separation", 8)
	command_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(command_box)

	log_label = _hud_label()
	log_label.custom_minimum_size = Vector2(320, 110)
	bottom.add_child(log_label)

	_build_command_buttons()


func _build_command_buttons() -> void:
	for child in command_box.get_children():
		child.queue_free()
	_add_command_button("Approach", func() -> void:
		if selected_ship != null and target_ship != null:
			selected_ship.command_approach(target_ship)
	)
	_add_command_button("Maintain", func() -> void:
		if selected_ship != null and target_ship != null:
			selected_ship.command_maintain_range(target_ship, 520.0)
	)
	_add_command_button("Stop", func() -> void:
		if selected_ship != null:
			selected_ship.command_stop()
	)
	_add_command_button("Repair", _activate_emergency_repair)
	_add_command_button("Retreat", func() -> void: _finish_battle("retreat"))
	_add_command_button("Menu", func() -> void: _finish_battle("retreat"))


func _refresh_hud() -> void:
	if selected_ship == null:
		return
	var player_status: Dictionary = selected_ship.get_status_percent()
	player_label.text = "PLAYER: %s\nShield %.0f%%  Armor %.0f%%  Hull %.0f%%\nEnergy %.0f / %.0f\nCamera: RMB orbit, wheel zoom, MMB pan, F follow" % [
		selected_ship.display_name,
		player_status["shield"] * 100.0,
		player_status["armor"] * 100.0,
		player_status["hull"] * 100.0,
		selected_ship.energy,
		float(selected_ship.stats.get("energy_capacity", 0))
	]
	target_label.text = _target_text()
	_rebuild_weapon_buttons()


func _target_text() -> String:
	if target_ship == null:
		return "TARGET\nNo target selected.\nClick an enemy contact."
	var distance: float = selected_ship.global_position.distance_to(target_ship.global_position)
	var detection: int = TARGETING.detection_state(selected_ship, target_ship)
	var label_text: String = TARGETING.detection_label(detection)
	match detection:
		TARGETING.DetectionState.CONTACT:
			return "TARGET: UNKNOWN CONTACT\nDistance: %.1f km\nDetection: %s" % [distance / 100.0, label_text]
		TARGETING.DetectionState.CLASSIFIED:
			return "TARGET: Probable %s\nDistance: %.1f km\nThreat: %s\nDetection: %s" % [target_ship.ship_class.capitalize(), distance / 100.0, target_ship.stats.get("combat_rating", "?"), label_text]
		TARGETING.DetectionState.SCANNED:
			var status: Dictionary = target_ship.get_status_percent()
			return "TARGET: %s\nClass: %s  Distance: %.1f km\nShield %.0f%%  Armor %.0f%%  Hull %.0f%%" % [
				target_ship.display_name,
				target_ship.ship_class.capitalize(),
				distance / 100.0,
				status["shield"] * 100.0,
				status["armor"] * 100.0,
				status["hull"] * 100.0
			]
		_:
			return "TARGET\nUndetected signal."


func _rebuild_weapon_buttons() -> void:
	for child in weapon_box.get_children():
		child.queue_free()
	for index in range(selected_ship.weapons.size()):
		var weapon: Dictionary = selected_ship.weapons[index]
		var weapon_id: String = weapon.get("id", "")
		var button := Button.new()
		button.text = "%s\nCD %.1f  Energy %s" % [
			weapon.get("display_name", weapon_id),
			float(selected_ship.weapon_cooldowns.get(weapon_id, 0.0)),
			weapon.get("energy_cost", 0)
		]
		button.custom_minimum_size = Vector2(230, 58)
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = target_ship == null or not selected_ship.can_fire(index, target_ship)
		button.pressed.connect(func() -> void: _fire_selected_weapon(index))
		weapon_box.add_child(button)


func _add_command_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(105, 56)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	command_box.add_child(button)


func _hud_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 19)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spawn_fleet(fleet: Dictionary, target_array: Array) -> void:
	for ship_config in fleet.get("ships", []):
		if not (ship_config is Dictionary):
			continue
		var definition: Dictionary = ship_definitions.get(ship_config.get("definition", ""), {})
		if definition.is_empty():
			continue
		var scene_path: String = definition.get("base_scene", SHIP_SCENE)
		var packed: PackedScene = load(scene_path)
		var ship: Variant = packed.instantiate()
		add_child(ship)
		ship.setup(ship_config, definition, weapon_definitions)
		ship.faction = fleet.get("faction", definition.get("faction", "neutral"))
		ship.set_meta("ai_profile", ship_config.get("ai_profile", "aggressive"))
		ship.set_meta("reward", ship_config.get("reward", {}))
		ship.destroyed.connect(_on_ship_destroyed)
		target_array.append(ship)


func _tick_ships(delta: float) -> void:
	for ship in player_ships + enemy_ships:
		ship.tick(delta)


func _tick_ai(delta: float) -> void:
	ai_timer -= delta
	if ai_timer > 0.0:
		return
	ai_timer = 0.35
	var player: Variant = _first_living(player_ships)
	if player == null:
		return
	for enemy in enemy_ships:
		if not enemy.destroyed_flag:
			AI.tick(enemy, player, delta)


func _try_enemy_fire() -> void:
	var player: Variant = _first_living(player_ships)
	if player == null:
		return
	for enemy in enemy_ships:
		if enemy.destroyed_flag:
			continue
		var weapon_index: int = WEAPONS.first_ready_weapon(enemy, player)
		if weapon_index >= 0:
			_spawn_projectile(enemy, weapon_index, player)


func _fire_selected_weapon(index: int) -> void:
	if selected_ship == null or target_ship == null:
		_log("No target selected.")
		return
	if TARGETING.detection_state(selected_ship, target_ship) == TARGETING.DetectionState.UNDETECTED:
		_log("Target is not detected.")
		return
	if _spawn_projectile(selected_ship, index, target_ship) != null:
		_log("Weapon fired.")
	else:
		_log("Weapon not ready or target out of range.")


func _spawn_projectile(source: Variant, weapon_index: int, target: Variant) -> Node3D:
	var weapon: Dictionary = source.weapons[weapon_index]
	var scene_path := MISSILE_SCENE if weapon.get("weapon_type", "") == "missile" else PROJECTILE_SCENE
	var packed: PackedScene = load(scene_path)
	var projectile: Node3D = source.fire_weapon(weapon_index, target, packed)
	if projectile != null:
		add_child(projectile)
	return projectile


func _activate_emergency_repair() -> void:
	if selected_ship == null:
		return
	var fire_warship: Dictionary = _singleton("ShipState").ship_data.get("fire_warship", {})
	var module_id: String = fire_warship.get("equipped_modules", {}).get("special_01", "")
	var module: Dictionary = module_definitions.get(module_id, {})
	var special: Dictionary = module.get("special_properties", {})
	if special.get("active_ability", "") != "emergency_repair":
		_log("No repair module equipped.")
		return
	var cooldown: float = float(special.get("cooldown", 25.0))
	if float(special_cooldowns.get(module_id, 0.0)) > Time.get_ticks_msec() / 1000.0:
		_log("Repair module is cooling down.")
		return
	var energy_cost: float = float(module.get("energy_requirement", 40))
	if selected_ship.energy < energy_cost:
		_log("Not enough energy for emergency repair.")
		return
	selected_ship.energy -= energy_cost
	var repaired: float = selected_ship.repair_hull(float(special.get("repair_percent", 0.2)))
	special_cooldowns[module_id] = Time.get_ticks_msec() / 1000.0 + cooldown
	_log("Emergency repair restored %.0f hull." % repaired)


func _handle_left_click(screen_position: Vector2) -> void:
	var clicked_ship: Variant = _ship_at_screen_position(screen_position)
	if clicked_ship != null:
		if clicked_ship.faction == "player":
			if selected_ship != null:
				selected_ship.set_selected(false)
			selected_ship = clicked_ship
			selected_ship.set_selected(true)
			_log("Selected %s." % selected_ship.display_name)
		else:
			target_ship = clicked_ship
			_log("Target selected: %s." % target_ship.display_name)
		return

	var point := _screen_to_battle_plane(screen_position)
	if selected_ship != null:
		selected_ship.command_move(point)
		_log("Move order issued.")


func _ship_at_screen_position(screen_position: Vector2) -> Variant:
	var best_ship: Variant = null
	var best_distance := 99999.0
	for ship in player_ships + enemy_ships:
		if ship.destroyed_flag:
			continue
		var projected := camera.unproject_position(ship.global_position)
		var distance := projected.distance_to(screen_position)
		if distance < best_distance and distance < 42.0:
			best_distance = distance
			best_ship = ship
	return best_ship


func _screen_to_battle_plane(screen_position: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if abs(direction.y) < 0.001:
		return camera_target
	var t := -origin.y / direction.y
	return origin + direction * t


func _update_camera(delta: float) -> void:
	if follow_selected and selected_ship != null:
		camera_target = camera_target.lerp(selected_ship.global_position, min(1.0, delta * 2.2))
	var offset := Vector3(
		sin(camera_yaw) * cos(camera_pitch),
		-sin(camera_pitch),
		cos(camera_yaw) * cos(camera_pitch)
	) * camera_distance
	camera.global_position = camera.global_position.lerp(camera_target + offset, min(1.0, delta * 7.0))
	camera.look_at(camera_target, Vector3.UP)


func _reset_camera() -> void:
	camera_yaw = 0.0
	camera_pitch = -0.55
	camera_distance = 920.0
	if selected_ship != null:
		camera_target = selected_ship.global_position


func _check_battle_end() -> void:
	if _first_living(player_ships) == null:
		_finish_battle("defeat")
	elif _first_living(enemy_ships) == null:
		_finish_battle("victory")


func _finish_battle(battle_result: String) -> void:
	if battle_ended:
		return
	battle_ended = true
	var rewards := {}
	var destroyed_count := 0
	for enemy in enemy_ships:
		if enemy.destroyed_flag:
			destroyed_count += 1
			var reward: Dictionary = enemy.get_meta("reward", {})
			rewards["source_points"] = int(rewards.get("source_points", 0)) + int(reward.get("source_points", 0))
			for material_id in reward.get("materials", {}).keys():
				rewards[material_id] = int(rewards.get(material_id, 0)) + int(reward["materials"][material_id])
	var player: Variant = player_ships[0] if not player_ships.is_empty() else null
	var player_state: Dictionary = {}
	if player != null:
		player_state = {
			"hull": int(max(1.0, player.hull)),
			"armor": int(max(0.0, player.armor)),
			"shield": int(max(0.0, player.shield))
		}
	result = {
		"result": battle_result,
		"ships_destroyed": destroyed_count,
		"damage_dealt": int(_sum_damage(player_ships, "dealt")),
		"damage_received": int(_sum_damage(player_ships, "received")),
		"rewards": rewards if battle_result == "victory" or battle_result == "retreat" else {},
		"modules_recovered": [],
		"player_ship_state": player_state,
		"alternate_space": bool(payload.get("alternate_space", false))
	}
	battle_finished.emit(result)


func _on_ship_destroyed(ship: Variant) -> void:
	var packed: PackedScene = load(EXPLOSION_SCENE)
	var explosion: Node3D = packed.instantiate()
	add_child(explosion)
	explosion.global_position = ship.global_position
	if ship == target_ship:
		target_ship = null
	_log("%s destroyed." % ship.display_name)


func _first_living(ships: Array) -> Variant:
	for ship in ships:
		if not ship.destroyed_flag:
			return ship
	return null


func _sum_damage(ships: Array, mode: String) -> float:
	var value := 0.0
	for ship in ships:
		value += ship.damage_dealt if mode == "dealt" else ship.damage_received
	return value


func _log(message: String) -> void:
	if log_label != null:
		log_label.text = message


func _load_data(file_name: String) -> Dictionary:
	var data: Variant = _singleton("DataManager").load_data_file(file_name, {})
	return data if data is Dictionary else {}


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
