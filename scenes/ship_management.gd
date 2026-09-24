extends Control

const SHIP_VISUAL := preload("res://scenes/ships/visuals/player_fire_warship.tscn")

var modules: Dictionary = {}
var ship_definitions: Dictionary = {}
var selected_module_id: String = ""
var preview_root: SubViewportContainer
var preview_world: Node3D
var preview_ship: Node3D
var preview_highlight: MeshInstance3D
var preview_camera: Camera3D
var preview_distance: float = 1000.0
var detail_label: Label
var resource_label: Label
var module_list: VBoxContainer


func _ready() -> void:
	var data: Variant = _singleton("DataManager").load_data_file("fire_warship_modules.json", {})
	modules = data if data is Dictionary else {}
	var ships_data: Variant = _singleton("DataManager").load_data_file("ship_definitions.json", {})
	ship_definitions = ships_data if ships_data is Dictionary else {}
	_build_ui()
	set_process(true)


func _process(delta: float) -> void:
	if preview_ship != null:
		preview_ship.rotation_degrees.y += delta * 9.0


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.012, 0.026, 0.036)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	var title := Label.new()
	title.text = "FIRE WARSHIP MANAGEMENT"
	title.add_theme_font_size_override("font_size", 34)
	left.add_child(title)

	resource_label = Label.new()
	resource_label.add_theme_font_size_override("font_size", 21)
	resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(resource_label)

	preview_root = SubViewportContainer.new()
	preview_root.custom_minimum_size = Vector2(0, 260)
	preview_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(preview_root)
	_build_preview()

	var list_panel := PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list_panel)

	var scroll := ScrollContainer.new()
	list_panel.add_child(scroll)
	module_list = VBoxContainer.new()
	module_list.add_theme_constant_override("separation", 8)
	scroll.add_child(module_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 12)
	root.add_child(right)

	detail_label = Label.new()
	detail_label.add_theme_font_size_override("font_size", 22)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_label)

	var upgrade := Button.new()
	upgrade.text = "UPGRADE"
	upgrade.custom_minimum_size = Vector2(0, 62)
	upgrade.add_theme_font_size_override("font_size", 24)
	upgrade.pressed.connect(_upgrade_selected)
	right.add_child(upgrade)

	var back := Button.new()
	back.text = "Back To Menu"
	back.custom_minimum_size = Vector2(0, 62)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void: _singleton("UIManager").show_main_menu())
	right.add_child(back)

	_refresh()


func _build_preview() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_root.add_child(viewport)

	preview_world = Node3D.new()
	viewport.add_child(preview_world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 2.2
	preview_world.add_child(light)

	var definition: Dictionary = ship_definitions.get("fire_warship_mk1", {})
	preview_ship = SHIP_VISUAL.instantiate()
	if preview_ship.has_method("setup"):
		preview_ship.setup(definition)
	preview_ship.scale = Vector3.ONE * 0.9
	preview_world.add_child(preview_ship)

	preview_highlight = MeshInstance3D.new()
	var highlight_mesh := SphereMesh.new()
	highlight_mesh.radius = 38.0
	preview_highlight.mesh = highlight_mesh
	var highlight_material := StandardMaterial3D.new()
	highlight_material.albedo_color = Color(0.1, 1.0, 0.7, 0.32)
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(0.1, 1.0, 0.7)
	preview_highlight.material_override = highlight_material
	preview_highlight.visible = false
	preview_ship.add_child(preview_highlight)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(540, 260, 900)
	preview_camera.fov = 42
	preview_camera.current = true
	viewport.add_child(preview_camera)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _refresh() -> void:
	_refresh_resources()
	_refresh_modules()
	_refresh_details()


func _refresh_resources() -> void:
	var resources: Dictionary = _singleton("PlayerState").state.get("resources", {})
	resource_label.text = "Source Points: %s | Credits: %s | Iron: %s | Copper: %s | Titanium: %s | Energy Crystal: %s" % [
		resources.get("source_points", 0),
		resources.get("credits", 0),
		resources.get("iron", 0),
		resources.get("copper", 0),
		resources.get("titanium", 0),
		resources.get("energy_crystal", 0)
	]


func _refresh_modules() -> void:
	for child in module_list.get_children():
		child.queue_free()
	var equipped: Dictionary = _singleton("ShipState").ship_data.get("fire_warship", {}).get("equipped_modules", {})
	for slot in equipped.keys():
		var module_id: String = equipped[slot]
		var module: Dictionary = modules.get(module_id, {})
		var button := Button.new()
		button.text = "%s\n%s" % [slot.capitalize().replace("_", " "), module.get("display_name", module_id)]
		button.custom_minimum_size = Vector2(0, 64)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(func() -> void:
			selected_module_id = module_id
			_refresh_details()
			_update_preview_highlight()
		)
		module_list.add_child(button)
	if selected_module_id.is_empty() and not equipped.is_empty():
		selected_module_id = equipped.values()[0]


func _refresh_details() -> void:
	if selected_module_id.is_empty() or not modules.has(selected_module_id):
		detail_label.text = "Select a module."
		return
	var module: Dictionary = modules[selected_module_id]
	var levels: Dictionary = _singleton("ShipState").ship_data.get("fire_warship", {}).get("module_levels", {})
	var module_type: String = module.get("module_type", "")
	var level: int = int(levels.get(module_type, module.get("level", 1)))
	detail_label.text = "%s\nQuality: %s\nType: %s\nLevel: %s / %s\n\n%s\n\nCurrent Stats:\n%s\n\nNext-Level Stats:\n%s\n\nCost:\nSource Points: %s\nMaterials: %s\nEnergy Requirement: %s" % [
		module.get("display_name", selected_module_id),
		module.get("quality", "COMMON"),
		module_type.capitalize().replace("_", " "),
		level,
		module.get("max_level", 1),
		module.get("description", ""),
		_format_dict(module.get("base_stats", {})),
		_format_dict(module.get("upgraded_stats", {})),
		module.get("source_point_cost", 0),
		_format_dict(module.get("material_cost", {})),
		module.get("energy_requirement", 0)
	]
	_update_preview_highlight()


func _upgrade_selected() -> void:
	if selected_module_id.is_empty():
		return
	var result: Dictionary = _singleton("GameEventManager").upgrade_fire_warship_module(selected_module_id)
	if not bool(result.get("success", false)):
		detail_label.text = "%s\n\n%s" % [detail_label.text, result.get("error", "Upgrade failed.")]
		return
	_refresh()


func _update_preview_highlight() -> void:
	if preview_highlight == null or selected_module_id.is_empty() or not modules.has(selected_module_id):
		return
	var module: Dictionary = modules[selected_module_id]
	var attachment: String = module.get("visual_attachment", "")
	var definition: Dictionary = ship_definitions.get("fire_warship_mk1", {})
	var hardpoints: Dictionary = definition.get("hardpoints", {})
	if attachment.is_empty() or not hardpoints.has(attachment):
		preview_highlight.visible = false
		return
	preview_highlight.position = _array_to_vec3(hardpoints[attachment])
	preview_highlight.visible = true


func _format_dict(data: Dictionary) -> String:
	if data.is_empty():
		return "None"
	var lines: Array[String] = []
	for key in data.keys():
		lines.append("%s: %s" % [str(key).capitalize().replace("_", " "), data[key]])
	return "\n".join(lines)


func _array_to_vec3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
