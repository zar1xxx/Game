extends "res://scripts/events/RoadEvent.gd"
## Омск: весеннее половодье. Иртыш вышел из берегов — по краям вода вместо кварталов,
## а на дороге огромные лужи. В воде машина вязнет и теряет скорость.
## Сухая полоса петляет — нужно лавировать. Проехали, не замочив колёс, — бонус.

const START := 260.0
const ROWS := 7
const ROW_STEP := 240.0
const WATER := Color(0.2, 0.4, 0.58, 0.92)
const WATER_ROAD := Color(0.24, 0.45, 0.64, 0.88)

var blobs: Array = []          # {"c": Vector2 (локально), "r": Vector2, "pts": PackedVector2Array}
var _wet: bool = false
var _spray_t: float = 0.0
var _splash_t: float = 0.0


func _init() -> void:
	kind = "flood"
	length = START + ROWS * ROW_STEP + 220.0
	spawn_policy = "enemies"
	clear_all_lanes = true


func start() -> void:
	toast("Весеннее половодье! В воде машина вязнет — ищи сухую полосу", Art.BLUE, 3.0)
	_build_blobs()


func _build_blobs() -> void:
	var dry := randi() % Art.LANES
	for row in ROWS:
		var y := -(START + row * ROW_STEP + randf_range(0.0, 50.0))
		# Сухая полоса смещается на соседнюю, чтобы приходилось маневрировать
		if row > 0:
			dry = clampi(dry + [-1, 1].pick_random(), 0, Art.LANES - 1)
		var groups := []
		if dry > 0:
			groups.append([0, dry - 1])
		if dry < Art.LANES - 1:
			groups.append([dry + 1, Art.LANES - 1])
		for g in groups:
			var x0 := lane_left(g[0]) + (0.0 if g[0] == 0 else 0.0)
			var x1 := lane_right(g[1])
			# Отступ от сухой полосы, чтобы машина проходила впритирку, но проходила
			if g[1] < dry:
				x1 -= 14.0
			if g[0] > dry:
				x0 += 14.0
			var c := Vector2((x0 + x1) / 2.0, y)
			var r := Vector2((x1 - x0) / 2.0 + 6.0, randf_range(70.0, 105.0))
			var pts := PackedVector2Array()
			for i in 22:
				var a := TAU * i / 22.0
				var rr := randf_range(0.88, 1.05)
				pts.append(c + Vector2(cos(a) * r.x * minf(rr, 1.0), sin(a) * r.y * rr))
			blobs.append({"c": c, "r": r, "pts": pts})


func _in_water(local: Vector2) -> bool:
	for b in blobs:
		var d: Vector2 = (local - b.c) / b.r
		if d.length_squared() < 0.85:
			return true
	return false


func _update(p, delta: float) -> void:
	var local: Vector2 = p.global_position - Vector2(0, global_position.y)
	var wet := false
	for off in [-p.CAR_LENGTH * 0.3, 0.0, p.CAR_LENGTH * 0.3]:
		if _in_water(local + Vector2(0, off)):
			wet = true
			break
	if not wet:
		return
	if not _wet:
		_wet = true
	var cruise: float = p.get_cruise_speed()
	p.current_speed = move_toward(p.current_speed, cruise * 0.45, 1300.0 * delta)
	_spray_t -= delta
	if _spray_t <= 0.0:
		_spray_t = 0.06
		_spray(p)
	_splash_t -= delta
	if _splash_t <= 0.0:
		_splash_t = 0.5
		Sound.play("splash", -9.0, randf_range(0.9, 1.1), 0.0)
		MobileInput.vibrate(15)


## Брызги из-под колёс
func _spray(p) -> void:
	for sx in [-1.0, 1.0]:
		var puff := Sprite2D.new()
		puff.texture = Art.glow_texture()
		puff.modulate = Color(0.8, 0.9, 1.0, 0.6)
		puff.scale = Vector2.ONE * 0.22
		puff.z_index = 2
		get_tree().current_scene.add_child(puff)
		puff.global_position = p.to_global(Vector2(sx * p.CAR_WIDTH * 0.45, p.CAR_LENGTH * 0.2))
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "scale", Vector2.ONE * randf_range(0.5, 0.8), 0.5)
		tw.tween_property(puff, "modulate:a", 0.0, 0.5)
		tw.tween_property(puff, "global_position", puff.global_position + Vector2(sx * randf_range(40, 80), randf_range(40, 90)), 0.5)
		tw.chain().tween_callback(puff.queue_free)


func _on_finished(_p) -> void:
	if not _wet:
		add_score(80)
		Sound.play("record", -6.0, 1.15, 0.0)
		toast("Сухим из воды! +80", Art.GREEN, 2.2)
	else:
		toast("Половодье позади. Колёса помыли бесплатно", Art.BLUE, 2.0)


func hud_info(p) -> Dictionary:
	if p.global_position.y < top_y() or p.global_position.y - global_position.y > 500.0:
		return {}
	return {"title": "Половодье", "text": "Объезжай лужи — в воде вязнешь", "color": Art.BLUE}


func _draw() -> void:
	var top := -length
	var bottom := -START + 160.0
	# Затопленные кварталы по краям
	for rect in [Rect2(-600, top, 600 + Art.ROAD_LEFT - 8, bottom - top), Rect2(Art.ROAD_RIGHT + 8, top, 1400, bottom - top)]:
		draw_rect(rect, WATER)
	# Волнистая «береговая линия» внизу и вверху
	for edge_y in [bottom, top]:
		var x := -600.0
		while x < 1800.0:
			if x < Art.ROAD_LEFT - 8 or x > Art.ROAD_RIGHT + 8:
				draw_circle(Vector2(x, edge_y), 22, WATER)
			x += 34.0
	# Рябь
	var k := 0
	var y := top + 30.0
	while y < bottom:
		var off := sin(_t * 1.5 + k) * 10.0
		draw_line(Vector2(40 + Art.hash01(k) * 120 + off, y), Vector2(80 + Art.hash01(k) * 120 + off, y), Color(1, 1, 1, 0.2), 2.0)
		draw_line(Vector2(Art.ROAD_RIGHT + 60 + Art.hash01(k + 9) * 160 + off, y), Vector2(Art.ROAD_RIGHT + 100 + Art.hash01(k + 9) * 160 + off, y), Color(1, 1, 1, 0.2), 2.0)
		y += 52.0
		k += 1
	# Торчащие из воды крыши, лавочка и знак «Купаться запрещено»
	for i in 3:
		var ry := top + 300 + i * 520
		Art.rrect(self, Rect2(Art.ROAD_LEFT - 200, ry, 120, 90), Art.ROOF_COLORS[i % Art.ROOF_COLORS.size()].darkened(0.1), 6, 2, Art.INK)
		Art.rrect(self, Rect2(Art.ROAD_RIGHT + 90, ry + 220, 130, 80), Art.ROOF_COLORS[(i + 2) % Art.ROOF_COLORS.size()].darkened(0.1), 6, 2, Art.INK)
	draw_plate(Rect2(Art.ROAD_RIGHT + 14, bottom - 120, 64, 34), Art.RED, "КУПАТЬСЯ\nЗАПРЕЩЕНО", Art.LINE_WHITE, 7)
	# Лодка с рыбаком
	var boat := Vector2(Art.ROAD_LEFT - 110 + sin(_t * 0.5) * 30, top + 900 + cos(_t * 0.4) * 40)
	draw_set_transform(boat, 0.25, Vector2.ONE)
	Art.rrect(self, Rect2(-20 + 4, -46 + 6, 40, 92), Color(0, 0, 0, 0.25), 18)
	Art.rrect(self, Rect2(-20, -46, 40, 92), Color("8a5a3a"), 18, 3, Color("4a2f1f"))
	draw_rect(Rect2(-14, -8, 28, 6), Color("4a2f1f"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_person(boat + Vector2(0, 14), Color("4f7a74"), Color("e8b48a"), 0.25, Color("2f3242"))
	draw_line(boat + Vector2(6, 6), boat + Vector2(70, -60), Color("c9b48a"), 2.0)
	# Уточки
	for i in 4:
		var dp := Vector2(Art.ROAD_RIGHT + 60 + i * 26 + sin(_t + i) * 6, top + 600 + i * 14)
		draw_circle(dp + Vector2(2, 3), 7, Color(0, 0, 0, 0.25))
		draw_circle(dp, 7, Art.YELLOW)
		draw_circle(dp + Vector2(0, -6), 4, Art.YELLOW)
		draw_circle(dp + Vector2(0, -10), 2, Art.ORANGE)
	# Лужи на дороге
	for b in blobs:
		var pts: PackedVector2Array = b.pts
		var wet_edge := PackedVector2Array()
		for p in pts:
			wet_edge.append(b.c + (p - b.c) * 1.12)
		draw_colored_polygon(wet_edge, Color(0.1, 0.12, 0.18, 0.35))
		draw_colored_polygon(pts, WATER_ROAD)
		var shine: Vector2 = b.c + Vector2(sin(_t + b.c.y) * 10.0, -b.r.y * 0.3)
		draw_line(shine - Vector2(b.r.x * 0.4, 0), shine + Vector2(b.r.x * 0.2, 0), Color(1, 1, 1, 0.25), 3.0)
		draw_arc(b.c + Vector2(b.r.x * 0.2, b.r.y * 0.2), 14 + fmod(_t * 12.0 + b.c.x, 18.0), 0, TAU, 20, Color(1, 1, 1, 0.15), 2.0)
