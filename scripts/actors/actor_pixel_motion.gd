extends RefCounted
## Visual displacement only. The node, ground pivot and collider never move.
## One-pixel destination rows retain nearest sampling; inverse Y sampling keeps
## the torso connected when a breath lifts its top by one pixel.


static func offset_at(y: float, upper: Vector2, middle: Vector2, foot_lock: float = 8.0) -> Vector2:
	return _offset_continuous(y, upper.round(), middle.round(), foot_lock).round()


static func draw_frame(canvas: Node2D, texture: Texture2D, offset: Vector2, size: Vector2, region: Rect2, tint: Color, upper_offset: Vector2, middle_offset: Vector2, foot_lock: float = 8.0) -> void:
	var upper := upper_offset.round()
	var middle := middle_offset.round()
	if upper == Vector2.ZERO and middle == Vector2.ZERO:
		canvas.draw_texture_rect_region(texture, Rect2(offset, size), region, tint)
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var feet_y := -maxf(.1, foot_lock)
	var upper_y := feet_y - 20.0
	var source_end := offset.y + size.y
	# Constant head and foot sections each need one draw, leaving only the
	# twenty-pixel torso transition split into rows, even for large atlases.
	var top_end := minf(source_end, upper_y)
	if top_end > offset.y:
		_draw_band(canvas, texture, offset, size, region, tint, offset.y, top_end, offset.y + upper.y, top_end + upper.y, upper.x)
	var middle_start := maxf(offset.y, upper_y)
	var middle_end := minf(source_end, feet_y)
	if middle_end > middle_start:
		var destination_start := middle_start + _offset_continuous(middle_start, upper, middle, foot_lock).y
		var destination_end := middle_end + _offset_continuous(middle_end, upper, middle, foot_lock).y
		for row in range(floori(destination_start), ceili(destination_end)):
			var start := maxf(float(row), destination_start)
			var end := minf(float(row + 1), destination_end)
			var source_start := clampf(_source_y(start, upper, middle, foot_lock), middle_start, middle_end)
			var source_finish := clampf(_source_y(end, upper, middle, foot_lock), middle_start, middle_end)
			var source_center := (source_start + source_finish) * .5
			var shift_x := roundf(_offset_continuous(source_center, upper, middle, foot_lock).x)
			_draw_band(canvas, texture, offset, size, region, tint, source_start, source_finish, start, end, shift_x)
	var feet_start := maxf(offset.y, feet_y)
	if source_end > feet_start:
		_draw_band(canvas, texture, offset, size, region, tint, feet_start, source_end, feet_start, source_end, 0.0)


static func _offset_continuous(y: float, upper: Vector2, middle: Vector2, foot_lock: float) -> Vector2:
	var feet_y := -maxf(.1, foot_lock)
	if y >= feet_y:
		return Vector2.ZERO
	var middle_y := feet_y - 8.0
	if y >= middle_y:
		return middle * smoothstep(0.0, 1.0, (feet_y - y) / 8.0)
	return middle.lerp(upper, smoothstep(0.0, 1.0, (middle_y - y) / 12.0))


static func _source_y(destination_y: float, upper: Vector2, middle: Vector2, foot_lock: float) -> float:
	var source := destination_y
	# Displacements are capped by the presentation callers to a few pixels.
	# Fixed-point inversion converges without a frame-rate-dependent state.
	for iteration in range(6):
		source = destination_y - _offset_continuous(source, upper, middle, foot_lock).y
	return source


static func _draw_band(canvas: Node2D, texture: Texture2D, offset: Vector2, size: Vector2, region: Rect2, tint: Color, source_start: float, source_end: float, destination_start: float, destination_end: float, shift_x: float) -> void:
	if source_end <= source_start or destination_end <= destination_start:
		return
	var source_region := Rect2(region.position + Vector2(0.0, (source_start - offset.y) / size.y * region.size.y), Vector2(region.size.x, (source_end - source_start) / size.y * region.size.y))
	var destination := Rect2(Vector2(offset.x + shift_x, destination_start), Vector2(size.x, destination_end - destination_start))
	canvas.draw_texture_rect_region(texture, destination, source_region, tint)
