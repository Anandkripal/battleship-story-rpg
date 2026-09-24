class_name ShipVisualWrapper
extends Node3D

## Visual-only ship wrapper. Combat logic owns movement, targeting, damage, and
## hardpoints; this node owns mesh presentation and can be replaced later.

const MODEL_CATALOG := preload("res://scripts/combat/model_catalog.gd")

@export var visual_model_id: String = ""
@export var fallback_shape: String = "warship"
@export var fallback_length: float = 120.0
@export var fallback_color: Color = Color(0.2, 0.55, 1.0)

var model_loaded := false


func setup(definition: Dictionary) -> void:
	if bool(definition.get("force_fallback_visuals", false)):
		visual_model_id = ""
	elif visual_model_id.is_empty():
		visual_model_id = definition.get("visual_model", "")
	fallback_shape = definition.get("fallback_shape", fallback_shape)
	fallback_length = float(definition.get("visual_length", fallback_length))
	if definition.has("fallback_color"):
		fallback_color = _array_to_color(definition["fallback_color"], fallback_color)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var loaded_model: Node3D = MODEL_CATALOG.instantiate_model(visual_model_id)
	if loaded_model != null:
		model_loaded = true
		add_child(loaded_model)
		return

	model_loaded = false
	_build_fallback()


func _build_fallback() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var width: float = max(10.0, fallback_length * 0.24)
	var height: float = max(4.0, fallback_length * 0.08)
	box.size = Vector3(width, height, fallback_length)
	body.mesh = box
	body.material_override = _material(fallback_color, fallback_color * 0.22)
	add_child(body)

	var nose := MeshInstance3D.new()
	var nose_mesh := PrismMesh.new()
	nose_mesh.size = Vector3(width * 0.82, height * 0.9, fallback_length * 0.22)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 0, -fallback_length * 0.58)
	nose.rotation_degrees.x = 90
	nose.material_override = _material(fallback_color.lightened(0.12), fallback_color * 0.18)
	add_child(nose)

	if fallback_shape in ["destroyer", "cruiser", "warship"]:
		var bridge := MeshInstance3D.new()
		var bridge_mesh := BoxMesh.new()
		bridge_mesh.size = Vector3(width * 0.45, height * 1.2, fallback_length * 0.18)
		bridge.mesh = bridge_mesh
		bridge.position = Vector3(0, height * 0.72, -fallback_length * 0.12)
		bridge.material_override = _material(fallback_color.lightened(0.18), fallback_color * 0.2)
		add_child(bridge)

	if fallback_shape == "cruiser":
		var spine := MeshInstance3D.new()
		var spine_mesh := BoxMesh.new()
		spine_mesh.size = Vector3(width * 0.18, height * 1.8, fallback_length * 0.76)
		spine.mesh = spine_mesh
		spine.position = Vector3(0, height * 1.2, 0)
		spine.material_override = _material(fallback_color.darkened(0.1), fallback_color * 0.18)
		add_child(spine)


func _material(albedo: Color, emission: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	return material


func _array_to_color(value: Variant, fallback: Color) -> Color:
	if value is Array and value.size() >= 3:
		var alpha := float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return fallback
