extends Node2D
## Соперник «Колян на девятке». Время от времени догоняет сзади, обходит и
## предлагает гонку на километр. Обогнал его и на финише оказался впереди — награда.
## Колян не сталкивается с машинами (он «свой» на этой дороге), но объезжает пробки,
## а на прямой едет чуть медленнее чисто едущего игрока: побеждает тот, кто не бьётся.

const RACE_LEN := 10000.0        # 1 км (10 px = 1 м, как на спидометре и в событиях)
const LENGTH := 100.0
const WIDTH := 50.0
const REWARD_COINS := 120
const REWARD_SCORE := 80
const BODY := Color("8e1f3a")    # «вишня»

enum S { WAIT, INTRO, RACE, OUTRO }
var state: S = S.WAIT
var _next: float = 0.0
var _rng := RandomNumberGenerator.new()
var _player = null
var _lane: int = 1
var _x: float = 0.0
var _v: float = 0.0
var _finish_y: float = 0.0
var _slow_t: float = 0.0          # притормаживает, пока перестраивается
var _t: float = 0.0
var _last_ahead: int = 0          # кто был впереди: 1 — игрок, −1 — Колян
var _banter_cd: float = 0.0
var _hp_seen: float = -1.0
var _outro_dir: float = 1.0
var _bass: float = 0.0
var _redraw: int = 0
var _line: Node2D = null          # финишная черта (стоит на месте в мире)

const INTRO_LINES := [
	"Колян на девятке: «Э, на этой табуретке? Давай до финиша, кило́метр!»",
	"Колян: «Слышь, тачка — огонь. Почти как моя. Погнали на километр?»",
	"Колян на девятке врубил басы: «Кто первый через километр — тот и король района!»",
]
const PASSED_LINES := ["Колян: «Ничё-ничё, щас догоню!»", "Колян: «Это я тебя пропустил, из жалости»",
	"Колян: «Ах ты ж… Кузьмич, поддай басов!»"]
const OVERTAKE_LINES := ["Колян: «Учись, студент!»", "Колян: «Девятка — сила, а ты — могила»",
	"Колян: «Вижу тебя только в зеркале!»"]
const CRASH_LINES := ["Колян: «Ха! Страховка-то есть?»", "Колян: «Ну ты таран, конечно»",
	"Колян: «Аккуратнее, это ж не дрифт-шоу!»"]


func _ready() -> void:
	add_to_group("rival")
	add_to_group("lit")
	z_index = 1
	_rng.seed = SaveManager.run_seed * 13 + 4242
	_next = _rng.randf_range(40.0, 65.0)
	if Missions.is_active("rival"):
		_next = _rng.randf_range(18.0, 28.0)
	visible = false


func is_racing() -> bool:
	return state == S.RACE or state == S.INTRO


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if _player.is_dead and state != S.WAIT:
		return
	match state:
		S.WAIT:
			_wait(delta)
		S.INTRO, S.RACE:
			_drive(delta)
		S.OUTRO:
			_outro(delta)
	_redraw += 1
	if visible and _redraw % 2 == 0:
		queue_redraw()


func _score() -> int:
	var sc = _player.get_node_or_null("scoreComponent")
	return sc.max_score if sc else 0


func _wait(delta: float) -> void:
	if SaveManager.tutorial_running or _player.current_speed < 300.0:
		return
	_next -= delta
	if _next > 0.0:
		return
	if _score() < 200:
		_next = 6.0
		return
	# Не мешаем погоням и колонне фур
	var police = get_tree().get_first_node_in_group("police")
	var tck = get_tree().get_first_node_in_group("tck")
	var ev = get_tree().get_first_node_in_group("road_events")
	if (police and police.state != police.State.IDLE) or (tck and tck.is_active()) \
			or (ev and ev.busy() and ev.current.kind in ["convoy", "bridge", "flood"]):
		_next = 4.0
		return
	_begin()


func _begin() -> void:
	state = S.INTRO
	visible = true
	_lane = _free_lane_near(_player.global_position.y + 300.0, _lane_of(_player.global_position.x))
	_x = _lane_center(_lane)
	global_position = Vector2(_x, _player.global_position.y + Art.half_view_h() + 160.0)
	_v = _player.current_speed * 1.25
	_last_ahead = 1
	_hp_seen = _player.current_health
	_banter_cd = 0.0
	Sound.play("horn", -4.0, 0.8, 0.0)
	_toast(INTRO_LINES[_rng.randi() % INTRO_LINES.size()], Color("ff6b8a"), 3.4)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.call_deferred("_place_toast")


func _drive(delta: float) -> void:
	_banter_cd = maxf(0.0, _banter_cd - delta)
	_slow_t = maxf(0.0, _slow_t - delta)
	_bass += delta
	var cruise: float = _player.get_cruise_speed()
	var gap: float = global_position.y - _player.global_position.y   # > 0 — Колян позади
	var target: float
	if state == S.INTRO:
		target = cruise * 1.25
		if gap < -260.0:
			state = S.RACE
			_finish_y = global_position.y - RACE_LEN
			_last_ahead = -1
			_make_finish_line()
	else:
		# Чуть медленнее чисто едущего игрока; далеко отстал — поддаёт, далеко ушёл — ждёт
		var band := 1.0
		if gap > 650.0:
			band = 1.1
		elif gap < -750.0:
			band = 0.86
		target = cruise * 0.94 * band
	if _slow_t > 0.0:
		target *= 0.8
	_v = move_toward(_v, target, 420.0 * delta)
	global_position.y -= _v * delta
	_avoid_traffic()
	global_position.x = move_toward(global_position.x, _lane_center(_lane), 330.0 * delta)
	if state != S.RACE:
		return
	# Кто впереди — подколки при смене лидера
	var ahead := 1 if _player.global_position.y < global_position.y else -1
	if ahead != _last_ahead and absf(gap) > 60.0:
		_last_ahead = ahead
		if _banter_cd <= 0.0:
			_banter_cd = 4.0
			var lines: Array = PASSED_LINES if ahead == 1 else OVERTAKE_LINES
			_toast(lines[_rng.randi() % lines.size()], Color("ff6b8a"), 2.2)
			if ahead == -1:
				Sound.play("horn", -6.0, 0.85, 0.0)
	# Игрок разбился — Колян радуется
	if _player.current_health < _hp_seen - 4.0 and _banter_cd <= 0.0:
		_banter_cd = 4.0
		_toast(CRASH_LINES[_rng.randi() % CRASH_LINES.size()], Color("ff6b8a"), 2.0)
	_hp_seen = _player.current_health
	# Финиш: решает, кто первым пересёк черту
	var p_done: bool = _player.global_position.y <= _finish_y
	var r_done: bool = global_position.y <= _finish_y
	if p_done or r_done:
		_finish(p_done and (not r_done or _player.global_position.y < global_position.y))
	elif gap > 1700.0:
		_finish(true)        # Колян безнадёжно отстал
	elif gap < -2200.0:
		_finish(false)       # Колян умчал за горизонт


func _finish(won: bool) -> void:
	state = S.OUTRO
	_outro_dir = 1.0 if won else -1.0
	var hud = get_tree().get_first_node_in_group("hud")
	if won:
		SaveManager.add_coins(REWARD_COINS)
		var sc = _player.get_node_or_null("scoreComponent")
		if sc and sc.has_method("add_bonus"):
			sc.add_bonus(REWARD_SCORE)
		Missions.event("rival")
		Achievements.event("rival_win")
		Sound.play("record", -3.0, 1.1, 0.0)
		Pickup.burst(_player, Art.YELLOW, "+%d монет" % REWARD_COINS, "")
		_toast("Победа! Колян: «Ладно, ты король района… до завтра». +%d монет" % REWARD_COINS, Art.YELLOW, 3.2)
		if hud and hud.fx:
			hud.fx.confetti(90)
	else:
		Sound.play("horn", -4.0, 0.8, 0.0)
		_toast("Колян первым на финише: «Приходи, когда подкачаешься!» В следующий раз повезёт", Art.UI_MUTED, 3.0)
	if hud:
		hud.call_deferred("_place_toast")


## Победил — Колян сбрасывает скорость и уходит назад; проиграл — уезжает вперёд
func _outro(delta: float) -> void:
	var cruise: float = _player.get_cruise_speed()
	_v = move_toward(_v, cruise * (0.55 if _outro_dir > 0.0 else 1.3), 300.0 * delta)
	global_position.y -= _v * delta
	_avoid_traffic()
	global_position.x = move_toward(global_position.x, _lane_center(_lane), 330.0 * delta)
	var cam := get_viewport().get_camera_2d()
	if cam and absf(global_position.y - cam.global_position.y) > Art.half_view_h() + 400.0:
		_reset()


func _reset() -> void:
	state = S.WAIT
	visible = false
	if _line and is_instance_valid(_line):
		_line.queue_free()
	_line = null
	_next = _rng.randf_range(110.0, 170.0)


func _make_finish_line() -> void:
	_line = Node2D.new()
	_line.z_index = -4
	_line.position = Vector2(0, _finish_y)
	_line.draw.connect(func():
		var cell := 20.0
		var n := int(Art.ROAD_W / cell)
		for row in 2:
			for i in n:
				var c := Color.WHITE if (i + row) % 2 == 0 else Art.INK
				_line.draw_rect(Rect2(Art.ROAD_LEFT + i * cell, -cell * (row + 1), cell, cell), c)
		# Растяжка «ФИНИШ» над дорогой
		for x in [Art.ROAD_LEFT - 14.0, Art.ROAD_RIGHT + 6.0]:
			_line.draw_rect(Rect2(x, -70, 8, 70), Art.SILVER)
		var banner := Rect2(Art.ROAD_LEFT + Art.ROAD_W / 2.0 - 130, -110, 260, 40)
		Art.rrect(_line, banner, Color("8e1f3a"), 8, 3, Art.INK)
		Art.text_center(_line, banner.get_center(), "ФИНИШ • КОЛЯН", 20, Art.YELLOW, true))
	get_tree().current_scene.add_child(_line)


## Объезд: впереди на его полосе что-то есть (или игрок прямо перед носом) — перестраивается
var _avoid_tick: int = 0

func _avoid_traffic() -> void:
	_avoid_tick += 1
	if _avoid_tick % 3 != 0 or not _lane_busy(_lane, 380.0):
		return
	var best := -1
	for d in [1, -1, 2, -2]:
		var l: int = _lane + d
		if l >= 0 and l < Art.LANES and not _lane_busy(l, 380.0):
			best = l
			break
	if best >= 0:
		_lane = best
		_slow_t = 0.5
	else:
		_slow_t = 0.8


func _lane_busy(lane: int, ahead: float) -> bool:
	# Полосы, занятые событием (АЗС, пассажир, ремонт, колонна), Колян тоже объезжает
	var ev = get_tree().get_first_node_in_group("road_events")
	if ev and ev.is_lane_blocked(lane):
		return true
	var x0 := Art.ROAD_LEFT + lane * Art.LANE_W
	var x1 := x0 + Art.LANE_W
	var y := global_position.y
	for grp in ["enemies", "hazards", "obstacles"]:
		for n in get_tree().get_nodes_in_group(grp):
			var half := 30.0
			if "width" in n:
				half = n.width / 2.0
			elif "_width" in n:
				half = n._width / 2.0
			var nx: float = n.global_position.x
			if nx + half < x0 or nx - half > x1:
				continue
			var dy: float = y - n.global_position.y
			if dy > -LENGTH and dy < ahead:
				return true
	# Игрок прямо перед носом — обходим
	var pdy: float = y - _player.global_position.y
	var px: float = _player.global_position.x
	return pdy > -40.0 and pdy < 200.0 and px > x0 - 10.0 and px < x1 + 10.0


func _free_lane_near(y: float, avoid: int) -> int:
	for d in [1, -1, 2, -2, 3, -3]:
		var l: int = avoid + d
		if l >= 0 and l < Art.LANES:
			return l
	return 0


static func _lane_of(x: float) -> int:
	return clampi(int((x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)


static func _lane_center(l: int) -> float:
	return Art.ROAD_LEFT + Art.LANE_W * (l + 0.5)


func _toast(text: String, color: Color, dur: float) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(text, color, dur)


## Для HUD: плашка гонки
func hud_text() -> Array:
	if state != S.RACE:
		return ["КОЛЯН НА ДЕВЯТКЕ", "догоняет…", Art.UI_TEXT]
	var left: float = maxf(0.0, (_player.global_position.y - _finish_y) * 0.1)
	var gap: float = (global_position.y - _player.global_position.y) * 0.1
	var sub := ("ты впереди на %d м" % int(gap)) if gap > 0.0 else ("отстаёшь на %d м" % int(-gap))
	return ["ГОНКА С КОЛЯНОМ • %d м" % int(left), sub, Art.GREEN if gap > 0.0 else Color("ff6b8a")]


func get_lights() -> Array:
	if not visible:
		return []
	return [[global_position + Vector2(0, -LENGTH * 0.7), 90.0, 0.7]]


func _draw() -> void:
	var tilt := clampf((_lane_center(_lane) - global_position.x) / 300.0, -0.25, 0.25)
	Art.draw_car(self, LENGTH, WIDTH, BODY, {"lights": true, "time": _t, "steer": tilt * 2.0,
		"base": Transform2D(tilt, Vector2.ZERO), "brake": _slow_t > 0.0, "spoiler": true})
	# Тонировка «в ноль»
	draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	Art.trapezoid(self, -LENGTH * 0.2, -LENGTH * 0.04, WIDTH * 0.6, WIDTH * 0.78, Color(0.02, 0.02, 0.04, 0.85))
	Art.trapezoid(self, LENGTH * 0.21, LENGTH * 0.31, WIDTH * 0.72, WIDTH * 0.58, Color(0.02, 0.02, 0.04, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Басы: кольца расходятся в такт
	if state != S.WAIT:
		var ph := fmod(_bass * 2.2, 1.0)
		draw_arc(Vector2(0, LENGTH * 0.2), 30.0 + ph * 40.0, 0.0, TAU, 28, Color(1.0, 0.42, 0.54, 0.45 * (1.0 - ph)), 3.0, true)
	Art.text_center(self, Vector2(0, -LENGTH * 0.5 - 16), "Колян", 14, Color("ff6b8a"), true)
