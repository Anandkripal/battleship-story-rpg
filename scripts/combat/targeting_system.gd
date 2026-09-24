class_name TargetingSystem
extends RefCounted

enum DetectionState {
	UNDETECTED,
	CONTACT,
	CLASSIFIED,
	SCANNED
}


static func detection_state(observer: Variant, target: Variant) -> int:
	if observer == null or target == null:
		return DetectionState.UNDETECTED
	var distance: float = observer.global_position.distance_to(target.global_position)
	var sensor_range := float(observer.stats.get("sensor_range", 0))
	var sensor_strength := float(observer.stats.get("sensor_strength", 0))
	var signature: float = max(1.0, float(target.stats.get("signature", 50)))
	var effective: float = sensor_range * (sensor_strength / signature)
	if distance > effective:
		return DetectionState.UNDETECTED
	if distance > effective * 0.72:
		return DetectionState.CONTACT
	if distance > effective * 0.42:
		return DetectionState.CLASSIFIED
	return DetectionState.SCANNED


static func detection_label(state: int) -> String:
	match state:
		DetectionState.CONTACT:
			return "CONTACT"
		DetectionState.CLASSIFIED:
			return "CLASSIFIED"
		DetectionState.SCANNED:
			return "SCANNED"
		_:
			return "UNDETECTED"
