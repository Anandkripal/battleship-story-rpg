class_name WeaponSystem
extends RefCounted


static func best_range(weapons: Array[Dictionary]) -> float:
	var value := 360.0
	for weapon in weapons:
		value = max(value, float(weapon.get("range", 0)) * 0.75)
	return value


static func first_ready_weapon(ship: Variant, target: Variant) -> int:
	for index in range(ship.weapons.size()):
		if ship.can_fire(index, target):
			return index
	return -1
