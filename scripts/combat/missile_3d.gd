extends "res://scripts/combat/projectile_3d.gd"

var guidance_delay: float = 0.25
var age: float = 0.0
var acceleration: float = 900.0
var max_speed: float = 2600.0
var turn_rate: float = 1.8
var proximity_fuse_radius: float = 95.0


func setup(new_source: Variant, new_target: Variant, new_weapon: Dictionary) -> void:
	super.setup(new_source, new_target, new_weapon)
	guidance_delay = float(weapon.get("guidance_delay", 0.25))
	acceleration = float(weapon.get("acceleration", 900.0))
	max_speed = float(weapon.get("max_speed", 2600.0))
	turn_rate = float(weapon.get("turn_rate", 1.8))
	proximity_fuse_radius = float(weapon.get("proximity_fuse_radius", max(hit_radius, 95.0)))
	life = float(weapon.get("lifetime", 8.0))


func _process(delta: float) -> void:
	age += delta
	life -= delta
	if life <= 0.0 or target == null or target.destroyed_flag:
		_spawn_hit_flash()
		queue_free()
		return
	if age >= guidance_delay:
		var desired_direction: Vector3 = _guidance_direction()
		var current_direction: Vector3 = velocity.normalized()
		var new_direction: Vector3 = current_direction.slerp(desired_direction, clamp(turn_rate * delta, 0.0, 1.0)).normalized()
		var new_speed: float = min(max_speed, velocity.length() + acceleration * delta)
		velocity = new_direction * new_speed
	else:
		velocity += velocity.normalized() * acceleration * 0.35 * delta
	global_position += velocity * delta
	if velocity.length() > 0.0:
		look_at(global_position + velocity.normalized(), Vector3.UP)
	if global_position.distance_to(target.global_position) <= proximity_fuse_radius:
		target.apply_damage(float(weapon.get("damage", 0)), source)
		_spawn_hit_flash()
		queue_free()


func _guidance_direction() -> Vector3:
	if target == null:
		return velocity.normalized()
	var target_velocity: Vector3 = target.velocity
	var time_to_target: float = global_position.distance_to(target.global_position) / max(1.0, velocity.length())
	var aim_point: Vector3 = target.global_position + target_velocity * clamp(time_to_target, 0.0, 2.5)
	return (aim_point - global_position).normalized()


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 9.0
	mesh.bottom_radius = 9.0
	mesh.height = 60.0
	body.mesh = mesh
	body.rotation_degrees.x = 90
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.9, 0.95)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.55, 1.0)
	body.material_override = material
	add_child(body)

	var trail := MeshInstance3D.new()
	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = 5.0
	trail_mesh.bottom_radius = 18.0
	trail_mesh.height = 110.0
	trail.mesh = trail_mesh
	trail.position = Vector3(0, 0, 72.0)
	trail.rotation_degrees.x = 90
	var trail_material := StandardMaterial3D.new()
	trail_material.albedo_color = Color(0.2, 0.75, 1.0, 0.42)
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.emission_enabled = true
	trail_material.emission = Color(0.2, 0.65, 1.0)
	trail.material_override = trail_material
	add_child(trail)
