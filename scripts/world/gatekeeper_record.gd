extends PortInteractable
## Small readable props, using the same interaction/collection flow as notes.
func _draw() -> void:
	if not active:return
	draw_colored_polygon(PackedVector2Array([Vector2(-8,0),Vector2(0,-4),Vector2(9,1),Vector2(1,5)]),Color("303936"))
	var paper:=kind=="gatekeeper_record" and item_id.ends_with("03")
	draw_colored_polygon(PackedVector2Array([Vector2(-6,-1),Vector2(2,-4),Vector2(7,0),Vector2(-1,3)]),Color("b1a083") if paper else Color("80613e"))
	for i in range(3):draw_line(Vector2(-3+i*2,-1+i),Vector2(1+i*2,-2+i),Color("594b3a") if paper else Color("b09562"),1)
	if highlighted:draw_arc(Vector2.ZERO,11,0,TAU,20,Color("c7ac73",.65),1)
