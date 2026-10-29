extends "res://scripts/events/RoadEvent.gd"
## Железнодорожный переезд (промзона — состав с цистернами, дачи — электричка).
## Когда машина подъезжает, звенит звонок, мигают красные огни и опускаются шлагбаумы.
## Поезд приходит чуть раньше, чем машина доехала бы на своей скорости:
##   • затормозить у стоп-линии и переждать — безопасно (+30 за терпение);
##   • проскочить до поезда (нитро!) — +40 и уважение;
##   • выехать на рельсы, когда идёт состав, — удар: −35% прочности, машину отбрасывает назад.

const CROSS := 1900.0            # где рельсы (от начала события)
const STOP_LINE := 1780.0
const RAIL_BAND := 46.0          # полуширина полосы с рельсами
const TRAIN_SPEED := 760.0

var electric: bool = false        # электричка (дачи) или товарный состав (промзона)
var _bell_t: float = -1.0         # сколько секунд звенит звонок (−1 — ещё не начал)
var _arrive: float = 2.2          # когда голова поезда выходит на дорогу (от начала звонка)
var _train_len: float = 1500.0
var _dir: float = 1.0
var _resolved: bool = false       # проскочили / пострадали / дождались
var _hit_done: bool = false
var _bell: AudioStreamPlayer
var _clack: AudioStreamPlayer
var _horned: bool = false


func _init() -> void:
	kind = "rail"
	length = CROSS + 200.0
	spawn_policy = "none"
	clear_all_lanes = true


func start() -> void:
	electric = Art.theme == "dacha"
	_train_len = 1150.0 if electric else 1650.0
	_dir = 1.0 if randf() < 0.5 else -1.0
	toast("Впереди железнодорожный переезд!" if not electric else "Переезд! Электричка «Дачная» идёт по расписанию", Art.YELLOW, 2.4)


## Где голова поезда по оси x (в мировых координатах дороги)
func _head_x() -> float:
	var t := _bell_t - _arrive
	if _dir > 0.0:
		return Art.ROAD_LEFT - 40.0 + t * TRAIN_SPEED
	return Art.ROAD_RIGHT + 40.0 - t * TRAIN_SPEED


## Поезд сейчас на дороге
func train_on_road() -> bool:
	if _bell_t < _arrive:
		return false
	var head := _head_x()
	var tail := head - _dir * _train_len
	var lo := minf(head, tail)
	var hi := maxf(head, tail)
	return hi > Art.ROAD_LEFT - 20.0 and lo < Art.ROAD_RIGHT + 20.0


func train_gone() -> bool:
	if _bell_t < _arrive:
		return false
	var tail := _head_x() - _dir * _train_len
	return (tail > Art.ROAD_RIGHT + 40.0) if _dir > 0.0 else (tail < Art.ROAD_LEFT - 40.0)


func _barrier_closed() -> float:
	if _bell_t < 0.0:
		return 0.0
	if train_gone():
		return clampf(1.0 - (_bell_t - _gone_at) / 0.8, 0.0, 1.0)
	return clampf((_bell_t - 0.3) / 0.8, 0.0, 1.0)


var _gone_at: float = 9999.0


func _update(p, delta: float) -> void:
	var front: float = p.global_position.y - p.CAR_LENGTH * 0.5
	var rear: float = p.global_position.y + p.CAR_LENGTH * 0.5
	var dist: float = front - wy(CROSS)
	if _bell_t < 0.0:
		# Чем быстрее едем, тем раньше звенит звонок — чтобы успеть затормозить
		var v: float = maxf(p.current_speed, 300.0)
		if dist < clampf(v * 1.9, 1300.0, 1850.0):
			_bell_t = 0.0
			# Поезд приходит чуть раньше машины: нужно решить — тормозить или жать нитро
			_arrive = clampf(dist / v * 0.88, 1.4, 3.4)
			_bell = Sound.make_loop(self, "bell", -6.0)
			_bell.play()
		return
	_bell_t += delta
	if not _horned and _bell_t > _arrive - 0.9:
		_horned = true
		Sound.play("train_horn", -2.0, 0.85 if not electric else 1.15, 0.0)
		_clack = Sound.make_loop(self, "train", -6.0)
		_clack.play()
	if train_gone() and _gone_at > 9000.0:
		_gone_at = _bell_t
		if _bell:
			_bell.stop()
		if _clack:
			_clack.stop()
	if _resolved:
		return
	var on_rails: bool = front < wy(CROSS) + RAIL_BAND and rear > wy(CROSS) - RAIL_BAND
	if on_rails and train_on_road():
		_train_hit(p)
		return
	# Машина целиком за рельсами
	if rear < wy(CROSS) - RAIL_BAND:
		_resolved = true
		if _bell_t < _arrive:
			add_score(40)
			Missions.event("rail")
			popup_at_player("+40", Art.TEAL)
			toast(["Проскочили перед самым поездом! +40", "Машинист покрутил пальцем у виска. +40"].pick_random(), Art.TEAL, 2.2)
		else:
			add_score(30)
			popup_at_player("+30", Art.GREEN)
			toast("Пропустили поезд — молодец, правила знаешь! +30", Art.GREEN, 2.2)


func _train_hit(p) -> void:
	_resolved = true
	_hit_done = true
	Sound.play("crash", 2.0, 0.7, 0.0)
	p.shake_camera(16.0)
	MobileInput.vibrate(220)
	# Отбрасывает назад, к стоп-линии
	var back: float = wy(STOP_LINE) + p.CAR_LENGTH * 0.6 + 40.0
	p.global_position.y = back
	p.velocity = Vector2.ZERO
	p.current_speed = 150.0
	p.take_damage(p.max_health * 0.35)
	if not p.is_dead:
		p.start_invulnerability(2.0)
		toast("Бам! Поезд всегда прав: −35% прочности", Art.RED, 2.6)


func _is_done(p) -> bool:
	return train_gone() and p.global_position.y < top_y() - 250.0


func _on_finished(_p) -> void:
	if _bell:
		_bell.stop()
	if _clack:
		_clack.stop()


func hud_info(p) -> Dictionary:
	if _resolved or _bell_t < 0.0:
		return {}
	var dist: float = p.global_position.y - wy(CROSS)
	var left := maxf(_arrive - _bell_t, 0.0)
	if train_on_road():
		return {"title": "Переезд закрыт!", "text": "Идёт поезд — стой до стоп-линии", "color": Art.RED, "dist": dist * 0.1}
	return {"title": "Ж/д переезд", "text": "Поезд через %.1f с — тормози или проскакивай!" % left,
		"color": Art.YELLOW, "dist": dist * 0.1}


func get_lights() -> Array:
	var out := []
	var on := _bell_t >= 0.0 and not train_gone() and fmod(_bell_t, 0.6) < 0.3
	for x in [Art.ROAD_LEFT - 24.0, Art.ROAD_RIGHT + 24.0]:
		out.append([Vector2(x, wy(STOP_LINE)), 120.0 if on else 60.0, 0.9])
	if train_on_road():
		out.append([Vector2(_head_x(), wy(CROSS)), 260.0, 1.0])
	return out


func _draw() -> void:
	var L := Art.ROAD_LEFT
	var R := Art.ROAD_RIGHT
	var cy := -CROSS
	# Знак «Железнодорожный переезд без шлагбаума» заранее
	var sy := -160.0
	for x in [L - 30.0, R + 30.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(x, sy - 26), Vector2(x - 24, sy + 16), Vector2(x + 24, sy + 16)]), Color.WHITE)
		draw_polyline(PackedVector2Array([Vector2(x, sy - 26), Vector2(x - 24, sy + 16), Vector2(x + 24, sy + 16), Vector2(x, sy - 26)]), Art.RED, 4.0)
		draw_rect(Rect2(x - 9, sy - 2, 18, 9), Art.INK)
		draw_circle(Vector2(x - 5, sy + 9), 3, Art.INK)
		draw_circle(Vector2(x + 5, sy + 9), 3, Art.INK)
	# Стоп-линия
	draw_rect(Rect2(L, -STOP_LINE - 4, R - L, 8), Color(Art.LINE_WHITE, 0.85))
	Art.text_center(self, Vector2((L + R) / 2.0, -STOP_LINE + 26), "СТОП", 22, Color(Art.LINE_WHITE, 0.7), true)
	# Рельсы и шпалы поперёк дороги (и дальше в стороны)
	draw_rect(Rect2(L - 700, cy - RAIL_BAND, R - L + 1400, RAIL_BAND * 2), Color("4a443c"))
	var x := L - 700.0
	while x < R + 700:
		draw_rect(Rect2(x, cy - RAIL_BAND + 6, 14, RAIL_BAND * 2 - 12), Color("6b4f36"))
		x += 30.0
	for ry in [cy - 18.0, cy + 18.0]:
		draw_rect(Rect2(L - 700, ry - 3, R - L + 1400, 6), Color("b9bdc8"))
	# Резиновый настил переезда на проезжей части
	draw_rect(Rect2(L, cy - RAIL_BAND + 4, R - L, RAIL_BAND * 2 - 8), Color(0.25, 0.25, 0.28, 0.85))
	for ry in [cy - 18.0, cy + 18.0]:
		draw_rect(Rect2(L, ry - 2, R - L, 4), Color("8a8f9c"))
	# Светофоры и шлагбаумы
	var on := _bell_t >= 0.0 and not train_gone() and fmod(_bell_t, 0.6) < 0.3
	var closed := _barrier_closed()
	var by := -STOP_LINE - 30.0
	for side in [-1.0, 1.0]:
		var pivot := Vector2(L - 24.0 if side < 0 else R + 24.0, by)
		Art.rrect(self, Rect2(pivot - Vector2(14, 34), Vector2(28, 30)), Art.INK, 5)
		draw_circle(pivot + Vector2(-6, -19), 6, Art.RED if on else Color("4a1a1a"))
		draw_circle(pivot + Vector2(6, -19), 6, Color("4a1a1a") if on else (Art.RED if _bell_t >= 0.0 and not train_gone() else Color("4a1a1a")))
		if _bell_t >= 0.0 and not train_gone():
			Art.glow(self, pivot + Vector2(-6 if on else 6, -19), 34, Color(1, 0.2, 0.2, 0.6))
		# Стрела: открыта — вдоль обочины, закрыта — поперёк половины дороги
		var ang := lerpf(-PI / 2.0, 0.0, closed) if side < 0 else lerpf(-PI / 2.0, -PI, closed)
		var dir := Vector2.from_angle(ang)
		var arm := (R - L) * 0.5 + 10.0
		var steps := 9
		for k in steps:
			var a := pivot + dir * (arm * k / steps)
			var b := pivot + dir * (arm * (k + 1) / steps)
			draw_line(a, b, Art.RED if k % 2 == 0 else Color.WHITE, 8.0)
		draw_circle(pivot, 9, Color("5d6274"))
	# Поезд
	if _bell_t >= _arrive and not train_gone():
		_draw_train(cy)


func _draw_train(cy: float) -> void:
	var head := _head_x()
	var car_len := 210.0 if electric else 170.0
	var gap := 12.0
	var n := int(_train_len / (car_len + gap))
	for i in n:
		var x1 := head - _dir * i * (car_len + gap)
		var x0 := x1 - _dir * car_len
		var r := Rect2(minf(x0, x1), cy - 30, car_len, 60)
		if r.end.x < Art.ROAD_LEFT - 900 or r.position.x > Art.ROAD_RIGHT + 900:
			continue
		Art.rrect(self, Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.3), 8)
		if electric:
			# Электричка: зелёные вагоны с красной полосой и окнами
			Art.rrect(self, r, Color("3f8f5a"), 10, 2, Color("1f4a2c"))
			draw_rect(Rect2(r.position.x + 4, r.get_center().y - 4, r.size.x - 8, 8), Color("c43a2e"))
			for k in int(r.size.x / 30.0):
				draw_rect(Rect2(r.position.x + 10 + k * 30, r.position.y + 8, 18, 10), Color("1c2333"))
				draw_rect(Rect2(r.position.x + 10 + k * 30, r.end.y - 18, 18, 10), Color("1c2333"))
			if i == 0:
				Art.text_center(self, r.get_center() + Vector2(0, -16), "ДАЧНАЯ", 12, Color("f2e6c8"), true)
		elif i == 0:
			# Тепловоз
			Art.rrect(self, r, Color("e86a2e"), 10, 2, Color("8a3a14"))
			draw_rect(Rect2(r.position.x + 6, r.get_center().y - 5, r.size.x - 12, 10), Color("f2c230"))
			for k in 4:
				draw_circle(Vector2(r.position.x + 30 + k * 36, r.get_center().y), 9, Color("5d6274"))
		else:
			# Цистерны
			Art.rrect(self, r, Color("23252d"), 26, 2, Art.INK)
			draw_line(Vector2(r.position.x + 12, r.get_center().y - 14), Vector2(r.end.x - 12, r.get_center().y - 14), Color(1, 1, 1, 0.12), 4.0)
			Art.text_center(self, r.get_center(), "НЕФТЬ", 13, Color("c9cdd6"), true)
	# Фары головного вагона
	var hx := head
	Art.glow(self, Vector2(hx + _dir * 10.0, cy), 60, Color(1, 0.95, 0.75, 0.6))
