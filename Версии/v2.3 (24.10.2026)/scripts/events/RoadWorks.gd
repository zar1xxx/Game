extends "res://scripts/events/RoadEvent.gd"
## Ремонт дороги: одна-две полосы перекрыты ограждениями на длинном участке.
## Внутри — свежий асфальт, каток и рабочие. Въехать туда можно только через ограждение
## (больно), а если всё же оказались внутри — рабочие ругаются, машина вязнет.

const BarrierScene := preload("res://scenes/obstacles/RoadBarrier.tscn")
const START := 470.0
const WORK_LEN := 1300.0

var lanes: Array = []
var _cooldown: float = 0.0
var _x0: float = 0.0
var _x1: float = 0.0
var _workers: Array = []


func _init() -> void:
	kind = "roadworks"
	length = START + WORK_LEN + 200.0


func setup(first_lane: int, n: int) -> void:
	lanes = []
	for i in n:
		lanes.append(first_lane + i)
	lanes_blocked = lanes.duplicate()
	_x0 = lane_left(lanes[0])
	_x1 = lane_right(lanes[-1])
	for i in 3:
		_workers.append({"x": randf_range(_x0 + 30, _x1 - 30), "y": -(START + 200 + i * 360 + randf_range(0, 120)),
			"a": randf_range(-PI, PI), "ph": randf() * TAU})


func start() -> void:
	toast("Дорожные работы! Полосы перекрыты — перестраивайся", Art.YELLOW, 2.6)
	call_deferred("_place_barriers")


func _place_barriers() -> void:
	for d in [START, START + WORK_LEN]:
		var b = BarrierScene.instantiate()
		b.width = _x1 - _x0 - 14.0
		b.global_position = Vector2((_x0 + _x1) / 2.0, wy(d))
		get_tree().current_scene.add_child(b)


func _update(p, delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var x: float = p.global_position.x
	var y: float = p.global_position.y
	if x > _x0 + 10.0 and x < _x1 - 10.0 and y < wy(START) - 20.0 and y > wy(START + WORK_LEN) + 20.0:
		if _cooldown <= 0.0:
			_cooldown = 0.9
			p.hit_hazard(5.0, 0.7, 6.0)
			toast(["Рабочие: «Куда прёшь?! Асфальт свежий!»", "Каток в шоке. Мастер звонит начальству",
				"Тут вообще-то ремонт! −прочность", "Свежий асфальт теперь с отпечатком ваших шин"].pick_random(), Art.RED, 1.8)


func hud_info(p) -> Dictionary:
	var y: float = p.global_position.y
	if y < wy(START + WORK_LEN) or y - global_position.y > 600.0:
		return {}
	return {"title": "Дорожные работы", "text": "Перекрыто: объезжай", "color": Art.YELLOW, "lanes_closed": lanes}


func get_lights() -> Array:
	var out := []
	for d in [START, START + WORK_LEN * 0.5, START + WORK_LEN]:
		out.append([Vector2((_x0 + _x1) / 2.0, wy(d)), 150.0, 0.8])
	return out


func _draw() -> void:
	var top := -(START + WORK_LEN)
	var bottom := -START
	# Свежий асфальт на закрытых полосах
	draw_rect(Rect2(_x0 + 6, top, _x1 - _x0 - 12, bottom - top), Color("22242e"))
	var y := top + 30.0
	while y < bottom - 20.0:
		draw_line(Vector2(_x0 + 14, y), Vector2(_x1 - 14, y + 6), Color(1, 1, 1, 0.04), 3.0)
		y += 44.0
	# Конусы вдоль границ с открытыми полосами и «косынки» на въезде/выезде
	var open_left: bool = lanes[0] > 0
	var open_right: bool = lanes[-1] < Art.LANES - 1
	y = top
	while y <= bottom:
		if open_left:
			draw_cone(Vector2(_x0 + 6, y), 0.85)
		if open_right:
			draw_cone(Vector2(_x1 - 6, y), 0.85)
		y += 80.0
	for k in 5:
		var t := float(k) / 4.0
		var cy := bottom + 260.0 * (1.0 - t)
		var edge_x: float = _x1 if not open_right else _x0
		var far_x: float = _x0 if not open_right else _x1
		draw_cone(Vector2(lerpf(edge_x, far_x, t * 0.9 + 0.05), cy), 0.8)
	# Каток ездит туда-сюда
	var roll_y := lerpf(bottom - 220.0, top + 260.0, 0.5 + 0.5 * sin(_t * 0.35))
	var rx := (_x0 + _x1) / 2.0
	Art.rrect(self, Rect2(rx - 34 + 6, roll_y - 50 + 8, 68, 100), Art.SHADOW, 8)
	Art.rrect(self, Rect2(rx - 32, roll_y - 50, 64, 26), Color("8a8f9c"), 10, 2, Art.INK)          # передний валец
	Art.rrect(self, Rect2(rx - 32, roll_y + 24, 64, 26), Color("8a8f9c"), 10, 2, Art.INK)          # задний валец
	Art.rrect(self, Rect2(rx - 24, roll_y - 30, 48, 58), Art.YELLOW, 6, 2, Art.YELLOW.darkened(0.45))
	Art.rrect(self, Rect2(rx - 16, roll_y - 12, 32, 22), Art.GLASS, 4)
	draw_circle(Vector2(rx + 12, roll_y - 22), 4, Art.ORANGE if int(_t * 3.0) % 2 == 0 else Color("6a3a10"))
	# Куча щебня и рабочие в оранжевых жилетах
	var pile := Vector2(_x0 + (_x1 - _x0) * 0.3, top + 140)
	for k in 7:
		draw_circle(pile + Vector2(cos(k * 1.7) * 18, sin(k * 2.3) * 12), 16, Color("8d8576").darkened(k * 0.03))
	for w in _workers:
		var wobble := sin(_t * 3.0 + w.ph) * 0.4
		draw_person(Vector2(w.x, w.y), Art.ORANGE, Color("e8b48a"), w.a + wobble, Art.YELLOW)
		var dir := Vector2.from_angle(w.a + wobble - PI / 2.0)
		draw_line(Vector2(w.x, w.y) + dir * 8, Vector2(w.x, w.y) + dir * 26, Color("6d5a3a"), 3.0)
	# Знаки «Дорожные работы» и «Сужение» на тротуаре со стороны перекрытия
	var sx: float = Art.ROAD_RIGHT + 24 if lanes[-1] >= Art.LANES / 2 else Art.ROAD_LEFT - 24
	var tri_c := Vector2(sx, -10)
	var tri := PackedVector2Array([tri_c + Vector2(0, -24), tri_c + Vector2(22, 16), tri_c + Vector2(-22, 16)])
	draw_colored_polygon(PackedVector2Array(Array(tri).map(func(v): return v + Vector2(4, 6))), Art.SHADOW)
	draw_colored_polygon(tri, Art.RED)
	var inner := PackedVector2Array(Array(tri).map(func(v): return tri_c + (v - tri_c) * 0.7 + Vector2(0, 2)))
	draw_colored_polygon(inner, Art.LINE_WHITE)
	draw_circle(tri_c + Vector2(-2, -2), 3.5, Art.INK)
	draw_line(tri_c + Vector2(-2, 1), tri_c + Vector2(4, 9), Art.INK, 2.5)
	draw_line(tri_c + Vector2(2, 6), tri_c + Vector2(8, 4), Art.INK, 2.0)
	draw_plate(Rect2(sx - 22, 30, 44, 20), Art.LINE_WHITE, "500 м", Art.INK, 9)
