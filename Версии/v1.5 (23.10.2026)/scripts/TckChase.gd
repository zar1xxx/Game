extends Node2D
## Облава: побег от бусика ТЦК и дронов.
## Время от времени (после 120 очков) сзади появляется белый бусик, а над дорогой — дроны.
##  • Дрон высвечивает на асфальте красный круг и ведёт его за вашей машиной.
##    Продержались в круге ~0,8 с — «засекли»: бусик сразу сокращает отрыв.
##  • Отрыв больше 700 или продержались до конца облавы — ушли (бонус очков).
##  • Бусик догнал — заезд окончен.

enum State { IDLE, CHASE, RETREAT }

const L := 132.0
const W := 60.0
const START_GAP := 420.0
const ESCAPE_GAP := 700.0
const DURATION := 22.0             # сколько длится облава, если не оторваться раньше
const VAN_SPEED := 0.95            # скорость бусика относительно крейсерской скорости игрока
const SPOT_TIME := 0.8             # сколько секунд в круге дрона до «засекли»
const SPOT_PENALTY := 200.0        # на сколько бусик приближается, когда засекли
const MARK_R := 52.0
const ESCAPE_BONUS := 100

var state: State = State.IDLE
var gap: float = START_GAP
var drones: Array = []             # {"pos": мировые координаты дрона, "mark": центр круга, "spot": сек, "cool": сек}
var _next: float = 45.0
var _left: float = 0.0
var _escape_t: float = 0.0
var _t: float = 0.0
var _buzz: AudioStreamPlayer
var _engine: AudioStreamPlayer


func _ready() -> void:
	add_to_group("tck")
	z_index = 6                    # дроны летают над машинами
	_next = randf_range(35.0, 60.0)


func is_active() -> bool:
	return state != State.IDLE


func _physics_process(delta: float) -> void:
	_t += delta
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam = get_viewport().get_camera_2d()
	if player.is_dead:
		_stop_sounds()
		if cam and cam.has_method("set_chase"):
			cam.set_chase("tck", 0.0)
		return
	match state:
		State.IDLE:
			_wait_for_raid(player, delta)
		State.CHASE:
			_update_chase(player, delta)
		State.RETREAT:
			gap += 700.0 * delta
			for d in drones:
				d.pos += Vector2(0, -900.0) * delta      # дроны улетают вперёд
			if gap > 1100.0:
				state = State.IDLE
				drones.clear()
				_stop_sounds()
	if cam and cam.has_method("set_chase"):
		cam.set_chase("tck", 1.0 if state == State.CHASE or (state == State.RETREAT and gap < 500.0) else 0.0)
	global_position = Vector2.ZERO
	queue_redraw()


func _wait_for_raid(player, delta: float) -> void:
	var sc = player.get_node_or_null("scoreComponent")
	if sc == null or sc.max_score < 120:
		return
	_next -= delta
	if _next > 0.0:
		return
	var police = get_tree().get_first_node_in_group("police")
	if police and police.state != police.State.IDLE:
		_next = 5.0                  # дождёмся, пока полиция отстанет
		return
	_start(player, sc.max_score)


func _start(player, score: int) -> void:
	state = State.CHASE
	gap = START_GAP
	_left = DURATION
	_escape_t = 0.0
	drones.clear()
	var count := 2 if score < 800 else 3
	for i in count:
		var lane_x := Art.ROAD_LEFT + Art.LANE_W * (randi() % Art.LANES + 0.5)
		drones.append({"pos": player.global_position + Vector2(randf_range(-300, 300), -700 - i * 150),
			"mark": Vector2(lane_x, player.global_position.y - 260), "spot": 0.0, "cool": 1.5 + i * 1.2,
			"ahead": randf_range(180.0, 330.0)})
	if _buzz == null:
		_buzz = Sound.make_loop(self, "drone", -14.0)
		_engine = Sound.make_loop(self, "engine", -12.0)
		_engine.pitch_scale = 0.7
	else:
		_buzz.play()
		_engine.play()
	Sound.play("alarm", -2.0, 1.0, 0.0)
	_toast("Облава! Сзади бусик ТЦК, в небе дроны!", Art.RED)


func _update_chase(player, delta: float) -> void:
	_left -= delta
	var cruise: float = player.get_cruise_speed()
	gap += (player.current_speed - cruise * VAN_SPEED) * delta
	# Дроны: висят впереди машины и ведут красный круг к её полосе
	var px: float = player.global_position.x
	var py: float = player.global_position.y
	for d in drones:
		d.cool = maxf(0.0, d.cool - delta)
		var target_mark := Vector2(px, py - d.ahead)
		if d.cool > 0.0:
			# После «засекли» дрон уводит круг в сторону и выбирает новую полосу
			target_mark.x = d.mark.x
		d.mark.x = move_toward(d.mark.x, target_mark.x, 150.0 * delta)
		d.mark.y = target_mark.y
		d.pos = d.pos.lerp(d.mark + Vector2(28, -70), clampf(delta * 3.0, 0.0, 1.0))
		var in_mark: bool = d.cool <= 0.0 and absf(px - d.mark.x) < MARK_R and absf(py - d.mark.y) < player.CAR_LENGTH * 0.5 + MARK_R
		# Круг стоит впереди: «попасть» в него — значит въехать в него, когда он окажется под машиной
		if d.cool <= 0.0 and absf(px - d.mark.x) < MARK_R * 0.8:
			d.ahead = move_toward(d.ahead, 0.0, 220.0 * delta)     # круг подтягивается к машине
		else:
			d.ahead = move_toward(d.ahead, 260.0, 120.0 * delta)
		if in_mark:
			d.spot += delta
			if d.spot >= SPOT_TIME:
				_spotted(d)
		else:
			d.spot = maxf(0.0, d.spot - delta * 0.5)
	if _buzz:
		_buzz.volume_db = -12.0 if not drones.is_empty() else -80.0
	if _engine:
		_engine.volume_db = lerpf(-6.0, -30.0, clampf(gap / 900.0, 0.0, 1.0))
	if gap <= 0.0:
		_caught(player)
	elif gap > ESCAPE_GAP:
		_escape_t += delta
		if _escape_t > 1.0:
			_escaped(player)
	elif _left <= 0.0:
		_escaped(player)
	else:
		_escape_t = 0.0


func _spotted(d: Dictionary) -> void:
	d.spot = 0.0
	d.cool = 3.0
	d.ahead = 300.0
	d.mark.x = Art.ROAD_LEFT + Art.LANE_W * (randi() % Art.LANES + 0.5)
	gap -= SPOT_PENALTY
	Sound.play("alarm", -3.0, 1.1, 0.0)
	MobileInput.vibrate(60)
	_toast("Дрон засёк вас! Бусик ближе!", Art.RED)


func _caught(player) -> void:
	state = State.RETREAT
	gap = 0.0
	Sound.play("horn", -2.0, 0.75, 0.0)
	player.trigger_game_over(["Вас догнал бусик ТЦК. Повестка вручена!",
		"Бусик ТЦК оказался быстрее. Добро пожаловать в учебку!"].pick_random())


func _escaped(player) -> void:
	state = State.RETREAT
	_next = randf_range(55.0, 90.0)
	var sc = player.get_node_or_null("scoreComponent")
	if sc and sc.has_method("add_bonus"):
		sc.add_bonus(ESCAPE_BONUS)
	Missions.event("escape_tck")
	Sound.play("record", -4.0, 1.1, 0.0)
	_toast("Ушли от бусика ТЦК! +%d" % ESCAPE_BONUS, Art.GREEN)


func _stop_sounds() -> void:
	for p in [_buzz, _engine]:
		if p and is_instance_valid(p):
			p.stop()


func _toast(text: String, color: Color) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(text, color, 2.4)


## 0 — бусик далеко, 1 — вплотную (для индикатора в HUD)
func get_threat() -> float:
	if state != State.CHASE:
		return 0.0
	return clampf(1.0 - gap / ESCAPE_GAP, 0.0, 1.0)


## Источники света для ночи (фары бусика и огоньки дронов)
func get_lights() -> Array:
	var out: Array = []
	if state == State.IDLE:
		return out
	var player = get_tree().get_first_node_in_group("player")
	if player:
		out.append([Vector2(_van_x, player.global_position.y + player.CAR_LENGTH / 2.0 + gap), 160.0, 0.9])
	for d in drones:
		out.append([d.mark, 70.0, 0.7])
	return out


func get_time_left() -> float:
	return maxf(_left, 0.0)


func _draw() -> void:
	if state == State.IDLE:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# Круги наведения дронов на асфальте
	for d in drones:
		if state == State.CHASE and d.cool <= 0.0:
			var k: float = d.spot / SPOT_TIME
			var pulse := 0.5 + 0.5 * sin(_t * 10.0)
			draw_circle(d.mark, MARK_R, Color(1.0, 0.15, 0.2, 0.12 + 0.25 * k))
			draw_arc(d.mark, MARK_R, 0, TAU, 36, Color(1.0, 0.2, 0.25, 0.6 + 0.4 * pulse), 3.0, true)
			draw_line(d.mark - Vector2(14, 0), d.mark + Vector2(14, 0), Color(1, 0.3, 0.3, 0.8), 2.0)
			draw_line(d.mark - Vector2(0, 14), d.mark + Vector2(0, 14), Color(1, 0.3, 0.3, 0.8), 2.0)
			if k > 0.0:
				draw_arc(d.mark, MARK_R + 8, -PI / 2, -PI / 2 + TAU * k, 32, Art.RED, 5.0, true)
	# Бусик позади игрока
	var van_pos := Vector2(player.global_position.x, player.global_position.y + player.CAR_LENGTH / 2.0 + gap + L / 2.0)
	_van_x = lerpf(_van_x if _van_x != 0.0 else van_pos.x, van_pos.x, 0.04)
	Art.draw_van(self, L, W, Color("eef0f4"), "ТЦК",
		{"lights": true, "time": _t, "base": Transform2D(0.0, Vector2(_van_x, van_pos.y))})
	for d in drones:
		Art.draw_drone(self, d.pos, _t, 1.15)


var _van_x: float = 0.0
