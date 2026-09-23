extends Control

signal completed(next_id: String)

var current_event: Dictionary = {}


func setup_event(event: Dictionary) -> void:
	current_event = event
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(top_spacer)

	var panel := PanelContainer.new()
	layout.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var title_text: String = current_event.get("title", current_event.get("speaker", ""))
	if not title_text.is_empty():
		var title := Label.new()
		title.text = title_text
		title.add_theme_font_size_override("font_size", 22)
		content.add_child(title)

	var body := Label.new()
	body.text = current_event.get("text", current_event.get("dialogue", current_event.get("narration", "")))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	content.add_child(body)

	if current_event.get("kind", "") == "choice":
		for choice in current_event.get("choices", []):
			if choice is Dictionary:
				var button := Button.new()
				button.text = choice.get("text", "Continue")
				button.custom_minimum_size = Vector2(0, 56)
				button.pressed.connect(func() -> void: completed.emit(choice.get("next", "")))
				content.add_child(button)
	else:
		var button := Button.new()
		button.text = current_event.get("button_text", "Continue")
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(func() -> void: completed.emit(current_event.get("next", "")))
		content.add_child(button)

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)


func _add_background() -> void:
	var fallback := ColorRect.new()
	fallback.color = Color(0.02, 0.03, 0.05)
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fallback)

	var asset_id: String = current_event.get("background", current_event.get("asset", ""))
	if asset_id.is_empty():
		return

	var path := AssetManifestManager.resolve(asset_id)
	if path.is_empty():
		return

	var texture: Texture2D = load(path)
	if texture == null:
		return

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = _image_mode_to_stretch(current_event.get("image_mode", "fill"))
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)


func _image_mode_to_stretch(mode: String) -> int:
	match mode:
		"fit":
			return TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		"fill", "crop", "top_crop", "center_crop":
			return TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_:
			return TextureRect.STRETCH_KEEP_ASPECT_CENTERED
