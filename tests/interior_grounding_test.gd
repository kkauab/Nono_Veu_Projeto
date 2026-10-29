extends SceneTree

## Projection and contact are checked independently from the Pixelorama/PNG
## equality test. A passing atlas export alone cannot prove a grounded room.
const InteriorArt = preload("res://scripts/world/interior_art.gd")
const Interior = preload("res://scripts/world/house_interior.gd")
const Catalog = preload("res://scripts/world/house_catalog.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const MANIFEST := "res://assets/world/interiors_v4_manifest.json"
const LONG := ["counter", "shelf_a", "shelf_b", "furnace", "rack", "cords", "trade_chest"]
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("Run with -- --qa")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for name in LONG:
		_check(InteriorArt.has(name), name + " uses exported native art")
		var metadata: Dictionary = manifest.get("sprites", {}).get(name, {})
		var declared: Array = metadata.get("ground_base", [])
		var base: PackedVector2Array = InteriorArt.footprint(name)
		_check(base.size() == 4 and declared.size() == 4, name + " declares its ground base in the exported manifest")
		if base.size() != 4 or declared.size() != 4:
			continue
		var center := Vector2.ZERO
		var edges_on_grid := true
		var matches := true
		for index in range(4):
			center += base[index]
			var vertex: Array = declared[index]
			if vertex.size() != 2 or base[index].distance_to(Vector2(float(vertex[0]), float(vertex[1]))) > .001:
				matches = false
			var delta := base[(index + 1) % 4] - base[index]
			if absf(delta.x) < .001 or absf(absf(delta.y / delta.x) - .5) > .001:
				edges_on_grid = false
		_check(matches, name + " runtime base matches its art metadata")
		_check(edges_on_grid, name + " follows the floor's exact 2:1 axes")
		_check((center / 4.0).length() < .001, name + " is centered on its ground anchor")
	# Instantiate actual furniture without a save, enemies or a mock world.
	for kind in ["counter", "shelf", "furnace", "rack", "cords", "trade_chest", "amphora", "table"]:
		var piece := Interior.Furniture.new()
		piece.kind = kind
		piece.position = Vector2(400, 300)
		root.add_child(piece)
		var base: PackedVector2Array = piece.ground_footprint()
		var solid: CollisionPolygon2D
		var shade: Interior.Furniture.ContactShadow
		for child in piece.get_children():
			if child is Interior.Furniture.ContactShadow:
				shade = child
			if child is StaticBody2D:
				for shape in child.get_children():
					if shape is CollisionPolygon2D: solid = shape
		_check(solid != null and solid.polygon == base, kind + " collision uses the same ground contact as its drawing")
		var touches := shade != null and not shade.polygons.is_empty()
		if touches:
			for point in base:
				var covered := false
				for polygon in shade.polygons:
					if Geometry2D.is_point_in_polygon(point, polygon): covered = true
				if not covered: touches = false
		_check(touches and shade.z_index < 0, kind + " has a contact shadow covering its feet below the sprite")
		piece.queue_free()
	for house_id in Catalog.HOUSES:
		var house: Dictionary = Catalog.HOUSES[house_id]
		var inside := true
		var limits := Rect2(Vector2(house["origin"]) - Vector2(.48, .48), Vector2(house["size"]) - Vector2(.04, .04))
		for entry in house["furniture"]:
			var piece := Interior.Furniture.new()
			piece.kind = entry[0]
			piece.position = Layout.iso(entry[1])
			piece.fit_to_floor(house)
			for point in piece.ground_footprint():
				if not limits.has_point(Layout.unproject(piece.position + point)): inside = false
			piece.free()
		_check(inside, house_id + " keeps every furniture foot inside the floor, away from walls")
	await process_frame
	print("INTERIOR GROUNDING checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
