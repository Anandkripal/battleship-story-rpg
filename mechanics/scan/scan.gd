extends "res://mechanics/base_mechanic.gd"

var target_id := ""
var target_data: Dictionary = {}


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	target_id = params.get("target", "")
	var targets: Variant = DataManager.load_json("res://data/scan_targets.json", {})
	target_data = targets.get(target_id, {}) if targets is Dictionary else {}
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.03, 0.07, 0.10)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Scan Result"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	var body := RichTextLabel.new()
	body.fit_content = true
	body.bbcode_enabled = false
	body.text = _format_dictionary(target_data if not target_data.is_empty() else {"error": "Unknown target", "id": target_id})
	layout.add_child(body)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var complete := make_button("Complete Scan")
	complete.pressed.connect(_complete_scan)
	layout.add_child(complete)


func _complete_scan() -> void:
	finish({
		"success": not target_data.is_empty(),
		"scanned_target": target_id,
		"changes": [
			{
				"path": "world.flags.scanned_%s" % target_id,
				"operation": "set",
				"value": true
			}
		]
	})


func _format_dictionary(data: Dictionary, indent: int = 0) -> String:
	var lines: Array[String] = []
	for key in data.keys():
		var value: Variant = data[key]
		var prefix := "  ".repeat(indent) + str(key).capitalize().replace("_", " ")
		if value is Dictionary:
			lines.append("%s:" % prefix)
			lines.append(_format_dictionary(value, indent + 1))
		elif value is Array:
			lines.append("%s: %s" % [prefix, ", ".join(value)])
		else:
			lines.append("%s: %s" % [prefix, str(value)])
	return "\n".join(lines)
