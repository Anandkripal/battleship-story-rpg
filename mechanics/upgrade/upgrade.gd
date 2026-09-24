extends "res://mechanics/base_mechanic.gd"

var upgrades: Dictionary = {}
var info_label: Label


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var data: Variant = _singleton("DataManager").load_data_file("upgrades.json", {})
	upgrades = data if data is Dictionary else {}
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.025, 0.065, 0.065)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	var ship_panel := PanelContainer.new()
	ship_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_panel.size_flags_stretch_ratio = 0.9
	row.add_child(ship_panel)

	var ship_stack := VBoxContainer.new()
	ship_stack.add_theme_constant_override("separation", 14)
	ship_panel.add_child(ship_stack)

	var title := Label.new()
	title.text = "SHIP STATUS"
	title.add_theme_font_size_override("font_size", 34)
	ship_stack.add_child(title)

	var art := Label.new()
	art.text = "      /\\\n ____/  \\____\n<____________>\n    /____\\"
	art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art.add_theme_font_size_override("font_size", 30)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ship_stack.add_child(art)

	var stats := Label.new()
	stats.text = _format_ship_stats()
	stats.add_theme_font_size_override("font_size", 24)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_stack.add_child(stats)

	var upgrade_panel := PanelContainer.new()
	upgrade_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_panel.size_flags_stretch_ratio = 1.1
	row.add_child(upgrade_panel)

	var upgrade_stack := VBoxContainer.new()
	upgrade_stack.add_theme_constant_override("separation", 12)
	upgrade_panel.add_child(upgrade_stack)

	var upgrade_title := Label.new()
	upgrade_title.text = "AVAILABLE UPGRADES"
	upgrade_title.add_theme_font_size_override("font_size", 34)
	upgrade_stack.add_child(upgrade_title)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 24)
	info_label.text = "Source Points: %s  Credits: %s" % [
		_singleton("PlayerState").state.get("resources", {}).get("source_points", 0),
		_singleton("PlayerState").state.get("resources", {}).get("credits", 0)
	]
	upgrade_stack.add_child(info_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrade_stack.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for upgrade_id in upgrades.keys():
		var upgrade: Dictionary = upgrades[upgrade_id]
		var button := make_button(_upgrade_label(upgrade))
		button.disabled = not _can_afford(upgrade.get("cost", {}))
		button.pressed.connect(func() -> void: _buy_upgrade(upgrade_id))
		list.add_child(button)

	var skip := make_button("Continue Without Upgrade")
	skip.pressed.connect(func() -> void: finish({"success": true, "skipped": true}))
	upgrade_stack.add_child(skip)


func _format_ship_stats() -> String:
	var stats: Dictionary = _singleton("ShipState").ship_data.get("stats", {})
	var lines: Array[String] = []
	for stat_id in stats.keys():
		lines.append("%s: %s" % [str(stat_id).capitalize().replace("_", " "), stats[stat_id]])
	return "\n".join(lines)


func _upgrade_label(upgrade: Dictionary) -> String:
	var costs: Array[String] = []
	for resource_id in upgrade.get("cost", {}).keys():
		costs.append("%s %s" % [upgrade["cost"][resource_id], resource_id])
	return "%s\nCost: %s" % [upgrade.get("name", "Upgrade"), ", ".join(costs)]


func _can_afford(cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if _singleton("PlayerState").state.get("resources", {}).get(resource_id, 0) < cost[resource_id]:
			return false
	return true


func _buy_upgrade(upgrade_id: String) -> void:
	var upgrade: Dictionary = upgrades[upgrade_id]
	if not _can_afford(upgrade.get("cost", {})):
		info_label.text = "Not enough resources."
		return

	var changes: Array = []
	for resource_id in upgrade.get("cost", {}).keys():
		changes.append({
			"path": "player.resources.%s" % resource_id,
			"operation": "subtract",
			"value": upgrade["cost"][resource_id]
		})

	changes.append({
		"path": upgrade.get("target_path", ""),
		"operation": upgrade.get("operation", "set"),
		"value": upgrade.get("value")
	})

	finish({
		"success": true,
		"upgrade": upgrade_id,
		"changes": changes
	})


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
