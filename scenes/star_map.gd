extends "res://mechanics/base_mechanic.gd"

var locations: Dictionary = {}


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var data: Variant = _singleton("DataManager").load_json("res://data/locations.json", {})
	locations = data if data is Dictionary else {}
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.07)
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
	title.text = "Star Map"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "Select a reachable location."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for location_id in locations.keys():
		var location: Dictionary = locations[location_id]
		var unlocked: bool = bool(location.get("unlocked", false)) or _singleton("WorldState").state.get("unlocked_regions", []).has(location_id)
		var button := make_button("%s\n%s" % [location.get("name", location_id), location.get("type", "unknown")])
		button.disabled = not unlocked
		button.pressed.connect(func() -> void: _select_location(location_id))
		list.add_child(button)


func _select_location(location_id: String) -> void:
	finish({
		"success": true,
		"location": location_id,
		"changes": [
			{
				"path": "world.current_location",
				"operation": "set",
				"value": location_id
			},
			{
				"path": "world.discovered_locations",
				"operation": "append",
				"value": location_id
			}
		]
	})


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
