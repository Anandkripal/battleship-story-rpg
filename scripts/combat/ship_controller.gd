class_name ShipController
extends Node3D

signal destroyed(ship: Variant)

const VISUAL_WRAPPER := preload("res://scripts/combat/ship_visual_wrapper.gd")

var ship_id: String = ""
var display_name: String = ""
var faction: String = ""
var ship_class: String = ""
var stats: Dictionary = {}
var weapons: Array[Dictionary] = []
var weapon_cooldowns: Dictionary = {}
var hardpoints: Dictionary = {}
var shield: float = 0.0
var armor: float = 0.0
var hull: float = 0.0
var energy: float = 0.0
var target: Variant
var command: String = "stop"
var destination: Vector3 = Vector3.ZERO
var desired_range: float = 420.0
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var direct_control_enabled := false
var flight_assist_enabled := true
var thrust_input: Vector3 = Vector3.ZERO
var rotation_input: Vector3 = Vector3.ZERO
var boost_input := false
var damage_dealt: float = 0.0
var damage_received: float = 0.0
var destroyed_flag: bool = false
var visual_length: float = 120.0
var collision_radius: float = 80.0
var gameplay_root: Node3D
var visual_root: Node3D
var hardpoint_root: Node3D
var engine_root: Node3D
var vfx_root: Node3D
var audio_root: Node3D
var engine_glows: Array[MeshInstance3D] = []
var engine_particles: Array[GPUParticles3D] = []
var selection_ring: MeshInstance3D
var shield_flash: MeshInstance3D
var marker_label: Label3D
var engine_particles_enabled := true
var marker_labels_enabled := true


func setup(config: Dictionary, definition: Dictionary, weapon_defs: Dictionary) -> void:
	ship_id = config.get("id", "")
	display_name = config.get("display_name", definition.get("display_name", ship_id))
	faction = definition.get("faction", config.get("faction", "neutral"))
	ship_class = definition.get("ship_class", "unknown")
	stats = definition.get("base_stats", {}).duplicate(true)
	for key in config.get("stat_overrides", {}).keys():
		stats[key] = config["stat_overrides"][key]
	position = _array_to_vec3(config.get("position", [0, 0, 0]))
	destination = position
	shield = float(stats.get("max_shield", 0))
	armor = float(stats.get("max_armor", 0))
	hull = float(stats.get("max_hull", 1))
	energy = float(stats.get("energy_capacity", 100))
	visual_length = float(definition.get("visual_length", stats.get("visual_length", 120.0)))
	collision_radius = max(24.0, visual_length * 0.48)
	engine_particles_enabled = bool(definition.get("engine_particles_enabled", true))
	marker_labels_enabled = bool(definition.get("marker_labels_enabled", true))
	hardpoints = definition.get("hardpoints", {}).duplicate(true)
	for weapon_id in config.get("weapons", []):
		if weapon_defs.has(weapon_id):
			var weapon: Dictionary = weapon_defs[weapon_id].duplicate(true)
			weapon["id"] = weapon_id
			weapons.append(weapon)
			weapon_cooldowns[weapon_id] = 0.0
	_build_ship(definition)


func tick(delta: float) -> void:
	if destroyed_flag:
		return
	_recharge(delta)
	_tick_cooldowns(delta)
	if direct_control_enabled:
		_update_direct_flight(delta)
	else:
		_update_movement(delta)


func command_move(point: Vector3) -> void:
	direct_control_enabled = false
	command = "move"
	destination = point
	target = null


func command_approach(new_target: Variant) -> void:
	if new_target == null:
		return
	target = new_target
	direct_control_enabled = false
	command = "approach"
	desired_range = float(stats.get("preferred_range", 8500.0))


func command_maintain_range(new_target: Variant, range: float) -> void:
	if new_target == null:
		return
	target = new_target
	direct_control_enabled = false
	command = "maintain_range"
	desired_range = range


func command_stop() -> void:
	direct_control_enabled = false
	command = "stop"
	target = null
	destination = position


func command_retreat(from_position: Vector3) -> void:
	direct_control_enabled = false
	command = "retreat"
	var away: Vector3 = (position - from_position).normalized()
	if away.length() < 0.1:
		away = Vector3(0, 0, 1)
	destination = position + away * 1200.0
	target = null


func can_fire(weapon_index: int, new_target: Variant) -> bool:
	if destroyed_flag or new_target == null or new_target.destroyed_flag:
		return false
	if weapon_index < 0 or weapon_index >= weapons.size():
		return false
	var weapon: Dictionary = weapons[weapon_index]
	var weapon_id: String = weapon.get("id", "")
	var distance: float = global_position.distance_to(new_target.global_position)
	return distance <= float(weapon.get("range", 0)) and float(weapon_cooldowns.get(weapon_id, 0.0)) <= 0.0 and energy >= float(weapon.get("energy_cost", 0)) and target_in_firing_arc(weapon, new_target)


func fire_weapon(weapon_index: int, new_target: Variant, projectile_scene: PackedScene) -> Node3D:
	if not can_fire(weapon_index, new_target):
		return null
	var weapon: Dictionary = weapons[weapon_index]
	var weapon_id: String = weapon.get("id", "")
	energy -= float(weapon.get("energy_cost", 0))
	weapon_cooldowns[weapon_id] = float(weapon.get("cooldown", 1.0))
	var projectile: Node3D = projectile_scene.instantiate()
	var hardpoint_name: String = weapon.get("hardpoint", "WeaponHardpoint%02d" % (weapon_index + 1))
	projectile.position = get_hardpoint_global_position(hardpoint_name)
	if projectile.has_method("setup"):
		projectile.setup(self, new_target, _weapon_launch_data(weapon, new_target, hardpoint_name))
	return projectile


func set_direct_control(enabled: bool) -> void:
	direct_control_enabled = enabled
	if enabled:
		command = "manual"
		target = null


func set_manual_input(new_thrust: Vector3, new_rotation: Vector3, boost: bool) -> void:
	thrust_input = new_thrust.limit_length(1.0)
	rotation_input = new_rotation.limit_length(1.0)
	boost_input = boost
	if thrust_input.length() > 0.01 or rotation_input.length() > 0.01:
		set_direct_control(true)


func toggle_flight_assist() -> bool:
	flight_assist_enabled = not flight_assist_enabled
	return flight_assist_enabled


func target_in_firing_arc(weapon: Dictionary, new_target: Variant) -> bool:
	if new_target == null:
		return false
	var hardpoint_name: String = weapon.get("hardpoint", "MainWeapon")
	var forward: Vector3 = get_hardpoint_forward(hardpoint_name)
	var to_target: Vector3 = (new_target.global_position - get_hardpoint_global_position(hardpoint_name)).normalized()
	if to_target.length() < 0.001:
		return true
	var arc: float = float(weapon.get("firing_arc_degrees", 180.0))
	var angle: float = rad_to_deg(acos(clamp(forward.dot(to_target), -1.0, 1.0)))
	return angle <= arc * 0.5


func firing_arc_angle(weapon: Dictionary, new_target: Variant) -> float:
	if new_target == null:
		return 999.0
	var hardpoint_name: String = weapon.get("hardpoint", "MainWeapon")
	var forward: Vector3 = get_hardpoint_forward(hardpoint_name)
	var to_target: Vector3 = (new_target.global_position - get_hardpoint_global_position(hardpoint_name)).normalized()
	if to_target.length() < 0.001:
		return 0.0
	return rad_to_deg(acos(clamp(forward.dot(to_target), -1.0, 1.0)))


func apply_damage(amount: float, source: Variant = null) -> Dictionary:
	var remaining: float = amount
	var shield_damage: float = 0.0
	var armor_damage: float = 0.0
	var hull_damage: float = 0.0

	if shield > 0.0:
		shield_damage = min(shield, remaining)
		shield -= shield_damage
		remaining -= shield_damage
		_flash_shield()
	if remaining > 0.0 and armor > 0.0:
		armor_damage = min(armor, remaining)
		armor -= armor_damage
		remaining -= armor_damage
	if remaining > 0.0:
		hull_damage = min(hull, remaining)
		hull -= hull_damage
	damage_received += amount
	if source != null:
		source.damage_dealt += amount
	if hull <= 0.0 and not destroyed_flag:
		_destroy()
	return {
		"shield": shield_damage,
		"armor": armor_damage,
		"hull": hull_damage
	}


func repair_hull(percent: float) -> float:
	var max_hull: float = float(stats.get("max_hull", 1))
	var repair_amount: float = max_hull * percent
	var previous: float = hull
	hull = min(max_hull, hull + repair_amount)
	return hull - previous


func set_selected(selected: bool) -> void:
	if selection_ring != null:
		selection_ring.visible = selected


func set_marker_text(text: String, color: Color) -> void:
	if marker_label == null:
		return
	marker_label.text = text
	marker_label.modulate = color


func get_status_percent() -> Dictionary:
	return {
		"shield": shield / max(1.0, float(stats.get("max_shield", 1))),
		"armor": armor / max(1.0, float(stats.get("max_armor", 1))),
		"hull": hull / max(1.0, float(stats.get("max_hull", 1)))
	}


func _recharge(delta: float) -> void:
	energy = min(float(stats.get("energy_capacity", 100)), energy + float(stats.get("energy_recharge", 0)) * delta)
	if shield > 0.0:
		shield = min(float(stats.get("max_shield", 0)), shield + float(stats.get("shield_recharge", 0)) * delta)


func _tick_cooldowns(delta: float) -> void:
	for weapon_id in weapon_cooldowns.keys():
		weapon_cooldowns[weapon_id] = max(0.0, float(weapon_cooldowns[weapon_id]) - delta)


func _update_movement(delta: float) -> void:
	if command == "approach" and target != null:
		destination = target.global_position
	elif command == "maintain_range" and target != null:
		var from_target: Vector3 = global_position - target.global_position
		if from_target.length() < 0.1:
			from_target = Vector3(0, 0, 1)
		destination = target.global_position + from_target.normalized() * desired_range
	elif command == "stop":
		destination = global_position

	var to_destination: Vector3 = destination - global_position
	var distance: float = to_destination.length()
	var max_speed: float = float(stats.get("max_speed", 20))
	var acceleration: float = float(stats.get("acceleration", 6))
	var target_velocity: Vector3 = Vector3.ZERO
	if distance > 4.0:
		target_velocity = to_destination.normalized() * max_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	global_position += velocity * delta
	if velocity.length() > 0.1:
		var target_transform: Transform3D = global_transform.looking_at(global_position + velocity.normalized(), Vector3.UP)
		var turn_rate: float = float(stats.get("turn_rate", 1.0))
		global_transform.basis = global_transform.basis.slerp(target_transform.basis, clamp(turn_rate * delta, 0.0, 1.0)).orthonormalized()
	_update_engine_effects()


func _update_direct_flight(delta: float) -> void:
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var up: Vector3 = global_transform.basis.y
	var max_speed: float = float(stats.get("max_speed", 20))
	var acceleration: float = float(stats.get("acceleration", 6))
	var reverse_factor: float = float(stats.get("reverse_thrust_factor", 0.6))
	var strafe_factor: float = float(stats.get("strafe_thrust_factor", 0.45))
	var vertical_factor: float = float(stats.get("vertical_thrust_factor", 0.45))
	var boost_factor: float = float(stats.get("boost_factor", 1.55)) if boost_input and thrust_input.z > 0.1 and energy > 3.0 else 1.0
	if boost_factor > 1.0:
		energy = max(0.0, energy - float(stats.get("boost_energy_per_second", 18.0)) * delta)
	var acceleration_vector: Vector3 = Vector3.ZERO
	if thrust_input.z > 0.0:
		acceleration_vector += forward * acceleration * thrust_input.z * boost_factor
	elif thrust_input.z < 0.0:
		acceleration_vector += forward * acceleration * thrust_input.z * reverse_factor
	acceleration_vector += right * acceleration * thrust_input.x * strafe_factor
	acceleration_vector += up * acceleration * thrust_input.y * vertical_factor
	velocity += acceleration_vector * delta
	if velocity.length() > max_speed * boost_factor:
		velocity = velocity.normalized() * max_speed * boost_factor
	if flight_assist_enabled and thrust_input.length() < 0.02:
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * 0.48 * delta)
	global_position += velocity * delta

	var turn_acceleration: float = float(stats.get("angular_acceleration", 0.9))
	var max_turn_speed: float = float(stats.get("max_angular_speed", 0.62))
	angular_velocity += rotation_input * turn_acceleration * delta
	if angular_velocity.length() > max_turn_speed:
		angular_velocity = angular_velocity.normalized() * max_turn_speed
	if flight_assist_enabled and rotation_input.length() < 0.02:
		angular_velocity = angular_velocity.move_toward(Vector3.ZERO, turn_acceleration * 0.72 * delta)
	rotate_object_local(Vector3.RIGHT, angular_velocity.x * delta)
	rotate_object_local(Vector3.UP, angular_velocity.y * delta)
	rotate_object_local(Vector3.FORWARD, angular_velocity.z * delta)
	_update_engine_effects()


func _destroy() -> void:
	destroyed_flag = true
	velocity = Vector3.ZERO
	command = "destroyed"
	if selection_ring != null:
		selection_ring.visible = false
	for particles in engine_particles:
		particles.emitting = false
	destroyed.emit(self)


func _build_ship(definition: Dictionary) -> void:
	gameplay_root = Node3D.new()
	gameplay_root.name = "GameplayRoot"
	add_child(gameplay_root)

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	hardpoint_root = Node3D.new()
	hardpoint_root.name = "Hardpoints"
	add_child(hardpoint_root)

	engine_root = Node3D.new()
	engine_root.name = "EnginePoints"
	add_child(engine_root)

	vfx_root = Node3D.new()
	vfx_root.name = "VFX"
	add_child(vfx_root)

	audio_root = Node3D.new()
	audio_root.name = "Audio"
	add_child(audio_root)

	_add_visual_wrapper(definition)
	_add_hardpoints()
	_add_engine_effects()
	_add_selection_and_shield()
	_add_marker_label()


func _add_visual_wrapper(definition: Dictionary) -> void:
	var wrapper: Node3D = null
	var visual_scene_path: String = definition.get("visual_scene", "")
	if not visual_scene_path.is_empty() and ResourceLoader.exists(visual_scene_path):
		var packed: PackedScene = load(visual_scene_path)
		wrapper = packed.instantiate()
	else:
		wrapper = VISUAL_WRAPPER.new()
	if wrapper.has_method("setup"):
		wrapper.setup(definition)
	visual_root.add_child(wrapper)


func _add_hardpoints() -> void:
	for hardpoint_name in hardpoints.keys():
		var marker := Marker3D.new()
		marker.name = hardpoint_name
		marker.position = _array_to_vec3(hardpoints[hardpoint_name])
		if hardpoint_name.begins_with("Engine"):
			engine_root.add_child(marker)
		else:
			hardpoint_root.add_child(marker)


func _add_engine_effects() -> void:
	var engine_markers: Array[Node] = engine_root.get_children()
	if engine_markers.is_empty():
		var fallback_marker := Marker3D.new()
		fallback_marker.name = "EngineHardpoint01"
		fallback_marker.position = Vector3(0, 0, visual_length * 0.52)
		engine_root.add_child(fallback_marker)
		engine_markers = engine_root.get_children()

	for marker_node in engine_markers:
		if not (marker_node is Node3D):
			continue
		var marker := marker_node as Node3D
		var glow := MeshInstance3D.new()
		glow.name = "%sGlow" % marker.name
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = max(4.0, visual_length * 0.035)
		glow.mesh = glow_mesh
		glow.position = marker.position
		glow.material_override = _engine_material(0.45)
		engine_root.add_child(glow)
		engine_glows.append(glow)

		if engine_particles_enabled:
			var particles := GPUParticles3D.new()
			particles.name = "%sTrail" % marker.name
			particles.position = marker.position + Vector3(0, 0, visual_length * 0.035)
			particles.amount = 12
			particles.lifetime = 0.45
			particles.emitting = true
			var process_material := ParticleProcessMaterial.new()
			process_material.direction = Vector3(0, 0, 1)
			process_material.spread = 6.0
			process_material.initial_velocity_min = max(20.0, visual_length * 0.16)
			process_material.initial_velocity_max = max(35.0, visual_length * 0.24)
			process_material.scale_min = 0.35
			process_material.scale_max = 0.9
			process_material.color = Color(0.15, 0.72, 1.0, 0.45)
			particles.process_material = process_material
			var particle_mesh := SphereMesh.new()
			particle_mesh.radius = max(1.0, visual_length * 0.008)
			particles.draw_pass_1 = particle_mesh
			engine_root.add_child(particles)
			engine_particles.append(particles)


func _add_selection_and_shield() -> void:
	var ring_radius: float = collision_radius * 1.08

	selection_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = ring_radius
	torus.outer_radius = ring_radius + max(2.0, visual_length * 0.012)
	selection_ring.mesh = torus
	selection_ring.rotation_degrees.x = 90
	selection_ring.visible = false
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.1, 1.0, 0.85)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.1, 1.0, 0.85)
	selection_ring.material_override = ring_material
	vfx_root.add_child(selection_ring)

	shield_flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = ring_radius
	shield_flash.mesh = sphere
	var shield_material := StandardMaterial3D.new()
	shield_material.albedo_color = Color(0.25, 0.65, 1.0, 0.16)
	shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_material.emission_enabled = true
	shield_material.emission = Color(0.25, 0.65, 1.0)
	shield_flash.material_override = shield_material
	shield_flash.visible = false
	vfx_root.add_child(shield_flash)


func _add_marker_label() -> void:
	if not marker_labels_enabled:
		return
	marker_label = Label3D.new()
	marker_label.name = "TacticalLabel"
	marker_label.text = display_name
	marker_label.position = Vector3(0, max(90.0, visual_length * 0.42), 0)
	marker_label.font_size = 42
	marker_label.pixel_size = max(0.9, visual_length * 0.006)
	marker_label.outline_size = 4
	marker_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	marker_label.modulate = Color(0.35, 0.95, 1.0) if faction == "player" else Color(1.0, 0.35, 0.24)
	marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	vfx_root.add_child(marker_label)


func _engine_material(intensity: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.55, 1.0, 0.86)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.1, 0.65, 1.0) * intensity
	return material


func _update_engine_effects() -> void:
	var max_speed: float = max(1.0, float(stats.get("max_speed", 1.0)))
	var thrust_ratio: float = clamp(velocity.length() / max_speed, 0.0, 1.0)
	var intensity: float = 0.35 + thrust_ratio * 1.35 + (0.75 if boost_input else 0.0)
	for glow in engine_glows:
		var material := glow.material_override as StandardMaterial3D
		if material != null:
			material.emission = Color(0.1, 0.65, 1.0) * intensity
			glow.scale = Vector3.ONE * (0.9 + thrust_ratio * 0.85)
	for particles in engine_particles:
		particles.speed_scale = 0.45 + thrust_ratio * 1.25


func _flash_shield() -> void:
	if shield_flash == null:
		return
	shield_flash.visible = true
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func() -> void:
		if shield_flash != null:
			shield_flash.visible = false
	)


func _hardpoint_offset(hardpoint_name: String) -> Vector3:
	var marker := hardpoint_root.get_node_or_null(hardpoint_name) if hardpoint_root != null else null
	if marker == null and engine_root != null:
		marker = engine_root.get_node_or_null(hardpoint_name)
	if marker is Marker3D:
		return marker.global_position - global_position
	return Vector3(0, visual_length * 0.03, -visual_length * 0.5)


func get_hardpoint_global_position(hardpoint_name: String) -> Vector3:
	var marker := hardpoint_root.get_node_or_null(hardpoint_name) if hardpoint_root != null else null
	if marker == null and engine_root != null:
		marker = engine_root.get_node_or_null(hardpoint_name)
	if marker is Marker3D:
		return marker.global_position
	return global_position + global_transform.basis * Vector3(0, visual_length * 0.03, -visual_length * 0.5)


func get_hardpoint_forward(hardpoint_name: String) -> Vector3:
	var marker := hardpoint_root.get_node_or_null(hardpoint_name) if hardpoint_root != null else null
	if marker == null and engine_root != null:
		marker = engine_root.get_node_or_null(hardpoint_name)
	if marker is Marker3D:
		return -marker.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()


func _weapon_launch_data(weapon: Dictionary, new_target: Variant, hardpoint_name: String) -> Dictionary:
	var launch_weapon: Dictionary = weapon.duplicate(true)
	var launch_direction: Vector3 = get_hardpoint_forward(hardpoint_name)
	if launch_weapon.get("weapon_type", "") != "missile":
		launch_direction = _intercept_direction(new_target, get_hardpoint_global_position(hardpoint_name), float(weapon.get("projectile_speed", 120.0)), launch_direction)
	launch_weapon["launch_direction"] = launch_direction
	launch_weapon["source_velocity"] = velocity
	launch_weapon["owner_id"] = ship_id
	return launch_weapon


func _intercept_direction(new_target: Variant, origin: Vector3, projectile_speed: float, fallback: Vector3) -> Vector3:
	if new_target == null or projectile_speed <= 0.0:
		return fallback
	var target_velocity: Vector3 = new_target.velocity
	var relative_position: Vector3 = new_target.global_position - origin
	var a: float = target_velocity.dot(target_velocity) - projectile_speed * projectile_speed
	var b: float = 2.0 * relative_position.dot(target_velocity)
	var c: float = relative_position.dot(relative_position)
	var t: float = 0.0
	if abs(a) < 0.001:
		t = -c / b if abs(b) > 0.001 else 0.0
	else:
		var discriminant: float = b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var sqrt_disc: float = sqrt(discriminant)
			var t1: float = (-b - sqrt_disc) / (2.0 * a)
			var t2: float = (-b + sqrt_disc) / (2.0 * a)
			t = min(t1, t2) if t1 > 0.0 and t2 > 0.0 else max(t1, t2)
	if t <= 0.0:
		return relative_position.normalized()
	return (relative_position + target_velocity * t).normalized()


func _array_to_vec3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
