extends Node

## Reads and modifies dynamic state using paths such as:
## player.resources.credits
## ship.stats.scanner_level
## world.flags.met_character_a

const VALID_ROOTS := ["player", "ship", "world"]


func get_roots() -> Dictionary:
	return {
		"player": PlayerState.state,
		"ship": ShipState.ship_data,
		"world": WorldState.state
	}


func is_valid_state_path(path: String) -> bool:
	var parts := path.split(".")
	return parts.size() >= 2 and VALID_ROOTS.has(parts[0]) and not parts.has("")


func get_value(path: String, default_value: Variant = null) -> Variant:
	if not is_valid_state_path(path):
		return default_value

	var parts := path.split(".")
	var roots := get_roots()
	var current: Variant = roots.get(parts[0])

	for index in range(1, parts.size()):
		var key := parts[index]
		if current is Dictionary:
			if not current.has(key):
				return default_value
			current = current[key]
		elif current is Array and key.is_valid_int():
			var array_index := int(key)
			if array_index < 0 or array_index >= current.size():
				return default_value
			current = current[array_index]
		else:
			return default_value

	return current


func set_value(path: String, value: Variant) -> bool:
	if not is_valid_state_path(path):
		push_warning("Invalid state path: %s" % path)
		return false

	var parts := path.split(".")
	var roots := get_roots()
	var current: Variant = roots[parts[0]]

	for index in range(1, parts.size() - 1):
		var key := parts[index]
		if current is Dictionary:
			if not current.has(key) or not (current[key] is Dictionary or current[key] is Array):
				current[key] = {}
			current = current[key]
		elif current is Array and key.is_valid_int():
			current = current[int(key)]
		else:
			push_warning("Cannot traverse state path: %s" % path)
			return false

	var final_key := parts[parts.size() - 1]
	if current is Dictionary:
		current[final_key] = value
		return true
	if current is Array and final_key.is_valid_int():
		var array_index := int(final_key)
		if array_index >= 0 and array_index < current.size():
			current[array_index] = value
			return true

	push_warning("Cannot write state path: %s" % path)
	return false


func apply_change(change: Dictionary) -> bool:
	var path: String = change.get("path", "")
	var operation: String = change.get("operation", "set")
	var value: Variant = change.get("value")

	if not is_valid_state_path(path):
		push_warning("Invalid state change path: %s" % path)
		return false

	var current: Variant = get_value(path)
	match operation:
		"set":
			return set_value(path, value)
		"add":
			return set_value(path, _number_or_zero(current) + _number_or_zero(value))
		"subtract":
			return set_value(path, _number_or_zero(current) - _number_or_zero(value))
		"multiply":
			return set_value(path, _number_or_zero(current) * _number_or_zero(value))
		"append":
			var array_value: Array = current if current is Array else []
			array_value.append(value)
			return set_value(path, array_value)
		"remove":
			var array_value: Array = current if current is Array else []
			array_value.erase(value)
			return set_value(path, array_value)
		_:
			push_warning("Unknown state operation: %s" % operation)
			return false


func apply_changes(changes: Array) -> void:
	for change in changes:
		if change is Dictionary:
			apply_change(change)


func evaluate_condition(condition: Dictionary) -> bool:
	var left: Variant = get_value(condition.get("path", ""))
	var operator_text: String = condition.get("operator", "==")
	var right: Variant = condition.get("value")

	match operator_text:
		"==":
			return left == right
		"!=":
			return left != right
		">":
			return _number_or_zero(left) > _number_or_zero(right)
		"<":
			return _number_or_zero(left) < _number_or_zero(right)
		">=":
			return _number_or_zero(left) >= _number_or_zero(right)
		"<=":
			return _number_or_zero(left) <= _number_or_zero(right)
		"contains":
			return _contains(left, right)
		"not_contains":
			return not _contains(left, right)
		_:
			push_warning("Unknown condition operator: %s" % operator_text)
			return false


func _contains(container: Variant, value: Variant) -> bool:
	if container is Array:
		return container.has(value)
	if container is Dictionary:
		return container.has(value)
	if container is String:
		return String(container).contains(str(value))
	return false


func _number_or_zero(value: Variant) -> float:
	if value is int or value is float:
		return value
	if value is String and String(value).is_valid_float():
		return float(value)
	return 0.0
