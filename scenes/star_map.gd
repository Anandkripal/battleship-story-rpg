extends "res://mechanics/base_mechanic.gd"

var locations: Dictionary = {}


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var data: Variant = _singleton("DataManager").load_data_file("locations.json", {})
	locations = data if data is Dictionary else {}
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.015, 0.025, 0.060)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "STAR MAP"
	title.add_theme_font_size_override("font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint := Label.new()
	hint.text = "Select a reachable location"
	hint.add_theme_font_size_override("font_size", 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hint)

	var map_panel := PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(map_panel)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 18)
	map_panel.add_child(grid)

	for location_id in locations.keys():
		var location: Dictionary = locations[location_id]
		var unlocked: bool = bool(location.get("unlocked", false)) or _singleton("WorldState").state.get("unlocked_regions", []).has(location_id)
		var button := make_button("%s\n%s\n%s" % [
			location.get("name", location_id),
			location.get("type", "unknown"),
			"Available" if unlocked else "Locked"
		])
		button.custom_minimum_size = Vector2(0, 132)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.disabled = not unlocked
		button.pressed.connect(func() -> void: _select_location(location_id))
		grid.add_child(button)


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
