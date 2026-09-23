extends "res://mechanics/base_mechanic.gd"

var asteroid_data: Array = []
var resources_found: Dictionary = {}
var scans_remaining := 3
var log_label: Label


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	asteroid_data = params.get("asteroids", [
		{"quality": "Common", "resource": "iron_ore", "value": 2},
		{"quality": "Rare", "resource": "crystal_ore", "value": 5},
		{"quality": "Trace", "resource": "source_points", "value": 1},
		{"quality": "Common", "resource": "iron_ore", "value": 1}
	])
	scans_remaining = params.get("scans", 3)
	resources_found.clear()
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.06, 0.05, 0.09)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Asteroid Field"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	log_label = Label.new()
	log_label.text = "Tap asteroids to scan. Scans remaining: %s" % scans_remaining
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(log_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(grid)

	for index in range(asteroid_data.size()):
		var button := make_button("Unscanned Asteroid")
		button.custom_minimum_size = Vector2(0, 120)
		button.pressed.connect(func() -> void: _scan_asteroid(index, button))
		grid.add_child(button)

	var finish_button := make_button("Finish Mining Run")
	finish_button.pressed.connect(_finish_mining)
	layout.add_child(finish_button)


func _scan_asteroid(index: int, button: Button) -> void:
	if scans_remaining <= 0 or button.disabled:
		return

	var data: Dictionary = asteroid_data[index]
	scans_remaining -= 1
	button.disabled = true
	button.text = "%s\n%s +%s" % [data.get("quality", "Unknown"), data.get("resource", "unknown"), data.get("value", 0)]
	var resource_id: String = data.get("resource", "unknown")
	resources_found[resource_id] = resources_found.get(resource_id, 0) + int(data.get("value", 0))
	log_label.text = "Scan complete. Scans remaining: %s" % scans_remaining


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
