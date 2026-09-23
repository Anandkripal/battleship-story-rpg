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
			"engine_speed": 10,
			"scanner_level": 1
		},
		"modules": {
			"engine": {
				"id": "basic_engine",
				"level": 1
			},
			"weapon": {
				"id": "light_cannon",
				"level": 1,
				"action": "main_cannon"
			}
		},
		"abilities": [
			"main_cannon",
			"defend"
		]
	}


func to_dict() -> Dictionary:
	return ship_data.duplicate(true)


func from_dict(data: Dictionary) -> void:
	ship_data = data.duplicate(true)
