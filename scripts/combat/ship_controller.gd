class_name ShipController
extends Node3D

signal destroyed(ship: Variant)

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
	hardpoints = definition.get("hardpoints", {}).duplicate(true)
	for weapon_id in config.get("weapons", []):
		if weapon_defs.has(weapon_id):
			var weapon: Dictionary = weapon_defs[weapon_id].duplicate(true)
			weapon["id"] = weapon_id
			weapons.append(weapon)
			weapon_cooldowns[weapon_id] = 0.0
	_build_placeholder_ship()


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
	desired_range = 180.0


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
	var hardpoint_name := "WeaponHardpoint%02d" % (weapon_index + 1)
	projectile.position = global_position + _hardpoint_offset(hardpoint_name)
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


func _destroy() -> void:
	destroyed_flag = true
	velocity = Vector3.ZERO
	visible = false
	destroyed.emit(self)


func _build_placeholder_ship() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length: float = 5.6 if ship_class != "frigate" else 3.8
	box.size = Vector3(2.2, 0.8, length)
	body.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.55, 1.0) if faction == "player" else Color(1.0, 0.20, 0.20)
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.25
	body.material_override = material
	add_child(body)

	var engine_glow := MeshInstance3D.new()
	var engine_mesh := CylinderMesh.new()
	engine_mesh.top_radius = 0.28
	engine_mesh.bottom_radius = 0.28
	engine_mesh.height = 0.25
	engine_glow.mesh = engine_mesh
	engine_glow.position = Vector3(0, 0, length * 0.5 + 0.1)
	var engine_material := StandardMaterial3D.new()
	engine_material.albedo_color = Color(0.2, 0.8, 1.0)
	engine_material.emission_enabled = true
	engine_material.emission = Color(0.2, 0.8, 1.0)
	engine_glow.material_override = engine_material
	add_child(engine_glow)

	selection_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.4
	torus.outer_radius = 3.48
	selection_ring.mesh = torus
	selection_ring.rotation_degrees.x = 90
	selection_ring.visible = false
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.1, 1.0, 0.85)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.1, 1.0, 0.85)
	selection_ring.material_override = ring_material
	add_child(selection_ring)

	shield_flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.4
	shield_flash.mesh = sphere
	var shield_material := StandardMaterial3D.new()
	shield_material.albedo_color = Color(0.25, 0.65, 1.0, 0.16)
	shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_material.emission_enabled = true
	shield_material.emission = Color(0.25, 0.65, 1.0)
	shield_flash.material_override = shield_material
	shield_flash.visible = false
	add_child(shield_flash)

	for hardpoint_name in hardpoints.keys():
		var marker := Marker3D.new()
		marker.name = hardpoint_name
		marker.position = _array_to_vec3(hardpoints[hardpoint_name])
		add_child(marker)


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
	var marker := get_node_or_null(hardpoint_name)
	if marker is Marker3D:
		return marker.global_position - global_position
	return Vector3(0, 0.2, -2.4)


func _array_to_vec3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
