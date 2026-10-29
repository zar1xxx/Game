extends Node2D
## Жизнь на тротуарах: прохожие (фонари теперь рисует дорога — Road.gd).
## Прохожие создаются впереди камеры и удаляются, когда остаются позади.

var _people: Array = []
var _t: float = 0.0
var _filled: bool = false
var _frame: int = 0
var _rng := RandomNumberGenerator.new()
const PEOPLE_COLORS := [Color("e8505b"), Color("4d7cfe"), Color("ffc857"), Color("2ec4b6"),
	Color("c9cdd6"), Color("8e6cef"), Color("ff8a3d"), Color("5bbf72")]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var top := cam.global_position.y - Art.half_view_h()
	var bottom := cam.global_position.y + Art.half_view_h()
	# Поддерживаем ~10 прохожих в зоне видимости и чуть выше
	# В пустыне прохожих нет — только песок
	var crowd: int = {"desert": 0, "mountain": 0, "village": 4, "beach": 14, "taiga": 0, "ice": 2,
		"highway": 0, "metro": 3, "refinery": 3, "dacha": 7, "retro": 12}.get(Art.theme, 10)
	if Art.quality == 0:
		crowd /= 2
	while _people.size() < crowd:
		var side := -1 if _rng.randf() < 0.5 else 1
		var lane_x := Art.CITY_LEFT_END + _rng.randf_range(12, Art.SIDEWALK_W - 12)
		if side > 0:
			lane_x = Art.ROAD_RIGHT + _rng.randf_range(12, Art.SIDEWALK_W - 12)
		_people.append({
			# При старте прохожие расставляются по всему экрану, потом — только выше него
			"pos": Vector2(lane_x, _rng.randf_range(top - 700, bottom if not _filled else top - 60)),
			"speed": _rng.randf_range(25, 55) * (1 if _rng.randf() < 0.5 else -1),
			"color": _person_color(),
			"phase": _rng.randf() * TAU,
		})
	_filled = true
	var i := _people.size() - 1
	while i >= 0:
		var p: Dictionary = _people[i]
		p.pos = p.pos + Vector2(0, p.speed * delta)
		if p.pos.y > bottom + 200 or p.pos.y < top - 1200:
			_people.remove_at(i)
		i -= 1
	# Прохожие идут медленно — им хватает перерисовки через кадр
	_frame += 1
	if _frame % 2 == 0:
		queue_redraw()


## Одежда прохожих: в промзоне — рабочие в оранжевом, в Омске-1985 — выцветшие цвета
func _person_color() -> Color:
	match Art.theme:
		"refinery", "metro":
			return Color("ff8a3d") if _rng.randf() < 0.7 else Color("f2c230")
		"retro":
			return Art.RETRO_CAR_COLORS[_rng.randi() % Art.RETRO_CAR_COLORS.size()]
	return PEOPLE_COLORS[_rng.randi() % PEOPLE_COLORS.size()]


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var top := cam.global_position.y - Art.half_view_h() - 100
	var bottom := cam.global_position.y + Art.half_view_h() + 100

	# Прохожие (только те, что на экране)
	for p in _people:
		var pos: Vector2 = p.pos
		if pos.y < top or pos.y > bottom:
			continue
		var step := sin(_t * 8.0 + p.phase) * 3.0
		var dir := signf(p.speed)
		draw_circle(pos + Vector2(3, 4), 8, Color(0, 0, 0, 0.3))
		draw_line(pos + Vector2(-3, 0), pos + Vector2(-3, step * dir + 6 * dir), Art.INK, 3.0)
		draw_line(pos + Vector2(3, 0), pos + Vector2(3, -step * dir + 6 * dir), Art.INK, 3.0)
		draw_set_transform(pos, 0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, 8, p.color)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_circle(pos, 4.5, Color("f1c9a5"))
		draw_circle(pos + Vector2(0, -1), 4.5, Color("3a2a22"))
