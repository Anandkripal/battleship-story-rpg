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
	_update_movement(delta)


func command_move(point: Vector3) -> void:
	command = "move"
	destination = point
	target = null


func command_approach(new_target: Variant) -> void:
	if new_target == null:
		return
	target = new_target
	command = "approach"
	desired_range = float(stats.get("preferred_range", 8500.0))


func command_maintain_range(new_target: Variant, range: float) -> void:
	if new_target == null:
		return
	target = new_target
	command = "maintain_range"
	desired_range = range


func command_stop() -> void:
	command = "stop"
	target = null
	destination = position


func command_retreat(from_position: Vector3) -> void:
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
	return distance <= float(weapon.get("range", 0)) and float(weapon_cooldowns.get(weapon_id, 0.0)) <= 0.0 and energy >= float(weapon.get("energy_cost", 0))


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
		projectile.setup(self, new_target, weapon)
	return projectile


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
		look_at(global_position + velocity.normalized(), Vector3.UP)
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

		var particles := GPUParticles3D.new()
		particles.name = "%sTrail" % marker.name
		particles.position = marker.position + Vector3(0, 0, visual_length * 0.035)
		particles.amount = 28
		particles.lifetime = 0.8
		particles.emitting = true
		var process_material := ParticleProcessMaterial.new()
		process_material.direction = Vector3(0, 0, 1)
		process_material.spread = 8.0
		process_material.initial_velocity_min = max(20.0, visual_length * 0.22)
		process_material.initial_velocity_max = max(35.0, visual_length * 0.32)
		process_material.scale_min = 0.5
		process_material.scale_max = 1.4
		process_material.color = Color(0.15, 0.72, 1.0, 0.6)
		particles.process_material = process_material
		var particle_mesh := SphereMesh.new()
		particle_mesh.radius = max(1.0, visual_length * 0.012)
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
	var intensity: float = 0.35 + thrust_ratio * 1.35
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


func _array_to_vec3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
