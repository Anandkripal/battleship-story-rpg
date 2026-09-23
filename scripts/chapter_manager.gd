extends Node

## Loads chapter JSON and keeps the current event pointer.

var current_chapter_path := ""
var current_chapter: Dictionary = {}
var events_by_id: Dictionary = {}
var current_event_id := ""


func load_chapter(path: String) -> bool:
	var data: Variant = _singleton("DataManager").load_json(path, {})
	if not (data is Dictionary):
		push_error("Chapter is not a dictionary: %s" % path)
		return false

	current_chapter_path = path
	current_chapter = data
	events_by_id.clear()

	for event in current_chapter.get("events", []):
		if event is Dictionary and event.has("id"):
			events_by_id[event["id"]] = event

	current_event_id = current_chapter.get("start_event", "")
	if current_event_id.is_empty() and not events_by_id.is_empty():
		current_event_id = events_by_id.keys()[0]

	return not current_event_id.is_empty()


func get_current_event() -> Dictionary:
	return events_by_id.get(current_event_id, {})


func get_event(event_id: String) -> Dictionary:
	return events_by_id.get(event_id, {})


func set_current_event(event_id: String) -> void:
	current_event_id = event_id


func to_dict() -> Dictionary:
	return {
		"chapter_path": current_chapter_path,
		"event_id": current_event_id
	}


func from_dict(data: Dictionary) -> bool:
	var chapter_path: String = data.get("chapter_path", "")
	if chapter_path.is_empty():
		return false
	if not load_chapter(chapter_path):
		return false
	current_event_id = data.get("event_id", current_event_id)
	return true


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
