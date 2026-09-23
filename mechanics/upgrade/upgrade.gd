extends "res://mechanics/base_mechanic.gd"

var upgrades: Dictionary = {}
var info_label: Label


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var data: Variant = DataManager.load_json("res://data/upgrades.json", {})
	upgrades = data if data is Dictionary else {}
	_build_ui()


func _build_ui() -> void:
	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.04, 0.08, 0.08)
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
	title.text = "Ship Upgrades"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	layout.add_child(title)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.text = "Choose an upgrade. Source Points: %s" % PlayerState.state.get("resources", {}).get("source_points", 0)
	layout.add_child(info_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

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
	layout.add_child(skip)


func _upgrade_label(upgrade: Dictionary) -> String:
	var costs: Array[String] = []
	for resource_id in upgrade.get("cost", {}).keys():
		costs.append("%s %s" % [upgrade["cost"][resource_id], resource_id])
	return "%s\nCost: %s" % [upgrade.get("name", "Upgrade"), ", ".join(costs)]


func _can_afford(cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if PlayerState.state.get("resources", {}).get(resource_id, 0) < cost[resource_id]:
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
