extends Node

## Generic chapter event runner. It knows event kinds, not gameplay systems.
## New gameplay mechanics are added through MechanicRegistry.

const DEMO_CHAPTER := "res://chapters/demo/chapter_001.json"


func start_demo_chapter() -> void:
	_singleton("SaveManager").reset_game()
	start_chapter(DEMO_CHAPTER)


func start_chapter(path: String) -> void:
	if not _singleton("ChapterManager").load_chapter(path):
		push_error("Could not start chapter: %s" % path)
		return
	_singleton("SaveManager").save_game()
	await continue_chapter()


func continue_saved_game() -> void:
	if not _singleton("SaveManager").load_game():
		await _singleton("UIManager").show_story_event({
			"kind": "narration",
			"title": "No Save Found",
			"text": "Start the demo chapter to create a save file.",
			"next": ""
		})
		await _singleton("UIManager").show_main_menu()
		return
	await continue_chapter()


func continue_chapter() -> void:
	var guard := 0
	while guard < 1000:
		var event: Dictionary = _singleton("ChapterManager").get_current_event()
		if event.is_empty():
			push_error("Missing event: %s" % _singleton("ChapterManager").current_event_id)
			await _singleton("UIManager").show_main_menu()
			return

		var next_event_id: String = await process_event(event)
		if next_event_id.is_empty():
			return

		_singleton("ChapterManager").set_current_event(next_event_id)
		_singleton("SaveManager").save_game()
		guard += 1

	push_error("Event loop guard reached. Check for a runaway chapter loop.")


func process_event(event: Dictionary) -> String:
	var kind: String = event.get("kind", "")

	match kind:
		"story", "narration", "choice":
			return await _singleton("UIManager").show_story_event(event)
		"mechanic":
			return await _run_mechanic_event(event)
		"reward":
			_singleton("StatePathUtil").apply_changes(event.get("changes", []))
			_singleton("SaveManager").save_game()
			if event.has("text") or event.has("title"):
				return await _singleton("UIManager").show_story_event(event)
			return event.get("next", "")
		"state_change":
			_singleton("StatePathUtil").apply_changes(event.get("changes", []))
			return event.get("next", "")
		"conditional":
			var passed: bool = _singleton("StatePathUtil").evaluate_condition(event.get("condition", {}))
			return event.get("true_next" if passed else "false_next", "")
		"jump":
			return event.get("next", "")
		"end":
			_singleton("StatePathUtil").apply_changes(event.get("changes", []))
			var chapter_id: String = _singleton("ChapterManager").current_chapter.get("id", _singleton("ChapterManager").current_chapter_path)
			if not chapter_id.is_empty():
				_singleton("StatePathUtil").apply_change({
					"path": "player.progress.completed_chapters.%s" % chapter_id,
					"operation": "set",
					"value": true
				})
			_singleton("SaveManager").save_game()
			await _singleton("UIManager").show_chapter_complete({
				"title": event.get("title", "Chapter Complete"),
				"text": event.get("text", "The chapter is complete.")
			})
			return ""
		_:
			push_error("Unknown event kind '%s' in event '%s'." % [kind, event.get("id", "<missing id>")])
			return ""


func _run_mechanic_event(event: Dictionary) -> String:
	var mechanic_id: String = event.get("mechanic", "")
	var result: Dictionary = await _singleton("MechanicRegistry").run_mechanic(mechanic_id, event.get("params", {}))
	_apply_mechanic_result(result)
	_singleton("SaveManager").save_game()

	if result.has("next"):
		return result["next"]
	return event.get("next", "")


func _apply_mechanic_result(result: Dictionary) -> void:
	_singleton("StatePathUtil").apply_changes(result.get("changes", []))

	var resources_found: Dictionary = result.get("resources_found", {})
	for resource_id in resources_found.keys():
		_singleton("StatePathUtil").apply_change({
			"path": "player.resources.%s" % resource_id,
			"operation": "add",
			"value": resources_found[resource_id]
		})


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
