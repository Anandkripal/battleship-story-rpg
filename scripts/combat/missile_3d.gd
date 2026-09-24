extends "res://scripts/combat/projectile_3d.gd"


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
