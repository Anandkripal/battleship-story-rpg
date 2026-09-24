extends "res://mechanics/base_mechanic.gd"

var target_id := ""
var target_data: Dictionary = {}


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	target_id = params.get("target", "")
	var targets: Variant = _singleton("DataManager").load_json("res://data/scan_targets.json", {})
	target_data = targets.get(target_id, {}) if targets is Dictionary else {}
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.025, 0.055, 0.075)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	var visual := PanelContainer.new()
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual.size_flags_stretch_ratio = 0.9
	row.add_child(visual)

	var visual_stack := VBoxContainer.new()
	visual_stack.add_theme_constant_override("separation", 16)
	visual.add_child(visual_stack)

	var title := Label.new()
	title.text = "SCAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	visual_stack.add_child(title)

	var ship_art := Label.new()
	ship_art.text = "\n      /\\\n ____/  \\____\n<____________>\n    /____\\\n"
	ship_art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_art.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ship_art.add_theme_font_size_override("font_size", 32)
	ship_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_stack.add_child(ship_art)

	var details := PanelContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 1.1
	row.add_child(details)

	var detail_stack := VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 14)
	details.add_child(detail_stack)

	var name := Label.new()
	name.text = target_data.get("name", "Unknown Target")
	name.add_theme_font_size_override("font_size", 38)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_stack.add_child(name)

	var body := RichTextLabel.new()
	body.fit_content = false
	body.bbcode_enabled = false
	body.text = _format_dictionary(target_data if not target_data.is_empty() else {"error": "Unknown target", "id": target_id})
	body.add_theme_font_size_override("normal_font_size", 25)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_child(body)

	var complete := make_button("Complete Scan")
	complete.pressed.connect(_complete_scan)
	detail_stack.add_child(complete)


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


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
