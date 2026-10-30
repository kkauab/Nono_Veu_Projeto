extends RefCounted
## Native eight-view live atlas plus the preserved V5/V6 art-review atlases.
## This renderer never moves actors or applies damage.
## Missing directions return an empty sample; never mirror the handed key-spear.
const MANIFEST := "res://assets/sprites/porteiro_v5_manifest.json"
const WALK_MANIFEST := "res://assets/sprites/porteiro_walk_v6_manifest.json"
static var _data: Dictionary = {}
static var _texture: Texture2D
static var _walk_data: Dictionary = {}
static var _walk_texture: Texture2D
const LIVE_MANIFEST="res://assets/sprites/porteiro_live_v9_manifest.json"
static var _live_data: Dictionary={}
static var _live_texture: Texture2D

static func direction_name(aim: Vector2) -> String:
	return ["right","down_right","down","down_left","left","up_left","up","up_right"][posmod(roundi(aim.angle()/(PI/4)),8)]

static func live_data() -> Dictionary:
	if not _live_data.is_empty():return _live_data
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(LIVE_MANIFEST))
	if not parsed is Dictionary:return {}
	_live_texture=load(str(parsed["texture"])) as Texture2D
	if _live_texture!=null:_live_data=parsed
	return _live_data

static func sample_live(clip: String,direction: String,elapsed: float=0,distance: float=0,moving: bool=false) -> Dictionary:
	var data:=live_data()
	if data.is_empty():return {}
	var selected:="idle" if clip=="walk" and not moving else clip
	var sequence: Array=data["clips"].get(selected,{}).get(direction,[])
	var position:=0
	if selected=="walk_settle":
		if not data["settle_sequences"].has(direction):return {}
		var phase:=posmod(floori(fposmod(distance,float(data["walk_stride"]))/float(data["walk_stride"])*16)+int(data["walk_start_phase"]),16)
		sequence=data["settle_sequences"][direction][str(phase)]
	if sequence.is_empty():return {}
	if selected=="walk":position=posmod(floori(fposmod(distance,float(data["walk_stride"]))/float(data["walk_stride"])*sequence.size())+int(data["walk_start_phase"]),sequence.size())
	else:
		var times: Array=[]
		for i in range(sequence.size()):times.append(float(data["settle_seconds"][i]) if selected=="walk_settle" else float(data["durations"][sequence[i]]))
		var seconds:=0.0
		for t in times:seconds+=float(t)
		var remaining:=fposmod(maxf(0,elapsed),seconds) if selected.begins_with("idle") or selected=="stagger" else maxf(0,elapsed)
		while position<sequence.size()-1 and remaining>=float(times[position]):remaining-=float(times[position]);position+=1
	var frame:=int(sequence[position])
	var region: Array=data["frame_regions"][frame]
	var offset: Array=data["frame_offsets"][frame]
	return {"frame":frame,"pose":position,"clip":selected,"direction":direction,"texture":_live_texture,"region":Rect2(region[0],region[1],region[2],region[3]),"offset":Vector2(offset[0],offset[1]),"size":Vector2(region[2],region[3]),"contact_pose":data["contact_poses"].has(selected) and position==int(data["contact_poses"][selected])}

static func draw_live(canvas: CanvasItem,clip: String,direction: String,elapsed: float=0,distance: float=0,moving: bool=false) -> bool:
	var frame:=sample_live(clip,direction,elapsed,distance,moving)
	if frame.is_empty():return false
	canvas.draw_texture_rect_region(frame["texture"],Rect2(frame["offset"],frame["size"]),frame["region"])
	return true

static func walk_settings() -> Dictionary:
	if not _walk_data.is_empty():return _walk_data
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(WALK_MANIFEST))
	if not parsed is Dictionary:return {}
	_walk_texture=load(str(parsed["texture"])) as Texture2D
	if _walk_texture!=null:_walk_data=parsed
	return _walk_data

static func settle_duration() -> float:
	var seconds:=0.0
	for value in walk_settings()["settle_seconds"]:seconds+=float(value)
	return seconds

static func _load_art() -> bool:
	if _texture != null: return true
	if not FileAccess.file_exists(MANIFEST): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary: return false
	var path := str(parsed.get("texture", ""))
	if not path.begins_with("res://assets/sprites/") or path.contains("..") or not ResourceLoader.exists(path): return false
	_texture = load(path) as Texture2D
	_data = parsed
	return _texture != null

static func sample(clip: String, direction: String, elapsed: float = 0.0, distance: float = 0.0, moving: bool = false) -> Dictionary:
	if not _load_art(): return {}
	var selected := "idle" if clip == "walk" and not moving else clip
	var settings := walk_settings() if selected in ["walk","walk_settle"] else _data
	var texture := _walk_texture if selected in ["walk","walk_settle"] else _texture
	var clips: Dictionary = settings.get("clips", {})
	var directions: Dictionary = clips.get(selected, {})
	var sequence: Array = directions.get(direction, [])
	if selected=="walk_settle" and direction=="down_right":
		var phase:=posmod(floori(fposmod(distance,float(settings["walk_stride"]))/float(settings["walk_stride"])*16)+int(settings["walk_start_phase"]),16)
		sequence=settings["settle_sequences"][str(phase)]
	if sequence.is_empty(): return {}
	var position := 0
	if selected == "walk":
		var stride := float(settings["walk_stride"])
		position = posmod(floori(fposmod(distance,stride)/stride*sequence.size())+int(settings["walk_start_phase"]),sequence.size())
	elif selected != "idle":
		var remaining := maxf(0.0, elapsed)
		var times: Array = settings["settle_seconds"] if selected=="walk_settle" else []
		while position < sequence.size() - 1:
			var seconds:=float(times[position] if selected=="walk_settle" else settings["durations"][sequence[position]])
			if remaining<seconds:break
			remaining -= seconds
			position += 1
	var frame := int(sequence[position])
	var bounds: Array = settings["frame_regions"][frame]
	var pivot: Array = settings["pivot"]
	var contacts: Dictionary = settings.get("contact_frames", {"thrust": settings.get("contact_frame", -1)})
	return {"frame": frame, "pose": position, "clip": selected, "direction": direction,
		"region": Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3])),
		"offset": -Vector2(float(pivot[0]), float(pivot[1])), "texture": texture,
		"contact_pose": contacts.has(selected) and frame == int(contacts[selected])}

static func draw_actor(canvas: CanvasItem, clip: String, direction: String, elapsed: float = 0.0, distance: float = 0.0, moving: bool = false) -> bool:
	var frame := sample(clip, direction, elapsed, distance, moving)
	if frame.is_empty(): return false
	canvas.draw_texture_rect_region(frame["texture"], Rect2(frame["offset"], Vector2(160, 160)), frame["region"])
	return true
