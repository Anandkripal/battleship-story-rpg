extends Node

## Resolves manifest IDs to resource paths. A local manifest may extend or
## override the public manifest, but that local file is ignored by Git.

const PUBLIC_MANIFEST := "res://assets/asset_manifest.json"
const LOCAL_MANIFEST := "res://assets/asset_manifest.local.json"

var manifest: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	manifest.clear()
	var public_data: Variant = DataManager.load_json(PUBLIC_MANIFEST, {})
	if public_data is Dictionary:
		manifest.merge(public_data, true)

	if FileAccess.file_exists(LOCAL_MANIFEST):
		var local_data: Variant = DataManager.load_json(LOCAL_MANIFEST, {})
		if local_data is Dictionary:
			manifest.merge(local_data, true)


func has_asset(asset_id: String) -> bool:
	return manifest.has(asset_id)


func resolve(asset_id: String) -> String:
	if not manifest.has(asset_id):
		push_warning("Unknown asset manifest ID: %s" % asset_id)
		return ""
	return manifest[asset_id].get("file", "")


func get_entry(asset_id: String) -> Dictionary:
	return manifest.get(asset_id, {})
