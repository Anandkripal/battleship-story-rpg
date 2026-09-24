extends "res://mechanics/base_mechanic.gd"

var asteroid_data: Array = []
var resources_found: Dictionary = {}
var scans_remaining := 3
var log_label: Label
var resource_label: Label


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	asteroid_data = params.get("asteroids", [
		{"quality": "Common", "resource": "iron_ore", "value": 2},
		{"quality": "Rare", "resource": "crystal_ore", "value": 5},
		{"quality": "Trace", "resource": "source_points", "value": 1},
		{"quality": "Common", "resource": "iron_ore", "value": 1},
		{"quality": "Dense", "resource": "iron_ore", "value": 4},
		{"quality": "Bright", "resource": "crystal_ore", "value": 3}
	])
	scans_remaining = params.get("scans", 3)
	resources_found.clear()
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.045, 0.038, 0.070)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	var field_panel := PanelContainer.new()
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field_panel)

	var field := GridContainer.new()
	field.columns = 3
	field.add_theme_constant_override("h_separation", 16)
	field.add_theme_constant_override("v_separation", 16)
	field_panel.add_child(field)

	for index in range(asteroid_data.size()):
		var button := make_button("Unscanned\nAsteroid")
		button.custom_minimum_size = Vector2(0, 150)
		button.pressed.connect(func() -> void: _scan_asteroid(index, button))
		field.add_child(button)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size = Vector2(340, 0)
	row.add_child(status_panel)

	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 16)
	status_panel.add_child(status)

	var title := Label.new()
	title.text = "ASTEROID FIELD"
	title.add_theme_font_size_override("font_size", 34)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(title)

	log_label = Label.new()
	log_label.text = "Tap asteroids to scan.\nScans remaining: %s" % scans_remaining
	log_label.add_theme_font_size_override("font_size", 25)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(log_label)

	resource_label = Label.new()
	resource_label.text = "Resources found:\nNone yet"
	resource_label.add_theme_font_size_override("font_size", 24)
	resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.add_child(resource_label)

	var finish_button := make_button("Finish Mining Run")
	finish_button.pressed.connect(_finish_mining)
	status.add_child(finish_button)


func _scan_asteroid(index: int, button: Button) -> void:
	if scans_remaining <= 0 or button.disabled:
		return

	var data: Dictionary = asteroid_data[index]
	scans_remaining -= 1
	button.disabled = true
	button.text = "%s\n%s +%s" % [data.get("quality", "Unknown"), data.get("resource", "unknown"), data.get("value", 0)]
	var resource_id: String = data.get("resource", "unknown")
	resources_found[resource_id] = resources_found.get(resource_id, 0) + int(data.get("value", 0))
	log_label.text = "Scan complete.\nScans remaining: %s" % scans_remaining
	resource_label.text = "Resources found:\n%s" % _format_resources()


func _format_resources() -> String:
	if resources_found.is_empty():
		return "None yet"
	var lines: Array[String] = []
	for resource_id in resources_found.keys():
		lines.append("%s: %s" % [resource_id, resources_found[resource_id]])
	return "\n".join(lines)


func _finish_mining() -> void:
	finish({
		"success": true,
		"resources_found": resources_found,
		"changes": [
			{
				"path": "world.flags.completed_training_mining",
				"operation": "set",
				"value": true
			}
		]
	})
