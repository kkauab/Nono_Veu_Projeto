extends RefCounted
## Cosmetic, original pixel geometry around the existing gate and floor.
## No added collider or changed route: combat warnings retain the clear center.
class Names extends Node2D:
	var game: Node2D
	func _draw() -> void:
		var glowing:=is_instance_valid(game.boss) and int(game.boss.get("mode"))==6
		var color:=Color("333d38",.7) if not glowing else Color("aa9163",.45)
		for tile in [Vector2(-9,20),Vector2(-3,20),Vector2(-9,26),Vector2(-3,26),Vector2(-6,24)]:
			var at:=PortLayout.iso(tile)
			for row in range(3):
				for mark in range(4):
					var p:=at+Vector2(mark*4-row*3,row*2+mark*2)
					draw_line(p,p+Vector2(2,-1),color,1)
	func _process(_delta: float) -> void:
		if is_instance_valid(game.boss):queue_redraw()

class Monument extends Node2D:
	var gate: PortGate
	var clock:=0.0
	func _process(delta: float) -> void:
		clock+=delta
		if Engine.get_process_frames()%6==0:queue_redraw()
	func _draw() -> void:
		var a:=gate.end_a;var b:=gate.end_b
		for foot: Vector2 in [a,b]:
			draw_colored_polygon(PackedVector2Array([foot+Vector2(-8,0),foot+Vector2(1,5),foot+Vector2(10,0),foot+Vector2(1,-5)]),Color("343c39"))
			draw_rect(Rect2(foot+Vector2(-7,-82),Vector2(14,82)),Color("43504b"))
			draw_rect(Rect2(foot+Vector2(-7,-82),Vector2(4,80)),Color("586057"))
			for row in range(7):draw_line(foot+Vector2(-7,-row*12),foot+Vector2(7,-row*12),Color("303a36"),1)
			draw_line(foot+Vector2(-3,-70),foot+Vector2(-1,-62),Color("827556"),1)
			draw_line(foot+Vector2(-1,-62),foot+Vector2(-4,-49),Color("827556"),1)
			draw_rect(Rect2(foot+Vector2(-10,-87),Vector2(20,7)),Color("5e6558"))
			draw_line(foot+Vector2(-9,-87),foot+Vector2(9,-87),Color("a18a5e"),1)
			var flame:=foot+Vector2(2,-32)
			draw_rect(Rect2(flame+Vector2(-2,1),Vector2(5,3)),Color("705335"))
			draw_line(flame,flame+Vector2(sin(clock*5+foot.x),-6-absf(sin(clock*7))*2),Color("e0b874"),2)
		draw_line(a+Vector2(0,-86),b+Vector2(0,-86),Color("38433e"),8)
		draw_line(a+Vector2(0,-90),b+Vector2(0,-90),Color("867754"),2)
		for i in range(23):
			var t:=float(i)/22
			var p:=a.lerp(b,t)+Vector2(0,-78+sin(t*PI)*15)
			draw_arc(p,2,0,TAU,6,Color("9e8150"),1)
		var bell:=a.lerp(b,.5)+Vector2(0,-56)
		draw_line(bell+Vector2(0,-9),bell,Color("705335"),1)
		draw_colored_polygon(PackedVector2Array([bell+Vector2(-3,0),bell+Vector2(3,0),bell+Vector2(5,8),bell+Vector2(-5,8)]),Color("80613e"))
		draw_line(bell+Vector2(-5,8),bell+Vector2(5,8),Color("c3a268"),1)
		draw_rect(Rect2(bell+Vector2(-1,8),Vector2(2,3)),Color("a88a54"))

static func build(game: Node2D) -> void:
	var names:=Names.new()
	names.name="GatekeeperFloorNames"
	names.game=game
	game.layout.add_child(names)
	var monument:=Monument.new()
	monument.name="GuaritaDoRetorno"
	monument.gate=game.exit_gate
	monument.position=game.exit_gate.position
	game.actors.add_child(monument)
