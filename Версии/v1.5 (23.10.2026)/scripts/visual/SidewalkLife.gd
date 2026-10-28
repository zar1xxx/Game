extends Node2D
## Жизнь на тротуарах: фонари с мягким светом и прохожие.
## Прохожие создаются впереди камеры и удаляются, когда остаются позади.

const LAMP_STEP := 290.0

var _people: Array = []
var _t: float = 0.0
var _filled: bool = false
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
	var top := cam.global_position.y - Art.VIEW_H / 2.0
	var bottom := cam.global_position.y + Art.VIEW_H / 2.0
	# Поддерживаем ~10 прохожих в зоне видимости и чуть выше
	# В пустыне прохожих нет — только песок
	while _people.size() < (0 if Art.theme == "desert" else 10):
		var side := -1 if _rng.randf() < 0.5 else 1
		var lane_x := Art.CITY_LEFT_END + _rng.randf_range(12, Art.SIDEWALK_W - 12)
		if side > 0:
			lane_x = Art.ROAD_RIGHT + _rng.randf_range(12, Art.SIDEWALK_W - 12)
		_people.append({
			# При старте прохожие расставляются по всему экрану, потом — только выше него
			"pos": Vector2(lane_x, _rng.randf_range(top - 700, bottom if not _filled else top - 60)),
			"speed": _rng.randf_range(25, 55) * (1 if _rng.randf() < 0.5 else -1),
			"color": PEOPLE_COLORS[_rng.randi() % PEOPLE_COLORS.size()],
			"phase": _rng.randf() * TAU,
		})
	_filled = true
	for p in _people.duplicate():
		p.pos = p.pos + Vector2(0, p.speed * delta)
		if p.pos.y > bottom + 200 or p.pos.y < top - 1200:
			_people.erase(p)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var top := cam.global_position.y - Art.VIEW_H / 2.0 - 100
	var bottom := cam.global_position.y + Art.VIEW_H / 2.0 + 100

	# Прохожие
	for p in _people:
		var pos: Vector2 = p.pos
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

	if Art.theme == "desert":
		return
	# Фонари: столб на тротуаре, свет падает на дорогу (днём свет почти не виден)
	var lamp_power := 0.2 + 0.8 * Art.night
	var y := floorf(top / LAMP_STEP) * LAMP_STEP
	while y < bottom:
		for side in [-1, 1]:
			var base := Vector2(Art.ROAD_LEFT - 14, y) if side < 0 else Vector2(Art.ROAD_RIGHT + 14, y)
			var head := base + Vector2(34 * -side, 0)
			var flicker := 0.85 + 0.15 * sin(_t * 2.0 + y * 0.01 + side)
			Art.glow(self, head + Vector2(20 * -side, 0), 95, Color(1.0, 0.84, 0.55, 0.22 * flicker * lamp_power))
			draw_line(base, head, Color("3d4152"), 4.0)
			draw_circle(base, 6, Color("3d4152"))
			Art.rrect(self, Rect2(head - Vector2(9, 5), Vector2(18, 10)), Color("fff2c4"), 4)
		y += LAMP_STEP
