extends Control


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.018, 0.033, 0.052)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 52)
	margin.add_theme_constant_override("margin_bottom", 52)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)

	var title_panel := PanelContainer.new()
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_panel.size_flags_stretch_ratio = 1.3
	row.add_child(title_panel)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 18)
	title_panel.add_child(title_box)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_box.add_child(spacer_top)

	var title := Label.new()
	title.text = "Battleship Story RPG"
	title.add_theme_font_size_override("font_size", 46)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Landscape public demo framework"
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(subtitle)

	var details := Label.new()
	details.text = "Story, progression, battleship upgrades, exploration, and modular mechanics."
	details.add_theme_font_size_override("font_size", 24)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(details)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_box.add_child(spacer_bottom)

	var actions_panel := PanelContainer.new()
	actions_panel.custom_minimum_size = Vector2(380, 0)
	row.add_child(actions_panel)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	actions_panel.add_child(actions)

	var actions_title := Label.new()
	actions_title.text = "Command"
	actions_title.add_theme_font_size_override("font_size", 34)
	actions.add_child(actions_title)

	var action_spacer := Control.new()
	action_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)

	_add_button(actions, "Start Demo Chapter", func() -> void: _singleton("EventRunner").start_demo_chapter())
	_add_private_chapter_buttons(actions)
	_add_button(actions, "Load Save", func() -> void: _singleton("EventRunner").continue_saved_game())
	_add_button(actions, "System Abilities", func() -> void: _singleton("UIManager").show_scene("res://scenes/system_screen.tscn"))
	_add_button(actions, "Validate Project", _show_validation)

	var action_bottom := Control.new()
	action_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(action_bottom)


func _add_button(parent: VBoxContainer, text: String, target: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(target)
	parent.add_child(button)
	return button


func _add_private_chapter_buttons(actions: VBoxContainer) -> void:
	for chapter_number in range(1, 6):
		var chapter_path: String = "res://chapters/private/chapter_%03d.json" % chapter_number
		if not FileAccess.file_exists(chapter_path):
			continue
		var chapter_id: String = "private:chapter_%03d" % chapter_number
		var previous_id: String = "private:chapter_%03d" % (chapter_number - 1)
		var unlocked: bool = chapter_number == 1 or _singleton("SaveManager").saved_chapter_completed(previous_id)
		var label: String = "Private Chapter %s" % chapter_number
		var button := _add_button(actions, label, func() -> void: _singleton("EventRunner").start_chapter(chapter_path))
		button.disabled = not unlocked
		if not unlocked:
			button.text = "%s (Locked)" % label
			_add_button(actions, "%s (Dev)" % label, func() -> void: _singleton("EventRunner").start_chapter(chapter_path))


func _show_validation() -> void:
	var report: String = _singleton("ValidationManager").validation_report()
	await _singleton("UIManager").show_story_event({
		"kind": "narration",
		"layout": "side_dialogue",
		"text": report,
		"title": "Validation",
		"next": ""
	})
	await _singleton("UIManager").show_main_menu()


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
