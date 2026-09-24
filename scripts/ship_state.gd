extends Node

## Dynamic ship state. Ship stats/modules/abilities are dictionaries so future
## systems can add new properties without redesigning the save format.

var ship_data: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	ship_data = {
		"id": "starter_ship",
		"name": "Starter Ship",
		"class": "Mining Vessel",
		"rating": "F",
		"stats": {
			"hull": 100,
			"hull_max": 100,
			"armor": 50,
			"armor_max": 50,
			"shield": 0,
			"shield_max": 0,
			"reactor_output": 100,
			"energy_engines": 30,
			"energy_shields": 20,
			"energy_weapons": 50,
			"engine_speed": 10,
			"scanner_level": 1
		},
		"modules": {
			"reactor": {
				"id": "basic_reactor",
				"level": 1
			},
			"engine": {
				"id": "basic_engine",
				"level": 1
			},
			"main_weapon": {
				"id": "light_cannon",
				"level": 1,
				"action": "main_cannon"
			},
			"scanner": {
				"id": "basic_scanner",
				"level": 1
			}
		},
		"abilities": [
			"main_cannon",
			"defend"
		],
		"active_hull": "fire_warship_mk1",
		"fire_warship": {
			"ship_definition": "fire_warship_mk1",
			"module_levels": {
				"main_gun": 1,
				"armor": 1,
				"engine": 1,
				"radar": 1,
				"shield": 1,
				"hull_structure": 1,
				"emergency_repair": 1
			},
			"equipped_modules": {
				"main_gun": "fw_main_cannon_common",
				"armor": "fw_armor_common",
				"engine": "fw_engine_common",
				"radar": "fw_radar_common",
				"shield": "fw_shield_common",
				"hull_structure": "fw_hull_common",
				"special_01": "fw_emergency_repair_common"
			}
		}
	}


func to_dict() -> Dictionary:
	return ship_data.duplicate(true)


func from_dict(data: Dictionary) -> void:
	reset()
	_deep_merge(ship_data, data)


func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.get(key) is Dictionary and source[key] is Dictionary:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]
