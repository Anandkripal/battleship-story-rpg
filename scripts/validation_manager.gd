extends Node

## Human-readable validation for public demo data and project wiring.

const REQUIRED_FILES := [
	"res://project.godot",
	"res://data/system_abilities.json",
	"res://data/scan_targets.json",
	"res://data/enemies.json",
	"res://data/upgrades.json",
	"res://data/locations.json",
	"res://data/mechanics.json",
	"res://assets/asset_manifest.json",
	"res://chapters/demo/chapter_001.json",
	"res://scenes/main_menu.tscn",
	"res://scenes/story_viewer.tscn",
	"res://scenes/system_screen.tscn",
	"res://scenes/star_map.tscn",
	"res://scenes/chapter_complete.tscn"
]


func validate_project() -> Array:
	var errors: Array = []

	for path in REQUIRED_FILES:
		if not FileAccess.file_exists(path):
			errors.append("Missing required file: %s" % path)

	var mechanics: Variant = _load_json_checked("res://data/mechanics.json", errors)
	if mechanics is Dictionary:
		for mechanic_id in mechanics.keys():
			var scene_path: String = mechanics[mechanic_id].get("scene", "")
			if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
				errors.append("Mechanic '%s' references a missing scene: %s" % [mechanic_id, scene_path])

	var chapter: Variant = _load_json_checked("res://chapters/demo/chapter_001.json", errors)
	if chapter is Dictionary:
		_validate_chapter(chapter, mechanics if mechanics is Dictionary else {}, errors)

	for private_chapter_path in _private_chapter_paths():
		errors.append_array(validate_chapter_path(private_chapter_path))

	return errors


func validate_chapter_path(path: String) -> Array:
	var errors: Array = []
	var mechanics: Variant = _load_json_checked("res://data/mechanics.json", errors)
	var chapter: Variant = _load_json_checked(path, errors)
	if chapter is Dictionary:
		_validate_chapter(chapter, mechanics if mechanics is Dictionary else {}, errors)
	return errors


func validation_report() -> String:
	var errors := validate_project()
	if errors.is_empty():
		return "Validation passed."
	return "Validation found %s issue(s):\n- %s" % [errors.size(), "\n- ".join(errors)]


func _load_json_checked(path: String, errors: Array) -> Variant:
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


func _private_chapter_paths() -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open("res://chapters/private")
	if directory == null:
		return paths

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "json":
			paths.append("res://chapters/private/%s" % file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths


func _validate_chapter(chapter: Dictionary, mechanics: Dictionary, errors: Array) -> void:
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
		if not (event is Dictionary):
			continue
		_validate_event(event, ids, mechanics, errors)


func _validate_event(event: Dictionary, ids: Dictionary, mechanics: Dictionary, errors: Array) -> void:
	var event_id: String = event.get("id", "<missing id>")
	var kind: String = event.get("kind", "")

	if kind == "mechanic":
		var mechanic_id: String = event.get("mechanic", "")
		if not mechanics.has(mechanic_id):
			errors.append("Event '%s' uses unknown mechanic '%s'." % [event_id, mechanic_id])
		_validate_mechanic_params(event, event_id, errors)

	if kind == "conditional":
		_validate_state_path(event.get("condition", {}).get("path", ""), event_id, errors)
		_check_ref(event.get("true_next", ""), event_id, ids, errors)
		_check_ref(event.get("false_next", ""), event_id, ids, errors)

	if kind == "chapter_boundary":
		for change in event.get("changes", []):
			if change is Dictionary:
				_validate_state_path(change.get("path", ""), event_id, errors)
		var continue_chapter: String = event.get("continue_chapter", "")
		if not continue_chapter.is_empty():
			if not FileAccess.file_exists(continue_chapter):
				errors.append("Event '%s' continues to missing chapter '%s'." % [event_id, continue_chapter])
			else:
				_validate_continue_event(event, event_id, continue_chapter, errors)

	_check_ref(event.get("next", ""), event_id, ids, errors)

	for choice in event.get("choices", []):
		if choice is Dictionary:
			_check_ref(choice.get("next", ""), event_id, ids, errors)

	for change in event.get("changes", []):
		if change is Dictionary:
			_validate_state_path(change.get("path", ""), event_id, errors)

	for asset_key in ["asset", "background", "foreground", "portrait"]:
		if event.has(asset_key):
			_validate_asset(event[asset_key], event_id, errors)

	for panel_id in event.get("panels", []):
		_validate_asset(panel_id, event_id, errors)


func _validate_mechanic_params(event: Dictionary, event_id: String, errors: Array) -> void:
	var mechanic_id: String = event.get("mechanic", "")
	var params: Dictionary = event.get("params", {})
	match mechanic_id:
		"scan":
			var target_id: String = params.get("target", "")
			var scan_targets: Variant = _singleton("DataManager").load_data_file("scan_targets.json", {})
			if target_id.is_empty() or not (scan_targets is Dictionary and scan_targets.has(target_id)):
				errors.append("Event '%s' references missing scan target '%s'." % [event_id, target_id])
		"map":
			var preferred_location: String = params.get("location", "")
			if not preferred_location.is_empty():
				var locations: Variant = _singleton("DataManager").load_data_file("locations.json", {})
				if not (locations is Dictionary and locations.has(preferred_location)):
					errors.append("Event '%s' references missing location '%s'." % [event_id, preferred_location])
		"battle":
			var enemy_id: String = params.get("enemy", "")
			var enemies: Variant = _singleton("DataManager").load_data_file("enemies.json", {})
			if enemy_id.is_empty() or not (enemies is Dictionary and enemies.has(enemy_id)):
				errors.append("Event '%s' references missing enemy '%s'." % [event_id, enemy_id])


func _validate_continue_event(event: Dictionary, event_id: String, continue_chapter: String, errors: Array) -> void:
	var continue_event: String = event.get("continue_event", "")
	if continue_event.is_empty():
		return

	var next_chapter: Variant = _load_json_checked(continue_chapter, errors)
	if not (next_chapter is Dictionary):
		return

	var found := false
	for next_event in next_chapter.get("events", []):
		if next_event is Dictionary and next_event.get("id", "") == continue_event:
			found = true
			break
	if not found:
		errors.append("Event '%s' continues to missing event '%s' in '%s'." % [event_id, continue_event, continue_chapter])


func _check_ref(next_id: String, event_id: String, ids: Dictionary, errors: Array) -> void:
	if next_id.is_empty():
		return
	if not ids.has(next_id):
		errors.append("Event '%s' references missing next event '%s'." % [event_id, next_id])


func _validate_state_path(path: String, event_id: String, errors: Array) -> void:
	if not _singleton("StatePathUtil").is_valid_state_path(path):
		errors.append("Event '%s' has invalid state path '%s'." % [event_id, path])


func _validate_asset(asset_id: String, event_id: String, errors: Array) -> void:
	if not _singleton("AssetManifestManager").has_asset(asset_id):
		errors.append("Event '%s' references missing manifest asset '%s'." % [event_id, asset_id])


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
