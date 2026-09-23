extends Node

## Dynamic player state. Add resources, stats, flags, unlocks, or relationship
## keys in JSON/state changes without changing this script.

var state: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	state = {
		"resources": {
			"credits": 100,
			"source_points": 5
		},
		"stats": {
			"physical_fitness": 1,
			"mental_strength": 1
		},
		"flags": {},
		"unlocks": {
			"scan": true
		},
		"relationships": {},
		"inventory": {},
		"progress": {}
	}


func to_dict() -> Dictionary:
	return state.duplicate(true)


func from_dict(data: Dictionary) -> void:
	state = data.duplicate(true)
