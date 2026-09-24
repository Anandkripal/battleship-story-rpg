extends Node3D


func _ready() -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 4.0
	flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.35, 0.08, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.25, 0.05)
	flash.material_override = material
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3(3.0, 3.0, 3.0), 0.35)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
