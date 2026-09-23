extends Node

## Saves flexible dictionaries. It never needs to know specific stat/resource
## names because PlayerState, ShipState, and WorldState own dynamic data.

const SAVE_PATH := "user://savegame.json"


func save_game() -> bool:
	var save_data := {
		"version": 1,
		"player": PlayerState.to_dict(),
		"ship": ShipState.to_dict(),
		"world": WorldState.to_dict(),
		"chapter": ChapterManager.to_dict()
	}
	return DataManager.save_json(SAVE_PATH, save_data)


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var data: Variant = DataManager.load_json(SAVE_PATH, {})
	if not (data is Dictionary):
		return false

	PlayerState.from_dict(data.get("player", {}))
	ShipState.from_dict(data.get("ship", {}))
	WorldState.from_dict(data.get("world", {}))
	ChapterManager.from_dict(data.get("chapter", {}))
	return true


func reset_game() -> void:
	PlayerState.reset()
	ShipState.reset()
	WorldState.reset()
	ChapterManager.current_chapter_path = ""
	ChapterManager.current_chapter = {}
	ChapterManager.events_by_id = {}
	ChapterManager.current_event_id = ""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
