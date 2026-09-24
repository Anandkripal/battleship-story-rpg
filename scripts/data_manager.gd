extends Node

## Small JSON loader/saver used by data-driven systems.

func load_json(path: String, fallback: Variant = {}) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON file: %s" % path)
		return fallback

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open JSON file: %s" % path)
		return fallback

	var text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_warning("Invalid JSON in %s at line %s: %s" % [path, json.get_error_line(), json.get_error_message()])
		return fallback

	return json.data


func save_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write JSON file: %s" % path)
		return false

	file.store_string(JSON.stringify(value, "\t"))
	return true


func load_data_file(file_name: String, fallback: Variant = {}) -> Variant:
	var public_path := "res://data/%s" % file_name
	var public_data: Variant = load_json(public_path, fallback)
	if not (public_data is Dictionary):
		return public_data

	var merged: Dictionary = public_data.duplicate(true)
	for local_path in _local_data_paths(file_name):
		if FileAccess.file_exists(local_path):
			var local_data: Variant = load_json(local_path, {})
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
