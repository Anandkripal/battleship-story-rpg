extends Node

## Owns scene swaps and small shared UI flows.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const STORY_VIEWER_SCENE := "res://scenes/story_viewer.tscn"
const CHAPTER_COMPLETE_SCENE := "res://scenes/chapter_complete.tscn"


func show_main_menu() -> void:
	await show_scene(MAIN_MENU_SCENE)


func show_scene(scene_path: String, payload: Dictionary = {}) -> Node:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("Missing scene: %s" % scene_path)
		return null
	var instance := packed.instantiate()
	await show_instance(instance, payload)
	return instance


func show_instance(instance: Node, payload: Dictionary = {}) -> Node:
	var tree := get_tree()
	if tree.current_scene != null:
		tree.current_scene.queue_free()

	tree.root.add_child(instance)
	tree.current_scene = instance
	await tree.process_frame

	if instance.has_method("setup"):
		instance.setup(payload)
	return instance


func show_story_event(event: Dictionary) -> Variant:
	var node := await show_scene(STORY_VIEWER_SCENE)
	if node == null:
		return event.get("next", "")
	node.setup_event(event)
	return await node.completed


func show_chapter_complete(summary: Dictionary = {}) -> void:
	var node := await show_scene(CHAPTER_COMPLETE_SCENE)
	if node != null and node.has_method("setup"):
		node.setup(summary)
