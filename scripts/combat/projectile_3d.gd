extends Node3D

var source: Variant
var target: Variant
var weapon: Dictionary = {}
var speed: float = 120.0
var life: float = 8.0
var hit_radius: float = 7.0


func setup(new_source: Variant, new_target: Variant, new_weapon: Dictionary) -> void:
	source = new_source
	target = new_target
	weapon = new_weapon.duplicate(true)
	speed = float(weapon.get("projectile_speed", 120))
	hit_radius = max(24.0, float(target.collision_radius) * 0.42) if target != null else hit_radius
	_build_visual()


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or target == null or target.destroyed_flag:
		queue_free()
		return
	var direction: Vector3 = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta
	if direction.length() > 0.0:
		look_at(global_position + direction, Vector3.UP)
	if global_position.distance_to(target.global_position) <= hit_radius:
		target.apply_damage(float(weapon.get("damage", 0)), source)
		_spawn_hit_flash()
		queue_free()


func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 18.0
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.75, 0.18)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.10)
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _spawn_hit_flash() -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = hit_radius * 0.45
	flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.15, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.08)
	flash.material_override = material
	var flash_parent := get_parent()
	if flash_parent == null:
		return
	flash_parent.add_child(flash)
	flash.global_position = global_position
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3(2.6, 2.6, 2.6), 0.18)
	tween.tween_callback(flash.queue_free)
