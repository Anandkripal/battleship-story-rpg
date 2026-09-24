extends SceneTree

const REQUIRED_FILES := [
	"res://project.godot",
	"res://data/system_abilities.json",
	"res://data/scan_targets.json",
	"res://data/enemies.json",
	"res://data/upgrades.json",
	"res://data/locations.json",
	"res://data/mechanics.json",
	"res://assets/asset_manifest.json",
	"res://chapters/demo/chapter_001.json"
]


func _init() -> void:
	var errors: Array[String] = []
	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			errors.append("Missing required file: %s" % path)

	var manifest: Variant = _load_manifest(errors)
	var mechanics: Variant = _load_json("res://data/mechanics.json", errors)
	var chapter: Variant = _load_json("res://chapters/demo/chapter_001.json", errors)

	if mechanics is Dictionary:
		for mechanic_id in mechanics.keys():
			var scene_path: String = mechanics[mechanic_id].get("scene", "")
			if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
				errors.append("Mechanic '%s' references a missing scene: %s" % [mechanic_id, scene_path])

	if chapter is Dictionary:
		_validate_chapter(chapter, mechanics if mechanics is Dictionary else {}, manifest if manifest is Dictionary else {}, errors)

	if FileAccess.file_exists("res://chapters/private/chapter_001.json"):
		var private_chapter: Variant = _load_json("res://chapters/private/chapter_001.json", errors)
		if private_chapter is Dictionary:
			_validate_chapter(private_chapter, mechanics if mechanics is Dictionary else {}, manifest if manifest is Dictionary else {}, errors)

	if errors.is_empty():
		print("Validation passed.")
		quit(0)
		return

	print("Validation failed:")
	for error in errors:
		print("- %s" % error)
	quit(1)


func _load_json(path: String, errors: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Missing JSON file: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Could not open JSON file: %s" % path)
		return null

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		errors.append("Invalid JSON in %s at line %s: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _load_manifest(errors: Array[String]) -> Variant:
	var manifest: Variant = _load_json("res://assets/asset_manifest.json", errors)
	if not (manifest is Dictionary):
		return manifest

	var merged: Dictionary = manifest.duplicate(true)
	if FileAccess.file_exists("res://assets/asset_manifest.local.json"):
		var local_manifest: Variant = _load_json("res://assets/asset_manifest.local.json", errors)
		if local_manifest is Dictionary:
			_deep_merge(merged, local_manifest)
	return merged


func _load_data_file(file_name: String, errors: Array[String]) -> Variant:
	var public_data: Variant = _load_json("res://data/%s" % file_name, errors)
	if not (public_data is Dictionary):
		return public_data

	var merged: Dictionary = public_data.duplicate(true)
	for path in _local_data_paths(file_name):
		if FileAccess.file_exists(path):
			var local_data: Variant = _load_json(path, errors)
			if local_data is Dictionary:
				_deep_merge(merged, local_data)
	return merged


func _local_data_paths(file_name: String) -> Array[String]:
	var base_name := file_name.get_basename()
	var extension := file_name.get_extension()
	return [
		"res://data/private/%s.local.%s" % [base_name, extension],
		"res://data/local/%s.local.%s" % [base_name, extension]
	]


func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.get(key) is Dictionary and source[key] is Dictionary:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]


func _validate_chapter(chapter: Dictionary, mechanics: Dictionary, manifest: Dictionary, errors: Array[String]) -> void:
	var events: Array = chapter.get("events", [])
	var ids := {}

	for event in events:
		if not (event is Dictionary):
			errors.append("Chapter contains a non-dictionary event.")
			continue
		var event_id: String = event.get("id", "")
		if event_id.is_empty():
			errors.append("Chapter contains an event without an id.")
			continue
		if ids.has(event_id):
			errors.append("Duplicate event id: %s" % event_id)
		ids[event_id] = true

	for event in events:
		if event is Dictionary:
			_validate_event(event, ids, mechanics, manifest, errors)


func _validate_event(event: Dictionary, ids: Dictionary, mechanics: Dictionary, manifest: Dictionary, errors: Array[String]) -> void:
	var event_id: String = event.get("id", "<missing id>")
	if event.get("kind", "") == "mechanic":
		var mechanic_id: String = event.get("mechanic", "")
		if not mechanics.has(mechanic_id):
			errors.append("Event '%s' uses unknown mechanic '%s'." % [event_id, mechanic_id])
		_validate_mechanic_params(event, event_id, errors)

	_check_ref(event.get("next", ""), event_id, ids, errors)
	if event.get("kind", "") == "conditional":
		_check_ref(event.get("true_next", ""), event_id, ids, errors)
		_check_ref(event.get("false_next", ""), event_id, ids, errors)
		_check_path(event.get("condition", {}).get("path", ""), event_id, errors)

	for choice in event.get("choices", []):
		if choice is Dictionary:
			_check_ref(choice.get("next", ""), event_id, ids, errors)

	for change in event.get("changes", []):
		if change is Dictionary:
			_check_path(change.get("path", ""), event_id, errors)

	for asset_key in ["asset", "background", "foreground", "portrait"]:
		if event.has(asset_key) and not manifest.has(event[asset_key]):
			errors.append("Event '%s' references missing manifest asset '%s'." % [event_id, event[asset_key]])

	for panel_id in event.get("panels", []):
		if not manifest.has(panel_id):
			errors.append("Event '%s' references missing manifest panel asset '%s'." % [event_id, panel_id])


func _validate_mechanic_params(event: Dictionary, event_id: String, errors: Array[String]) -> void:
	var mechanic_id: String = event.get("mechanic", "")
	var params: Dictionary = event.get("params", {})
	match mechanic_id:
		"scan":
			var target_id: String = params.get("target", "")
			var scan_targets: Variant = _load_data_file("scan_targets.json", errors)
			if target_id.is_empty() or not (scan_targets is Dictionary and scan_targets.has(target_id)):
				errors.append("Event '%s' references missing scan target '%s'." % [event_id, target_id])
		"map":
			var location_id: String = params.get("location", "")
			if not location_id.is_empty():
				var locations: Variant = _load_data_file("locations.json", errors)
				if not (locations is Dictionary and locations.has(location_id)):
					errors.append("Event '%s' references missing location '%s'." % [event_id, location_id])


func _check_ref(next_id: String, event_id: String, ids: Dictionary, errors: Array[String]) -> void:
	if not next_id.is_empty() and not ids.has(next_id):
		errors.append("Event '%s' references missing next event '%s'." % [event_id, next_id])


func _check_path(path: String, event_id: String, errors: Array[String]) -> void:
	var parts := path.split(".")
	if parts.size() < 2 or not ["player", "ship", "world"].has(parts[0]) or parts.has(""):
		errors.append("Event '%s' has invalid state path '%s'." % [event_id, path])
