class_name ShieldSystem
extends RefCounted


static func layered_percent(ship: Variant) -> Dictionary:
	return ship.get_status_percent()
