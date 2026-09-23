extends Node

## Saves flexible dictionaries. It never needs to know specific stat/resource
## names because PlayerState, ShipState, and WorldState own dynamic data.

const SAVE_PATH := "user://savegame.json"


func save_game() -> bool:
	var save_data := {
		"version": 1,
		"player": _singleton("PlayerState").to_dict(),
		"ship": _singleton("ShipState").to_dict(),
		"world": _singleton("WorldState").to_dict(),
		"chapter": _singleton("ChapterManager").to_dict()
	}
	return _singleton("DataManager").save_json(SAVE_PATH, save_data)


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var data: Variant = _singleton("DataManager").load_json(SAVE_PATH, {})
	if not (data is Dictionary):
		return false

	_singleton("PlayerState").from_dict(data.get("player", {}))
	_singleton("ShipState").from_dict(data.get("ship", {}))
	_singleton("WorldState").from_dict(data.get("world", {}))
	_singleton("ChapterManager").from_dict(data.get("chapter", {}))
	return true


func reset_game() -> void:
	_singleton("PlayerState").reset()
	_singleton("ShipState").reset()
	_singleton("WorldState").reset()
	_singleton("ChapterManager").current_chapter_path = ""
	_singleton("ChapterManager").current_chapter = {}
	_singleton("ChapterManager").events_by_id = {}
	_singleton("ChapterManager").current_event_id = ""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
