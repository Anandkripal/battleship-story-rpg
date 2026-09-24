class_name CombatAI
extends RefCounted

const TARGETING := preload("res://scripts/combat/targeting_system.gd")
const WEAPONS := preload("res://scripts/combat/weapon_system.gd")


static func tick(ship: Variant, player: Variant, delta: float) -> void:
	if ship == null or player == null or ship.destroyed_flag or player.destroyed_flag:
		return
	var state: int = TARGETING.detection_state(ship, player)
	if state == TARGETING.DetectionState.UNDETECTED:
		ship.command_move(Vector3.ZERO)
		return

	var profile: String = ship.get_meta("ai_profile", "aggressive")
	var preferred_range: float = WEAPONS.best_range(ship.weapons)
	var distance: float = ship.global_position.distance_to(player.global_position)
	if profile == "cowardly" and ship.hull < float(ship.stats.get("max_hull", 1)) * 0.35:
		ship.command_retreat(player.global_position)
	elif profile == "maintain_range" or distance < preferred_range * 0.5:
		ship.command_maintain_range(player, preferred_range)
	else:
		ship.command_approach(player)
