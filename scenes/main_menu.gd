extends Control


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.02, 0.04, 0.07)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 72)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Battleship Story RPG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Public demo framework"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	layout.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	_add_button(layout, "Start Demo Chapter", func() -> void: _singleton("EventRunner").start_demo_chapter())
	_add_button(layout, "Load Save", func() -> void: _singleton("EventRunner").continue_saved_game())
	_add_button(layout, "System Abilities", func() -> void: _singleton("UIManager").show_scene("res://scenes/system_screen.tscn"))
	_add_button(layout, "Validate Project", _show_validation)

	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(bottom)


func _add_button(parent: VBoxContainer, text: String, target: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.pressed.connect(target)
	parent.add_child(button)


func _show_validation() -> void:
	var report: String = _singleton("ValidationManager").validation_report()
	await _singleton("UIManager").show_story_event({
		"kind": "narration",
		"title": "Validation",
		"text": report,
		"next": ""
	})
	await _singleton("UIManager").show_main_menu()


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
