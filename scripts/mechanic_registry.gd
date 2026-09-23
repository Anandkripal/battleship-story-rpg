extends Node

## Mechanics register by string ID. EventRunner calls this registry and does not
## need to know how scan, mining, battle, upgrade, or future mechanics work.

var mechanics: Dictionary = {}


func _ready() -> void:
	load_registered_mechanics()


func load_registered_mechanics() -> void:
	mechanics.clear()
	var data: Variant = _singleton("DataManager").load_json("res://data/mechanics.json", {})
	if not (data is Dictionary):
		return

	for mechanic_id in data.keys():
		var entry: Dictionary = data[mechanic_id]
		register_mechanic(mechanic_id, entry.get("scene", ""), entry)


func register_mechanic(mechanic_id: String, scene_path: String, metadata: Dictionary = {}) -> void:
	if mechanic_id.is_empty() or scene_path.is_empty():
		push_warning("Cannot register mechanic with empty ID or scene path.")
		return
	mechanics[mechanic_id] = {
		"scene": scene_path,
		"metadata": metadata
	}


func has_mechanic(mechanic_id: String) -> bool:
	return mechanics.has(mechanic_id)


func get_registered_ids() -> Array:
	return mechanics.keys()


func run_mechanic(mechanic_id: String, params: Dictionary = {}) -> Dictionary:
	if not mechanics.has(mechanic_id):
		return {
			"success": false,
			"error": "Unknown mechanic: %s" % mechanic_id
		}

	var scene_path: String = mechanics[mechanic_id]["scene"]
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return {
			"success": false,
			"error": "Missing mechanic scene: %s" % scene_path
		}

	var mechanic := packed.instantiate()
	await _singleton("UIManager").show_instance(mechanic)

	if mechanic.has_method("start"):
		mechanic.start(params)
	else:
		return {
			"success": false,
			"error": "Mechanic %s does not implement start(params)." % mechanic_id
		}

	var result: Variant = await mechanic.completed
	return result if result is Dictionary else {"success": false, "error": "Mechanic returned a non-dictionary result."}


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
