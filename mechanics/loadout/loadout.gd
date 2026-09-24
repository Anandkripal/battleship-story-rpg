extends "res://mechanics/base_mechanic.gd"

var modules: Dictionary = {}
var available_modules: Array = []
var info_label: Label


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var module_data: Variant = _singleton("DataManager").load_data_file("modules.json", {})
	modules = module_data if module_data is Dictionary else {}
	available_modules = params.get("available_modules", [])
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.018, 0.036, 0.044)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var installed_panel := PanelContainer.new()
	installed_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(installed_panel)

	var installed := VBoxContainer.new()
	installed.add_theme_constant_override("separation", 12)
	installed_panel.add_child(installed)

	var title := Label.new()
	title.text = "SHIP LOADOUT"
	title.add_theme_font_size_override("font_size", 34)
	installed.add_child(title)

	var ship_stats := Label.new()
	ship_stats.text = _format_ship_status()
	ship_stats.add_theme_font_size_override("font_size", 22)
	ship_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	installed.add_child(ship_stats)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	installed.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var installed_modules: Dictionary = _singleton("ShipState").ship_data.get("modules", {})
	for slot_id in installed_modules.keys():
		var module_entry: Dictionary = installed_modules[slot_id]
		var module_id: String = module_entry.get("id", "")
		var definition: Dictionary = modules.get(module_id, {})
		var label := Label.new()
		label.text = "%s\n%s" % [slot_id.capitalize().replace("_", " "), _format_module(module_id, definition)]
		label.add_theme_font_size_override("font_size", 22)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)

	var available_panel := PanelContainer.new()
	available_panel.custom_minimum_size = Vector2(430, 0)
	row.add_child(available_panel)

	var available := VBoxContainer.new()
	available.add_theme_constant_override("separation", 12)
	available_panel.add_child(available)

	var available_title := Label.new()
	available_title.text = "AVAILABLE MODULES"
	available_title.add_theme_font_size_override("font_size", 32)
	available.add_child(available_title)

	info_label = Label.new()
	info_label.text = _resource_line()
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	available.add_child(info_label)

	for entry in available_modules:
		if not (entry is Dictionary):
			continue
		var module_id: String = entry.get("module", "")
		var slot: String = entry.get("slot", "")
		var definition: Dictionary = modules.get(module_id, {})
		var button := make_button("%s\nInstall to %s\nCost: %s" % [
			definition.get("name", module_id),
			slot.capitalize().replace("_", " "),
			_format_cost(entry.get("cost", {}))
		])
		button.disabled = not _can_afford(entry.get("cost", {}))
		button.pressed.connect(func() -> void: _install(entry))
		available.add_child(button)

	var continue_button := make_button("Continue")
	continue_button.pressed.connect(func() -> void: finish({"success": true, "skipped": true}))
	available.add_child(continue_button)


func _install(entry: Dictionary) -> void:
	var module_id: String = entry.get("module", "")
	var slot: String = entry.get("slot", "")
	var cost: Dictionary = entry.get("cost", {})
	if module_id.is_empty() or slot.is_empty():
		info_label.text = "Module entry is missing a module or slot."
		return
	if not _can_afford(cost):
		info_label.text = "Not enough resources."
		return

	var changes: Array = []
	for resource_id in cost.keys():
		changes.append({
			"path": "player.resources.%s" % resource_id,
			"operation": "subtract",
			"value": cost[resource_id]
		})

	var module_record := {
		"id": module_id,
		"level": int(entry.get("level", 1))
	}
	var definition: Dictionary = modules.get(module_id, {})
	if definition.has("action"):
		module_record["action"] = definition["action"]

	changes.append({
		"path": "ship.modules.%s" % slot,
		"operation": "set",
		"value": module_record
	})

	for stat_id in definition.get("stats", {}).keys():
		if ["damage", "range", "cooldown", "energy_cost"].has(stat_id):
			continue
		changes.append({
			"path": "ship.stats.%s" % stat_id,
			"operation": "set",
			"value": definition["stats"][stat_id]
		})

	finish({
		"success": true,
		"installed_module": module_id,
		"slot": slot,
		"changes": changes
	})


func _format_ship_status() -> String:
	var ship: Dictionary = _singleton("ShipState").ship_data
	var stats: Dictionary = ship.get("stats", {})
	return "%s\nHull %s/%s  Armor %s  Shield %s\nReactor %s | Engine %s | Scanner %s" % [
		ship.get("name", "Ship"),
		stats.get("hull", 0),
		stats.get("hull_max", 0),
		stats.get("armor", 0),
		stats.get("shield", 0),
		stats.get("reactor_output", 0),
		stats.get("engine_speed", 0),
		stats.get("scanner_level", 0)
	]


func _format_module(module_id: String, definition: Dictionary) -> String:
	if definition.is_empty():
		return module_id
	var lines: Array[String] = [definition.get("name", module_id)]
	for stat_id in definition.get("stats", {}).keys():
		lines.append("%s: %s" % [stat_id.capitalize().replace("_", " "), definition["stats"][stat_id]])
	return "\n".join(lines)


func _can_afford(cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if int(_singleton("PlayerState").state.get("resources", {}).get(resource_id, 0)) < int(cost[resource_id]):
			return false
	return true


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var parts: Array[String] = []
	for resource_id in cost.keys():
		parts.append("%s %s" % [cost[resource_id], resource_id])
	return ", ".join(parts)


func _resource_line() -> String:
	var resources: Dictionary = _singleton("PlayerState").state.get("resources", {})
	return "Credits: %s  Ore: %s  Alloys: %s  Source: %s" % [
		resources.get("credits", 0),
		resources.get("ore", 0),
		resources.get("alloys", 0),
		resources.get("source_points", 0)
	]


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
