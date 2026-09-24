extends Control

signal completed(next_id: String)

const MARGIN := 34
const GAP := 20

var current_event: Dictionary = {}


func setup_event(event: Dictionary) -> void:
	current_event = event
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_color_layer(Color(0.015, 0.025, 0.04))

	var layout_mode: String = current_event.get("layout", _default_layout_for_event())
	match layout_mode:
		"side_dialogue", "split":
			_build_side_dialogue()
		"full_art":
			_build_full_art()
		"cinematic":
			_build_cinematic()
		_:
			_build_bottom_dialogue()

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.16)


func _build_bottom_dialogue() -> void:
	_add_art_background(true)

	var root := _screen_margin()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", GAP)
	root.add_child(stack)

	var art_space := Control.new()
	art_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(art_space)

	var panel := _dialogue_panel()
	panel.custom_minimum_size = Vector2(0, 210)
	stack.add_child(panel)
	_fill_dialogue_panel(panel, false)


func _build_side_dialogue() -> void:
	_add_optional_blur_background()

	var root := _screen_margin()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	root.add_child(row)

	var art_width := 0.64 if current_event.get("image_position", "left") != "center" else 0.56
	var art := _create_art_view(current_event.get("display_mode", "fit"))
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = art_width

	var panel := _dialogue_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0 - art_width
	_fill_dialogue_panel(panel, true)

	if current_event.get("image_position", "left") == "right":
		row.add_child(panel)
		row.add_child(art)
	else:
		row.add_child(art)
		row.add_child(panel)


func _build_full_art() -> void:
	_add_art_background(true)

	var root := _screen_margin()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	root.add_child(stack)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_END
	stack.add_child(controls)
	_add_continue_or_choices(controls, true)


func _build_cinematic() -> void:
	_add_art_background(true)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.72)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 54)
	add_child(top_bar)

	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.12
	bottom_panel.anchor_right = 0.88
	bottom_panel.anchor_top = 0.70
	bottom_panel.anchor_bottom = 0.96
	bottom_panel.offset_left = 0
	bottom_panel.offset_right = 0
	bottom_panel.offset_top = 0
	bottom_panel.offset_bottom = 0
	add_child(bottom_panel)
	_fill_dialogue_panel(bottom_panel, false)


func _screen_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	return margin


func _dialogue_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("content_margin_left", 24)
	panel.add_theme_constant_override("content_margin_right", 24)
	panel.add_theme_constant_override("content_margin_top", 20)
	panel.add_theme_constant_override("content_margin_bottom", 20)
	return panel


func _fill_dialogue_panel(panel: PanelContainer, vertical_buttons: bool) -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var title_text: String = current_event.get("title", current_event.get("speaker", ""))
	if not title_text.is_empty():
		var title := Label.new()
		title.text = title_text
		title.add_theme_font_size_override("font_size", 32)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(title)

	var body := Label.new()
	body.text = current_event.get("text", current_event.get("dialogue", current_event.get("narration", "")))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	var button_container: BoxContainer
	if vertical_buttons:
		button_container = VBoxContainer.new()
	else:
		button_container = HBoxContainer.new()
		button_container.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_theme_constant_override("separation", 12)
	content.add_child(button_container)
	_add_continue_or_choices(button_container, not vertical_buttons)


func _add_continue_or_choices(parent: BoxContainer, compact: bool) -> void:
	if current_event.get("kind", "") == "choice":
		for choice in current_event.get("choices", []):
			if choice is Dictionary:
				var choice_button := _story_button(choice.get("text", "Continue"), compact)
				choice_button.pressed.connect(func() -> void: completed.emit(choice.get("next", "")))
				parent.add_child(choice_button)
	else:
		var button := _story_button(current_event.get("button_text", "Continue"), compact)
		button.pressed.connect(func() -> void: completed.emit(current_event.get("next", "")))
		parent.add_child(button)


func _story_button(text: String, compact: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220 if compact else 0, 62)
	button.add_theme_font_size_override("font_size", 24)
	return button


func _create_art_view(display_mode: String) -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_constant_override("content_margin_left", 0)
	frame.add_theme_constant_override("content_margin_right", 0)
	frame.add_theme_constant_override("content_margin_top", 0)
	frame.add_theme_constant_override("content_margin_bottom", 0)

	var texture := _load_event_texture()
	if texture == null:
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.04, 0.07, 0.10)
		frame.add_child(placeholder)
		return frame

	if display_mode == "panel_sequence":
		frame.add_child(_create_panel_sequence(texture))
		return frame

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = _display_mode_to_stretch(display_mode)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(rect)
	return frame


func _create_panel_sequence(texture: Texture2D) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panels: Array = current_event.get("panels", [])
	var count: int = max(1, panels.size())
	for index in range(count):
		var rect := TextureRect.new()
		var panel_texture: Texture2D = texture
		if not panels.is_empty():
			panel_texture = load(_singleton("AssetManifestManager").resolve(panels[index]))
		rect.texture = panel_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(rect)
	return row


func _add_art_background(add_overlay: bool) -> void:
	var texture := _load_event_texture()
	if texture == null:
		return

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = _display_mode_to_stretch(current_event.get("display_mode", current_event.get("image_mode", "crop")))
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)

	if add_overlay:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.22)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade)


func _add_optional_blur_background() -> void:
	if current_event.get("display_mode", "") != "background_blur":
		_add_color_layer(Color(0.015, 0.025, 0.04))
		return

	_add_art_background(false)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _add_color_layer(color: Color) -> void:
	var layer := ColorRect.new()
	layer.color = color
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)


func _load_event_texture() -> Texture2D:
	var asset_id: String = current_event.get("asset", current_event.get("background", ""))
	if asset_id.is_empty():
		return null

	var path: String = _singleton("AssetManifestManager").resolve(asset_id)
	if path.is_empty():
		return null
	return load(path)


func _display_mode_to_stretch(mode: String) -> int:
	match mode:
		"fit", "split_layout", "panel_sequence":
			return TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		"crop", "focus_crop", "background_blur", "fill", "top_crop", "center_crop":
			return TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_:
			return TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _default_layout_for_event() -> String:
	var display_mode: String = current_event.get("display_mode", current_event.get("image_mode", ""))
	if display_mode == "split_layout" or display_mode == "panel_sequence":
		return "side_dialogue"
	if current_event.get("kind", "") == "choice":
		return "side_dialogue"
	return "bottom_dialogue"


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
