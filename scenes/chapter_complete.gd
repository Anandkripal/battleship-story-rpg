extends Control

var summary: Dictionary = {}


func setup(new_summary: Dictionary) -> void:
	summary = new_summary
	_build_ui()


func _ready() -> void:
	if summary.is_empty():
		_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.02, 0.05, 0.06)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var spacer_a := Control.new()
	spacer_a.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer_a)

	var title := Label.new()
	title.text = summary.get("title", "Chapter Complete")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	layout.add_child(title)

	var body := Label.new()
	body.text = summary.get("text", "The demo chapter is complete.")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(body)

	var menu := Button.new()
	menu.text = "Return to Main Menu"
	menu.custom_minimum_size = Vector2(0, 60)
	menu.pressed.connect(func() -> void: UIManager.show_main_menu())
	layout.add_child(menu)

	var spacer_b := Control.new()
	spacer_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer_b)
