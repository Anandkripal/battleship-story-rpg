class_name CombatAI
extends RefCounted

const TARGETING := preload("res://scripts/combat/targeting_system.gd")
const WEAPONS := preload("res://scripts/combat/weapon_system.gd")


static func tick(ship: Variant, player: Variant, delta: float) -> void:
	if ship == null or player == null or ship.destroyed_flag or player.destroyed_flag:
		return
	var state: int = TARGETING.detection_state(ship, player)
	if state == TARGETING.DetectionState.UNDETECTED:
		ship.set_meta("ai_state", "PATROL")
		ship.command_move(Vector3.ZERO)
		return

	var profile: String = ship.get_meta("ai_profile", "aggressive")
	var preferred_range: float = WEAPONS.best_range(ship.weapons)
	var distance: float = ship.global_position.distance_to(player.global_position)
	if profile == "cowardly" and ship.hull < float(ship.stats.get("max_hull", 1)) * 0.35:
		ship.set_meta("ai_state", "RETREAT")
		ship.command_retreat(player.global_position)
	elif profile == "aggressive" and ship.ship_class == "frigate":
		_tick_frigate_attack_pass(ship, player, preferred_range, distance)
	elif profile == "maintain_range" or distance < preferred_range * 0.5:
		ship.set_meta("ai_state", "MAINTAIN_RANGE")
		ship.command_maintain_range(player, preferred_range)
	else:
		ship.set_meta("ai_state", "APPROACH")
		ship.command_approach(player)


static func _tick_frigate_attack_pass(ship: Variant, player: Variant, preferred_range: float, distance: float) -> void:
	var side: float = -1.0 if abs(hash(ship.ship_id)) % 2 == 0 else 1.0
	var vertical: float = -1.0 if abs(hash("%s_vertical" % ship.ship_id)) % 2 == 0 else 1.0
	if distance > preferred_range * 0.92:
		ship.set_meta("ai_state", "CLOSING")
		ship.command_approach(player)
		return
	var player_forward: Vector3 = -player.global_transform.basis.z.normalized()
	var player_right: Vector3 = player.global_transform.basis.x.normalized()
	var pass_distance: float = clamp(preferred_range * 0.72, 3600.0, 6200.0)
	var pass_point: Vector3 = player.global_position + player_forward * pass_distance + player_right * side * 2400.0 + Vector3.UP * vertical * 650.0
	ship.set_meta("ai_state", "ATTACK_PASS")
	ship.command_move(pass_point)
