extends RefCounted
## Shared source for animation timing, contact cues and isometric danger shapes.
const PATH := "res://resources/bosses/gatekeeper_attacks.json"
const ISO_Y := .70
static var _data: Dictionary = {}

static func load_data() -> Dictionary:
	if not _data.is_empty(): return _data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("version") != 1:
		push_error("Invalid Gatekeeper attack JSON")
		return {}
	_data = parsed
	return _data

static func definition(id: String) -> Dictionary:
	return load_data().get("attacks", {}).get(id, {})

static func contact_time(attack: Dictionary) -> float:
	var result := 0.0
	var times: Array = attack.get("seconds", [])
	for index in range(int(attack.get("contact_pose", 0))): result += float(times[index])
	return result

static func duration(attack: Dictionary) -> float:
	var result := 0.0
	for value in attack.get("seconds", []): result += float(value)
	return result

static func vector(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func metric(value: Vector2) -> Vector2:
	return Vector2(value.x,value.y/ISO_Y)

static func ground(value: Vector2) -> Vector2:
	return Vector2(value.x,value.y*ISO_Y)

static func orient(value: Vector2, aim: Vector2) -> Vector2:
	return ground(metric(value).rotated(aim.angle()))

## Offsets are native screen/ground pixels for the authored three-quarter pilot;
## reach/radius are the existing combat metric. No unproduced view is mirrored.
static func contains_point(attack: Dictionary, point: Vector2, aim: Vector2, since_contact: float, radius: float=0.0) -> bool:
	var shape: Dictionary = attack.get("shape", {})
	var local := metric(point).rotated(-aim.angle())
	var facing := Vector2.RIGHT
	match str(shape.get("kind", "")):
		"line":
			var along := local.dot(facing)
			return along >= -radius and along <= float(shape["reach"])+radius and absf(local.cross(facing)) <= float(shape["width"])+radius
		"arc":
			return local.length() <= float(shape["reach"])+radius and (local.length() < radius+2 or local.normalized().dot(facing) >= cos(deg_to_rad(float(shape["degrees"])*.5)+atan2(radius,maxf(1,local.length()))))
		"disc":
			return (local-metric(vector(shape.get("offset",[0,0])))).length() <= float(shape["radius"])+radius
		"ring":
			var seconds := float(shape["wave_seconds"])
			if since_contact < 0 or since_contact > seconds: return false
			var wave_radius := float(shape["reach"])*since_contact/seconds
			return absf(local.length()-wave_radius) <= float(shape["width"])*.5+radius
		"zones":
			if since_contact < float(shape["delay"]) or since_contact > float(shape["delay"])+float(shape["active_seconds"]): return false
			for at in shape["zones"]:
				if (local-metric(vector(at))).length() <= float(shape["radius"])+radius: return true
	return false
