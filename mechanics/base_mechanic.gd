class_name BaseMechanic
extends Control

## Common mechanic interface.
##
## To add a mechanic:
## 1. Create a scene/script extending BaseMechanic.
## 2. Implement start(params: Dictionary).
## 3. Emit completed(result: Dictionary) when finished.
## 4. Register the scene in data/mechanics.json.
##
## EventRunner does not need to change for new mechanics.

signal completed(result: Dictionary)

var params: Dictionary = {}


func start(new_params: Dictionary) -> void:
	params = new_params


func finish(result: Dictionary) -> void:
	completed.emit(result)


func set_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_font_size_override("font_size", 24)
	return button
