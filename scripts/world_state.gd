extends Node

## Flexible world state for map, factions, technologies, and future progression.

var state: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	var shared_flags := {}
	state = {
		"discovered_locations": [],
		"known_planets": {},
		"factions": {},
		"faction_reputation": {},
		"unlocked_regions": [],
		"current_location": "training_planet",
		"world_flags": shared_flags,
		"flags": shared_flags,
		"discovered_technologies": {},
		"exploration": {
			"current_sector": "",
			"current_node": "",
			"visited_nodes": [],
			"completed_encounters": {}
		},
		"objectives": {},
		"active_arc": "",
		"calendar": {
			"year": 10103,
			"month": 6,
			"day": 1,
			"hour": 8
		},
		"alternate_space": {
			"cooldown_days": 30,
			"last_entry_day": -9999,
			"available": true,
			"current_expedition": {},
			"destination_seed": 1001,
			"reward_multiplier": 1.0,
			"return_state": {}
		},
		"last_battle_result": {}
	}


func to_dict() -> Dictionary:
	return state.duplicate(true)


func from_dict(data: Dictionary) -> void:
	reset()
	_deep_merge(state, data)
	if not state.has("flags") and state.has("world_flags"):
		state["flags"] = state["world_flags"]
	if not state.has("world_flags") and state.has("flags"):
		state["world_flags"] = state["flags"]


func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.get(key) is Dictionary and source[key] is Dictionary:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]
