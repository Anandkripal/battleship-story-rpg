extends Control

var ability_data: Dictionary = {}
var selected_ability_id := ""
var details_title: Label
var details_body: Label
var activate_button: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.052)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var loaded: Variant = _singleton("DataManager").load_data_file("system_abilities.json", {})
	ability_data = loaded if loaded is Dictionary else {}

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "SYSTEM"
	title.add_theme_font_size_override("font_size", 42)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 58)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void: _singleton("UIManager").show_main_menu())
	header.add_child(back)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(370, 0)
	columns.add_child(list_panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list_panel.add_child(list)

	var list_title := Label.new()
	list_title.text = "Abilities"
	list_title.add_theme_font_size_override("font_size", 30)
	list.add_child(list_title)

	for ability_id in ability_data.keys():
		var ability: Dictionary = ability_data[ability_id]
		var button := Button.new()
		button.text = "%s\n%s" % [ability.get("name", ability_id), "Unlocked" if ability.get("unlocked", false) else "Locked"]
		button.custom_minimum_size = Vector2(0, 72)
		button.add_theme_font_size_override("font_size", 23)
		button.pressed.connect(func() -> void: _select_ability(ability_id))
		list.add_child(button)
		if selected_ability_id.is_empty():
			selected_ability_id = ability_id

	var details_panel := PanelContainer.new()
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(details_panel)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 16)
	details_panel.add_child(details)

	details_title = Label.new()
	details_title.add_theme_font_size_override("font_size", 36)
	details_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(details_title)

	details_body = Label.new()
	details_body.add_theme_font_size_override("font_size", 26)
	details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(details_body)

	activate_button = Button.new()
	activate_button.text = "Activate"
	activate_button.custom_minimum_size = Vector2(220, 62)
	activate_button.add_theme_font_size_override("font_size", 24)
	details.add_child(activate_button)

	if not selected_ability_id.is_empty():
		_select_ability(selected_ability_id)


func _select_ability(ability_id: String) -> void:
	selected_ability_id = ability_id
	var ability: Dictionary = ability_data.get(ability_id, {})
	details_title.text = ability.get("name", ability_id)
	details_body.text = "ID: %s\nLevel: %s\nStatus: %s\n\nFuture ability data can add fields here without changing this screen." % [
		ability_id,
		ability.get("level", "-"),
		"Unlocked" if ability.get("unlocked", false) else "Locked"
	]
	activate_button.disabled = not ability.get("unlocked", false)


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
