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
			"source_points": 5,
			"ore": 0,
			"alloys": 0,
			"iron": 0,
			"copper": 0,
			"titanium": 0,
			"titanium_crystal": 0,
			"energy_crystal": 0
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
	reset()
	_deep_merge(state, data)


func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.get(key) is Dictionary and source[key] is Dictionary:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]
