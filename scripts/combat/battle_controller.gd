extends Node3D

signal battle_finished(result: Dictionary)

const SHIP_SCENE := "res://scenes/combat/ship_3d.tscn"
const PROJECTILE_SCENE := "res://scenes/combat/projectile_3d.tscn"
const MISSILE_SCENE := "res://scenes/combat/missile_3d.tscn"
const EXPLOSION_SCENE := "res://scenes/combat/explosion_3d.tscn"
const TARGETING := preload("res://scripts/combat/targeting_system.gd")
const WEAPONS := preload("res://scripts/combat/weapon_system.gd")
const AI := preload("res://scripts/combat/combat_ai.gd")
const MODEL_CATALOG := preload("res://scripts/combat/model_catalog.gd")

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
var intro_overlay: Control
var completion_overlay: Control
var player_label: Label
var target_label: Label
var log_label: Label
var weapon_box: VBoxContainer
var command_box: HBoxContainer
var result: Dictionary = {}
var battle_started := false
var battle_ended := false
var intro_active := false
var ai_timer := 0.0
var hud_timer := 0.0
var special_cooldowns: Dictionary = {}
var manual_scans: Dictionary = {}


func _ready() -> void:
	call_deferred("_start_default_if_needed")


func setup(new_payload: Dictionary = {}) -> void:
	payload = new_payload.duplicate(true)
	_start_battle()


func _process(delta: float) -> void:
	if not battle_started or battle_ended:
		if battle_ended:
			_update_camera(delta)
		return
	if intro_active:
		_update_camera(delta)
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
	if intro_active:
		if event is InputEventMouseButton or event is InputEventKey:
			_finish_intro()
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
			camera_distance = min(36000.0, camera_distance * 1.12)
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
				_focus_selected_ship()
			KEY_T:
				_focus_target_ship()
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
		follow_selected = true
	if bool(config.get("auto_select_first_enemy", false)) and not enemy_ships.is_empty():
		target_ship = enemy_ships[0]
		manual_scans[target_ship.ship_id] = true
		target_ship.set_selected(true)
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
	_update_ship_markers()
	_start_intro()
	_apply_opening_camera()


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.006, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var env_data: Dictionary = config.get("environment", {})
	env.ambient_light_color = _array_to_color(env_data.get("ambient_color", [0.11, 0.14, 0.2]), Color(0.11, 0.14, 0.2))
	env.ambient_light_energy = float(env_data.get("ambient_energy", 0.8))
	env.glow_enabled = bool(env_data.get("glow_enabled", not _performance_mode()))
	env.glow_intensity = float(env_data.get("glow_intensity", 0.38))
	environment.environment = env
	add_child(environment)

	var sun_data: Dictionary = env_data.get("sun", {})
	var sun_position: Vector3 = _array_to_vec3(sun_data.get("position", [24000, 12000, -18000]))
	var light := DirectionalLight3D.new()
	light.look_at_from_position(sun_position.normalized() * -1000.0, Vector3.ZERO, Vector3.UP)
	light.light_energy = float(sun_data.get("energy", 2.2))
	add_child(light)
	_add_sun(sun_position, _array_to_color(sun_data.get("color", [1.0, 0.82, 0.52]), Color(1.0, 0.82, 0.52)))

	camera = Camera3D.new()
	camera.fov = 48
	camera.far = 120000
	add_child(camera)
	_reset_camera()

	_add_starfield(int(env_data.get("starfield_count", 260)))
	_add_planet(env_data.get("planet", {}))
	_add_asteroid_field(env_data.get("asteroid_field", {}))
	_add_grid()
	_build_hud()


func _add_grid() -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(52000, 52000)
	mesh_instance.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.07, 0.11, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	mesh_instance.position.y = -18
	add_child(mesh_instance)


func _add_starfield(count: int) -> void:
	var multimesh_instance := MultiMeshInstance3D.new()
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 18.0
	var multimesh := MultiMesh.new()
	multimesh.mesh = star_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = count
	for index in range(count):
		var angle: float = float(index) * 12.9898
		var radius: float = 42000.0 + fmod(float(index * 7919), 38000.0)
		var x: float = sin(angle) * radius
		var y: float = -9000.0 + fmod(float(index * 4813), 22000.0)
		var z: float = cos(angle * 0.73) * radius - 17000.0
		var transform := Transform3D(Basis(), Vector3(x, y, z))
		var size: float = 0.35 + fmod(float(index * 37), 120.0) / 100.0
		transform.basis = Basis().scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(index, transform)
	multimesh_instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.9, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.62, 0.76, 1.0) * 0.75
	multimesh_instance.material_override = material
	add_child(multimesh_instance)


func _add_sun(position_value: Vector3, color: Color) -> void:
	var sun := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 900.0
	sun.mesh = mesh
	sun.position = position_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 1.8
	sun.material_override = material
	add_child(sun)


func _add_planet(planet_data: Dictionary) -> void:
	if planet_data.is_empty():
		return
	var planet: Node3D = null
	if not _performance_mode() and bool(config.get("use_optional_models", true)):
		planet = MODEL_CATALOG.instantiate_model(planet_data.get("visual_model", ""))
	if planet == null:
		var mesh_instance := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = float(planet_data.get("radius", 6200.0))
		mesh.radial_segments = 24 if _performance_mode() else 64
		mesh.rings = 12 if _performance_mode() else 32
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _solid_material(_array_to_color(planet_data.get("color", [0.18, 0.34, 0.72]), Color(0.18, 0.34, 0.72)), Color(0.03, 0.07, 0.14))
		planet = mesh_instance
	planet.position = _array_to_vec3(planet_data.get("position", [-12500, -2600, -34000]))
	add_child(planet)


func _add_asteroid_field(field_data: Dictionary) -> void:
	if field_data.is_empty():
		return
	var count: int = int(field_data.get("count", 24))
	var center: Vector3 = _array_to_vec3(field_data.get("center", [9000, -350, -11200]))
	var spread: Vector3 = _array_to_vec3(field_data.get("spread", [5000, 1200, 4200]))
	var visual_models: Array = field_data.get("visual_models", [])
	for index in range(count):
		var asteroid: Node3D = null
		if not _performance_mode() and bool(config.get("use_optional_models", true)) and not visual_models.is_empty():
			asteroid = MODEL_CATALOG.instantiate_model(str(visual_models[index % visual_models.size()]))
		if asteroid == null:
			asteroid = _fallback_asteroid(float(index))
		var offset := Vector3(
			(fmod(float(index * 1543), 1000.0) / 1000.0 - 0.5) * spread.x,
			(fmod(float(index * 2909), 1000.0) / 1000.0 - 0.5) * spread.y,
			(fmod(float(index * 3907), 1000.0) / 1000.0 - 0.5) * spread.z
		)
		asteroid.position = center + offset
		asteroid.rotation_degrees = Vector3(index * 17.0, index * 43.0, index * 29.0)
		var scale_value: float = 0.55 + fmod(float(index * 97), 140.0) / 100.0
		asteroid.scale *= scale_value
		add_child(asteroid)


func _fallback_asteroid(index: float) -> Node3D:
	var asteroid := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 75.0 + fmod(index * 53.0, 130.0)
	mesh.radial_segments = 10
	mesh.rings = 5
	asteroid.mesh = mesh
	asteroid.scale = Vector3(1.0, 0.62 + fmod(index * 0.19, 0.7), 0.78 + fmod(index * 0.31, 0.8))
	asteroid.material_override = _solid_material(Color(0.33, 0.31, 0.29), Color(0.02, 0.018, 0.015))
	return asteroid


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
	_add_command_button("Scan", _scan_target)
	_add_command_button("Maintain", func() -> void:
		if selected_ship != null and target_ship != null:
			selected_ship.command_maintain_range(target_ship, float(selected_ship.stats.get("preferred_range", 8500.0)))
	)
	_add_command_button("Stop", func() -> void:
		if selected_ship != null:
			selected_ship.command_stop()
	)
	_add_command_button("Focus Ship", _focus_selected_ship)
	_add_command_button("Focus Target", _focus_target_ship)
	_add_command_button("Repair", _activate_emergency_repair)
	_add_command_button("Retreat", func() -> void: _finish_battle("retreat"))


func _refresh_hud() -> void:
	if selected_ship == null:
		return
	var player_status: Dictionary = selected_ship.get_status_percent()
	player_label.text = "PLAYER: %s\nShield %.0f%%  Armor %.0f%%  Hull %.0f%%\nEnergy %.0f / %.0f\nCamera: RMB orbit, wheel zoom, MMB pan, F focus, T target" % [
		selected_ship.display_name,
		player_status["shield"] * 100.0,
		player_status["armor"] * 100.0,
		player_status["hull"] * 100.0,
		selected_ship.energy,
		float(selected_ship.stats.get("energy_capacity", 0))
	]
	target_label.text = _target_text()
	_rebuild_weapon_buttons()
	_update_ship_markers()


func _target_text() -> String:
	if target_ship == null:
		return "TARGET\nNo target selected.\nClick an enemy contact."
	var distance: float = selected_ship.global_position.distance_to(target_ship.global_position)
	var detection: int = _detection_state(selected_ship, target_ship)
	var label_text: String = TARGETING.detection_label(detection)
	match detection:
		TARGETING.DetectionState.CONTACT:
			return "TARGET: UNKNOWN CONTACT\nDistance: %s\nDetection: %s" % [_format_distance(distance), label_text]
		TARGETING.DetectionState.CLASSIFIED:
			return "TARGET: Probable %s\nDistance: %s\nThreat: %s\nDetection: %s" % [target_ship.ship_class.capitalize(), _format_distance(distance), target_ship.stats.get("combat_rating", "?"), label_text]
		TARGETING.DetectionState.SCANNED:
			var status: Dictionary = target_ship.get_status_percent()
			return "TARGET: %s\nClass: %s  Distance: %s\nShield %.0f%%  Armor %.0f%%  Hull %.0f%%" % [
				target_ship.display_name,
				target_ship.ship_class.capitalize(),
				_format_distance(distance),
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
		var status_text: String = _weapon_status(weapon)
		var button := Button.new()
		button.text = "%s\n%s" % [
			weapon.get("display_name", weapon_id),
			status_text
		]
		button.custom_minimum_size = Vector2(245, 64)
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
		definition = definition.duplicate(true)
		if _performance_mode() or not bool(config.get("use_optional_models", true)):
			definition["force_fallback_visuals"] = true
			definition["engine_particles_enabled"] = false
		var scene_path: String = definition.get("base_scene", SHIP_SCENE)
		var packed: PackedScene = load(scene_path)
		var ship: Variant = packed.instantiate()
		add_child(ship)
		ship.setup(ship_config, definition, weapon_definitions)
		ship.faction = fleet.get("faction", definition.get("faction", "neutral"))
		ship.set_meta("ai_profile", ship_config.get("ai_profile", "aggressive"))
		ship.set_meta("ai_state", "PATROL")
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
	if _detection_state(selected_ship, target_ship) == TARGETING.DetectionState.UNDETECTED:
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


func _scan_target() -> void:
	if selected_ship == null or target_ship == null:
		_log("Select a target to scan.")
		return
	var distance: float = selected_ship.global_position.distance_to(target_ship.global_position)
	if distance > float(selected_ship.stats.get("sensor_range", 0)) * 1.15:
		_log("Target outside scan envelope: %s." % _format_distance(distance))
		return
	manual_scans[target_ship.ship_id] = true
	_log("Scan complete: %s identified." % target_ship.display_name)
	_refresh_hud()


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
			if target_ship != null:
				target_ship.set_selected(false)
			target_ship = clicked_ship
			target_ship.set_selected(true)
			_log("Target selected: %s." % TARGETING.detection_label(_detection_state(selected_ship, target_ship)))
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
		var pick_radius: float = max(42.0, float(ship.collision_radius) * 0.18)
		if distance < best_distance and distance < pick_radius:
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
	camera_distance = 9000.0
	if selected_ship != null:
		camera_target = selected_ship.global_position
	_apply_opening_camera()


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
	_show_completion_overlay(result)


func _on_ship_destroyed(ship: Variant) -> void:
	var packed: PackedScene = load(EXPLOSION_SCENE)
	var explosion: Node3D = packed.instantiate()
	add_child(explosion)
	explosion.global_position = ship.global_position
	explosion.scale = Vector3.ONE * _explosion_scale(ship.ship_class)
	if ship == target_ship:
		target_ship = null
	var reward: Dictionary = ship.get_meta("reward", {})
	var source_points: int = int(reward.get("source_points", 0))
	_log("%s destroyed. +%s Source Points pending." % [ship.display_name, source_points])
	var tween := create_tween()
	tween.tween_property(ship, "scale", ship.scale * 0.68, 1.25)
	tween.tween_interval(1.2)
	tween.tween_callback(ship.queue_free)


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


func _start_intro() -> void:
	if not bool(config.get("intro", {}).get("enabled", true)):
		_finish_intro()
		return
	intro_active = true
	var intro_data: Dictionary = config.get("intro", {})
	intro_overlay = Control.new()
	intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_overlay.add_child(shade)
	var label := Label.new()
	label.text = "%s\nClick or press any key to skip." % intro_data.get("message", "SENSOR WARNING: UNKNOWN CONTACTS DETECTED")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_overlay.add_child(label)
	hud_layer.add_child(intro_overlay)
	camera_target = Vector3(-2500, 400, -6200)
	camera_distance = 14500.0
	var timer := get_tree().create_timer(float(intro_data.get("duration", 5.0)))
	timer.timeout.connect(_finish_intro)


func _finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	if intro_overlay != null:
		intro_overlay.queue_free()
		intro_overlay = null
	_log("SENSOR WARNING: UNKNOWN CONTACTS DETECTED")
	if bool(config.get("keep_opening_camera_after_intro", false)):
		_apply_opening_camera()
	else:
		_focus_selected_ship()


func _show_completion_overlay(final_result: Dictionary) -> void:
	if hud_layer == null:
		battle_finished.emit(final_result)
		return
	completion_overlay = Control.new()
	completion_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(completion_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 360)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_top = -180
	panel.offset_right = 260
	panel.offset_bottom = 180
	completion_overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "EXPEDITION COMPLETE" if final_result.get("result", "") == "victory" else "EXPEDITION ABORTED"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var report := Label.new()
	report.text = _format_result(final_result)
	report.add_theme_font_size_override("font_size", 20)
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(report)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var return_button := Button.new()
	return_button.text = "RETURN"
	return_button.custom_minimum_size = Vector2(180, 58)
	return_button.add_theme_font_size_override("font_size", 22)
	return_button.pressed.connect(func() -> void: battle_finished.emit(final_result))
	row.add_child(return_button)

	var observe_button := Button.new()
	observe_button.text = "OBSERVE"
	observe_button.custom_minimum_size = Vector2(180, 58)
	observe_button.add_theme_font_size_override("font_size", 22)
	observe_button.pressed.connect(func() -> void:
		if completion_overlay != null:
			completion_overlay.queue_free()
			completion_overlay = null
	)
	row.add_child(observe_button)


func _format_result(final_result: Dictionary) -> String:
	var rewards: Dictionary = final_result.get("rewards", {})
	var reward_lines: Array[String] = []
	for resource_id in rewards.keys():
		reward_lines.append("+%s %s" % [rewards[resource_id], resource_id.capitalize().replace("_", " ")])
	return "Enemies Destroyed: %s\nSource/Materials: %s\nDamage Dealt: %s\nDamage Taken: %s" % [
		final_result.get("ships_destroyed", 0),
		", ".join(reward_lines) if not reward_lines.is_empty() else "None",
		final_result.get("damage_dealt", 0),
		final_result.get("damage_received", 0)
	]


func _focus_selected_ship() -> void:
	if selected_ship == null:
		return
	follow_selected = true
	camera_target = selected_ship.global_position
	camera_distance = max(1800.0, float(selected_ship.visual_length) * 6.0)


func _focus_target_ship() -> void:
	if target_ship == null:
		_log("No target selected.")
		return
	follow_selected = false
	camera_target = target_ship.global_position
	camera_distance = max(2600.0, float(target_ship.visual_length) * 7.0)


func _apply_opening_camera() -> void:
	var camera_data: Dictionary = config.get("opening_camera", {})
	if camera_data.is_empty():
		return
	follow_selected = bool(camera_data.get("follow_selected", false))
	camera_yaw = deg_to_rad(float(camera_data.get("yaw_degrees", 18.0)))
	camera_pitch = deg_to_rad(float(camera_data.get("pitch_degrees", -30.0)))
	camera_distance = float(camera_data.get("distance", 5200.0))
	camera_target = _array_to_vec3(camera_data.get("target", [0, 0, -1800]))
	if bool(camera_data.get("target_midpoint", false)) and selected_ship != null and target_ship != null:
		camera_target = selected_ship.global_position.lerp(target_ship.global_position, 0.42)


func _update_ship_markers() -> void:
	if selected_ship == null:
		return
	for ship in player_ships:
		if ship != null and ship.has_method("set_marker_text"):
			ship.set_marker_text("FIRE WARSHIP", Color(0.35, 0.95, 1.0))
	for enemy in enemy_ships:
		if enemy == null or not enemy.has_method("set_marker_text"):
			continue
		var detection: int = _detection_state(selected_ship, enemy)
		match detection:
			TARGETING.DetectionState.SCANNED:
				enemy.set_marker_text("%s\n%s" % [enemy.display_name.to_upper(), _format_distance(selected_ship.global_position.distance_to(enemy.global_position))], Color(1.0, 0.38, 0.24))
			TARGETING.DetectionState.CLASSIFIED:
				enemy.set_marker_text("HOSTILE %s\n%s" % [enemy.ship_class.to_upper(), _format_distance(selected_ship.global_position.distance_to(enemy.global_position))], Color(1.0, 0.62, 0.24))
			TARGETING.DetectionState.CONTACT:
				enemy.set_marker_text("UNKNOWN CONTACT\n%s" % _format_distance(selected_ship.global_position.distance_to(enemy.global_position)), Color(1.0, 0.86, 0.28))
			_:
				enemy.set_marker_text("SIGNAL\n%s" % _format_distance(selected_ship.global_position.distance_to(enemy.global_position)), Color(0.7, 0.7, 0.7))


func _detection_state(observer: Variant, target: Variant) -> int:
	if target != null and manual_scans.has(target.ship_id):
		return TARGETING.DetectionState.SCANNED
	return TARGETING.detection_state(observer, target)


func _weapon_status(weapon: Dictionary) -> String:
	var weapon_id: String = weapon.get("id", "")
	var cooldown: float = float(selected_ship.weapon_cooldowns.get(weapon_id, 0.0))
	var range: float = float(weapon.get("range", 0.0))
	var distance: float = selected_ship.global_position.distance_to(target_ship.global_position) if target_ship != null else 0.0
	if target_ship == null:
		return "Range %s | No target" % _format_distance(range)
	if distance > range:
		return "Range %s | Target %s | OUT" % [_format_distance(range), _format_distance(distance)]
	if selected_ship.energy < float(weapon.get("energy_cost", 0)):
		return "Range %s | ENERGY LOW" % _format_distance(range)
	if cooldown > 0.0:
		return "Range %s | CD %.1f" % [_format_distance(range), cooldown]
	return "Range %s | READY" % _format_distance(range)


func _format_distance(distance: float) -> String:
	if distance < 1000.0:
		return "%.0f m" % distance
	return "%.1f km" % (distance / 1000.0)


func _explosion_scale(ship_class_name: String) -> float:
	match ship_class_name:
		"frigate":
			return 10.0
		"destroyer":
			return 18.0
		"cruiser":
			return 34.0
		_:
			return 14.0


func _solid_material(albedo: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material


func _performance_mode() -> bool:
	return bool(config.get("performance_mode", false))


func _array_to_color(value: Variant, fallback: Color) -> Color:
	if value is Array and value.size() >= 3:
		var alpha := float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return fallback


func _array_to_vec3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _load_data(file_name: String) -> Dictionary:
	var data: Variant = _singleton("DataManager").load_data_file(file_name, {})
	return data if data is Dictionary else {}


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
