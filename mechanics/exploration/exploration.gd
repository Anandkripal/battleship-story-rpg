extends "res://mechanics/base_mechanic.gd"

const NODE_SIZE := Vector2(168, 72)
const MAP_OFFSET := Vector2(20, 20)

var sectors: Dictionary = {}
var encounters: Dictionary = {}
var sector_id: String = ""
var sector: Dictionary = {}
var current_node_id: String = ""
var objective_node_id: String = ""
var completed_optional: Dictionary = {}
var resources_gained: Dictionary = {}
var changes_applied: Array = []
var map_canvas: Control
var status_label: Label
var objective_label: Label
var log_label: Label
var node_buttons: Dictionary = {}


func start(new_params: Dictionary) -> void:
	super.start(new_params)
	var sector_data: Variant = _singleton("DataManager").load_data_file("sectors.json", {})
	var encounter_data: Variant = _singleton("DataManager").load_data_file("encounters.json", {})
	sectors = sector_data if sector_data is Dictionary else {}
	encounters = encounter_data if encounter_data is Dictionary else {}
	sector_id = params.get("sector", "training_sector")
	sector = sectors.get(sector_id, {})
	objective_node_id = params.get("objective_node", "")
	completed_optional.clear()
	resources_gained.clear()
	changes_applied.clear()

	var exploration_state: Dictionary = _singleton("WorldState").state.get("exploration", {})
	var saved_node: String = exploration_state.get("current_node", "")
	current_node_id = params.get("start_node", saved_node)
	if current_node_id.is_empty() or not _nodes().has(current_node_id):
		current_node_id = sector.get("start_node", "")
	if current_node_id.is_empty() and not _nodes().is_empty():
		current_node_id = _nodes().keys()[0]

	_apply_change({
		"path": "world.exploration.current_sector",
		"operation": "set",
		"value": sector_id
	})
	_apply_change({
		"path": "world.exploration.current_node",
		"operation": "set",
		"value": current_node_id
	})
	_visit_node(current_node_id, false)
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	node_buttons.clear()

	set_full_rect()
	var background := ColorRect.new()
	background.color = Color(0.012, 0.020, 0.034)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(map_panel)

	map_canvas = Control.new()
	map_canvas.clip_contents = true
	map_canvas.custom_minimum_size = Vector2(780, 640)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(map_canvas)

	for node_id in _visible_node_ids():
		_add_node_button(node_id)

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(390, 0)
	row.add_child(side_panel)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side_panel.add_child(side)

	var title := Label.new()
	title.text = sector.get("name", sector_id)
	title.add_theme_font_size_override("font_size", 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(title)

	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 22)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(objective_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(status_label)

	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 22)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(log_label)

	var repair := make_button("Repair At Current Node")
	repair.pressed.connect(_try_repair)
	side.add_child(repair)

	var finish_button := make_button("Continue Mission")
	finish_button.disabled = not _objective_complete()
	finish_button.pressed.connect(_finish_exploration)
	side.add_child(finish_button)

	queue_redraw()
	_refresh("Choose a destination or resolve a local opportunity.")


func _add_node_button(node_id: String) -> void:
	var node: Dictionary = _nodes().get(node_id, {})
	var button := make_button("%s\n%s" % [node.get("name", node_id), node.get("type", "unknown")])
	button.custom_minimum_size = NODE_SIZE
	button.position = _node_position(node)
	button.disabled = not _can_travel_to(node_id) and node_id != current_node_id
	button.pressed.connect(func() -> void: _select_node(node_id))
	map_canvas.add_child(button)
	node_buttons[node_id] = button


func _draw() -> void:
	if map_canvas == null:
		return
	var offset: Vector2 = map_canvas.global_position - global_position
	for node_id in _visible_node_ids():
		var node: Dictionary = _nodes().get(node_id, {})
		var from_pos: Vector2 = offset + _node_position(node) + NODE_SIZE * 0.5
		for connected_id in node.get("connections", []):
			if not _visible_node_ids().has(connected_id):
				continue
			var connected_node: Dictionary = _nodes().get(connected_id, {})
			var to_pos: Vector2 = offset + _node_position(connected_node) + NODE_SIZE * 0.5
			draw_line(from_pos, to_pos, Color(0.22, 0.58, 0.86, 0.55), 3.0)


func _select_node(node_id: String) -> void:
	if node_id == current_node_id:
		_resolve_current_node()
		return
	if not _can_travel_to(node_id):
		_refresh("That destination is not connected from the current position.")
		return

	var cost: int = int(_nodes().get(node_id, {}).get("energy_cost", 4))
	if _resource("energy_cells") < cost:
		_refresh("Not enough energy cells for that route.")
		return
	_add_resource("energy_cells", -cost)
	current_node_id = node_id
	_apply_change({
		"path": "world.exploration.current_node",
		"operation": "set",
		"value": current_node_id
	})
	_visit_node(current_node_id, true)
	_resolve_current_node()
	_rebuild_after_change("Traveled to %s." % _nodes().get(node_id, {}).get("name", node_id))


func _resolve_current_node() -> void:
	var node: Dictionary = _nodes().get(current_node_id, {})
	var encounter_id: String = node.get("encounter", "")
	if encounter_id.is_empty() or completed_optional.has(current_node_id):
		_refresh(node.get("description", "No new signal at this destination."))
		return

	var encounter: Dictionary = encounters.get(encounter_id, {})
	completed_optional[current_node_id] = true
	for resource_id in encounter.get("rewards", {}).keys():
		_add_resource(resource_id, int(encounter["rewards"][resource_id]))
	for change in encounter.get("changes", []):
		if change is Dictionary:
			_apply_change(change)
	for reveal_id in encounter.get("reveals", []):
		_apply_change({
			"path": "world.flags.node_revealed_%s" % reveal_id,
			"operation": "set",
			"value": true
		})

	_rebuild_after_change("%s\n%s" % [
		encounter.get("name", node.get("name", current_node_id)),
		encounter.get("description", "Encounter resolved.")
	])


func _try_repair() -> void:
	var node: Dictionary = _nodes().get(current_node_id, {})
	if not bool(node.get("repair", false)):
		_refresh("No repair service is available at this node.")
		return

	var cost: Dictionary = node.get("repair_cost", {"credits": 20, "alloys": 1})
	for resource_id in cost.keys():
		if _resource(resource_id) < int(cost[resource_id]):
			_refresh("Repair requires %s." % _format_cost(cost))
			return

	for resource_id in cost.keys():
		_add_resource(resource_id, -int(cost[resource_id]))

	var stats: Dictionary = _singleton("ShipState").ship_data.get("stats", {})
	var hull_max: int = int(stats.get("hull_max", 100))
	_apply_change({
		"path": "ship.stats.hull",
		"operation": "set",
		"value": hull_max
	})
	_refresh("Repairs complete. Hull restored.")


func _finish_exploration() -> void:
	finish({
		"success": true,
		"sector": sector_id,
		"location": current_node_id,
		"resources_gained": resources_gained,
		"changes_applied": changes_applied,
		"next": params.get("completion_next", "")
	})


func _rebuild_after_change(message: String) -> void:
	_build_ui()
	_refresh(message)


func _refresh(message: String) -> void:
	var current: Dictionary = _nodes().get(current_node_id, {})
	var objective_name: String = _nodes().get(objective_node_id, {}).get("name", objective_node_id)
	objective_label.text = "PRIMARY: Reach %s\nStatus: %s" % [
		objective_name if not objective_name.is_empty() else "any destination",
		"Complete" if _objective_complete() else "Active"
	]
	status_label.text = "Current: %s\nHull: %s/%s\nCredits: %s  Ore: %s  Alloys: %s  Energy Cells: %s" % [
		current.get("name", current_node_id),
		_ship_stat("hull", 0),
		_ship_stat("hull_max", 0),
		_resource("credits"),
		_resource("ore"),
		_resource("alloys"),
		_resource("energy_cells")
	]
	log_label.text = "%s\n\n%s" % [current.get("description", ""), message]


func _visit_node(node_id: String, record_change: bool) -> void:
	var visited: Array = _singleton("WorldState").state.get("exploration", {}).get("visited_nodes", [])
	if not visited.has(node_id):
		var change := {
			"path": "world.exploration.visited_nodes",
			"operation": "append",
			"value": node_id
		}
		if record_change:
			_apply_change(change)
		else:
			_singleton("StatePathUtil").apply_change(change)


func _apply_change(change: Dictionary) -> void:
	changes_applied.append(change)
	_singleton("StatePathUtil").apply_change(change)


func _add_resource(resource_id: String, amount: int) -> void:
	resources_gained[resource_id] = int(resources_gained.get(resource_id, 0)) + amount
	_apply_change({
		"path": "player.resources.%s" % resource_id,
		"operation": "add",
		"value": amount
	})


func _can_travel_to(node_id: String) -> bool:
	var current: Dictionary = _nodes().get(current_node_id, {})
	return current.get("connections", []).has(node_id)


func _objective_complete() -> bool:
	return objective_node_id.is_empty() or current_node_id == objective_node_id


func _visible_node_ids() -> Array:
	var ids: Array = []
	for node_id in _nodes().keys():
		var node: Dictionary = _nodes()[node_id]
		if bool(node.get("hidden", false)) and not _singleton("WorldState").state.get("flags", {}).get("node_revealed_%s" % node_id, false):
			continue
		ids.append(node_id)
	return ids


func _nodes() -> Dictionary:
	return sector.get("nodes", {})


func _node_position(node: Dictionary) -> Vector2:
	var position_data: Array = node.get("position", [120, 120])
	if position_data.size() >= 2:
		return Vector2(float(position_data[0]), float(position_data[1])) + MAP_OFFSET
	return Vector2(120, 120) + MAP_OFFSET


func _ship_stat(stat_id: String, default_value: int) -> int:
	return int(_singleton("ShipState").ship_data.get("stats", {}).get(stat_id, default_value))


func _resource(resource_id: String) -> int:
	return int(_singleton("PlayerState").state.get("resources", {}).get(resource_id, 0))


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in cost.keys():
		parts.append("%s %s" % [cost[resource_id], resource_id])
	return ", ".join(parts)


func _singleton(singleton_name: String) -> Variant:
	return get_node("/root/%s" % singleton_name)
