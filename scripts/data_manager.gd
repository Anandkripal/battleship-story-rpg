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
