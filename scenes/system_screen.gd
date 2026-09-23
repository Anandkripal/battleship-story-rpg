extends Control


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.05, 0.06)
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
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "System Abilities"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	var data: Variant = DataManager.load_json("res://data/system_abilities.json", {})
	for ability_id in (data.keys() if data is Dictionary else []):
		var ability: Dictionary = data[ability_id]
		var button := Button.new()
		button.text = "%s\nLevel: %s  Status: %s" % [
			ability.get("name", ability_id),
			ability.get("level", "-"),
			"Unlocked" if ability.get("unlocked", false) else "Locked"
		]
		button.disabled = not ability.get("unlocked", false)
		button.custom_minimum_size = Vector2(0, 74)
		layout.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 58)
	back.pressed.connect(func() -> void: UIManager.show_main_menu())
	layout.add_child(back)
