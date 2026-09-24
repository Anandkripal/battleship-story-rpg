class_name CombatModelCatalog
extends RefCounted

## Optional visual model resolver. Public code can reference visual model IDs
## without hard-linking ignored local asset packs into committed scenes.


static func get_entry(visual_model_id: String) -> Dictionary:
	if visual_model_id.is_empty():
		return {}
	var data_manager: Variant = _data_manager()
	if data_manager == null:
		return {}
	var catalog: Variant = data_manager.load_data_file("visual_models.json", {})
	if catalog is Dictionary:
		return catalog.get(visual_model_id, {})
	return {}


static func instantiate_model(visual_model_id: String) -> Node3D:
	var entry: Dictionary = get_entry(visual_model_id)
	if entry.is_empty():
		return null

	for path in _candidate_paths(entry):
		var node: Node3D = _instantiate_path(path)
		if node != null:
			_apply_transform(node, entry)
			return node
	return null


static func _candidate_paths(entry: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	var model_path: String = entry.get("model_path", "")
	if not model_path.is_empty():
		paths.append(model_path)
	for path in entry.get("optional_model_paths", []):
		if path is String and not path.is_empty():
			paths.append(path)
	return paths


static func _instantiate_path(path: String) -> Node3D:
	if path.is_empty():
		return null
	var resource: Resource = null
	if ResourceLoader.exists(path):
		resource = load(path)
	elif FileAccess.file_exists(path):
		resource = load(path)
	if resource == null:
		return null
	if resource is PackedScene:
		var scene_node: Node = resource.instantiate()
		if scene_node is Node3D:
			return scene_node
		scene_node.queue_free()
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource
		return mesh_instance
	return null


static func _apply_transform(node: Node3D, entry: Dictionary) -> void:
	node.scale = _array_to_vec3(entry.get("model_scale", [1, 1, 1]), Vector3.ONE)
	node.rotation_degrees = _array_to_vec3(entry.get("model_rotation_degrees", [0, 0, 0]), Vector3.ZERO)
	node.position = _array_to_vec3(entry.get("model_offset", [0, 0, 0]), Vector3.ZERO)


static func _array_to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


static func _data_manager() -> Variant:
	var tree: MainLoop = Engine.get_main_loop()
	if tree == null or not (tree is SceneTree):
		return null
	return tree.root.get_node_or_null("/root/DataManager")
