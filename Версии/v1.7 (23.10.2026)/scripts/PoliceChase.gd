extends Node2D
## Полиция в погоне.
## Если ехать слишком медленно или долго тормозить, растёт «подозрение».
## Когда оно заполнится, сзади появляется машина ДПС с мигалкой и начинает догонять.
##  • Едете быстрее полиции — расстояние растёт, и через пару секунд вы оторвались (бонус очков).
##  • Тормозите или врезаетесь — полиция догоняет: штраф −30% прочности, после чего она отстаёт.
## За рулём своего перехватчика ДПС погони нет: «свои не трогают».

enum State { IDLE, CHASE, RETREAT }

const SUSPICION_MAX := 2.5        # сколько секунд медленной езды до начала погони
const SLOW_FACTOR := 0.72         # «медленно» — ниже 72% крейсерской скорости
const START_GAP := 430.0          # на каком расстоянии позади появляется полиция
const ESCAPE_GAP := 650.0         # если отрыв больше — полиция начинает отставать
const POLICE_SPEED := 0.85        # скорость полиции относительно крейсерской скорости игрока
const ESCAPE_BONUS := 50
const L := 106.0
const W := 52.0

var state: State = State.IDLE
var suspicion: float = 0.0
var gap: float = START_GAP
var _grace: float = 7.0           # первые секунды заезда — разгон, полиция не реагирует
var _cooldown: float = 0.0
var _escape_t: float = 0.0
var _warned: bool = false
var _t: float = 0.0
var _siren: AudioStreamPlayer
var _enabled: bool = true
var _chase_time: float = 0.0


func _ready() -> void:
	add_to_group("police")
	z_index = 3
	visible = false
	_enabled = GameData.get_car(SaveManager.selected_car).kind != "police"


func _physics_process(delta: float) -> void:
	_t += delta
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not _enabled:
		return
	var cam = get_viewport().get_camera_2d()
	if player.is_dead:
		if _siren:
			_siren.stop()
		if cam and cam.has_method("set_chase"):
			cam.set_chase("police", 0.0)
		return
	var cruise: float = player.get_cruise_speed()
	match state:
		State.IDLE:
			_update_suspicion(player, cruise, delta)
		State.CHASE:
			_chase_time += delta
			# Чем дольше погоня, тем настойчивее полиция (но всё равно медленнее крейсерской)
			var police_speed := cruise * minf(POLICE_SPEED + _chase_time * 0.002, 0.93)
			gap += (player.current_speed - police_speed) * delta
			if gap <= 0.0:
				_caught(player)
			elif gap > ESCAPE_GAP:
				_escape_t += delta
				if _escape_t > 1.0:
					_escaped(player)
			else:
				_escape_t = 0.0
		State.RETREAT:
			gap += 650.0 * delta
			if gap > 1000.0:
				state = State.IDLE
				visible = false
				if _siren:
					_siren.stop()
	if cam and cam.has_method("set_chase"):
		cam.set_chase("police", 1.0 if state == State.CHASE or (state == State.RETREAT and gap < 500.0) else 0.0)
	# Позиция: позади игрока, по его полосе с небольшим запаздыванием
	var target_x: float = player.global_position.x
	global_position.x = lerpf(global_position.x, target_x, clampf(delta * 2.2, 0.0, 1.0))
	global_position.y = player.global_position.y + player.CAR_LENGTH / 2.0 + gap + L / 2.0
	if _siren:
		_siren.volume_db = lerpf(-4.0, -26.0, clampf(gap / 900.0, 0.0, 1.0))
	queue_redraw()


func _update_suspicion(player, cruise: float, delta: float) -> void:
	if _grace > 0.0:
		_grace -= delta
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		suspicion = 0.0
		return
	# После аварии, на масле и на нитро медленная езда не считается
	var excused: bool = player.recovery_time_left > 0.0 or player.slip_time_left > 0.0 \
		or player.nitro_time_left > 0.0 or player.slow_excuse > 0.0
	var slow: bool = player.current_speed < cruise * SLOW_FACTOR or player.is_braking
	if slow and not excused:
		suspicion += delta
		if not _warned and suspicion > SUSPICION_MAX * 0.45:
			_warned = true
			_toast("Слишком медленно! Полиция присматривается…", Art.BLUE)
	else:
		suspicion = maxf(0.0, suspicion - delta * 0.6)
		if suspicion <= 0.0:
			_warned = false
	var tck = get_tree().get_first_node_in_group("tck")
	if suspicion >= SUSPICION_MAX and not (tck and tck.is_active()):
		_start_chase(player)


func _start_chase(player) -> void:
	state = State.CHASE
	gap = START_GAP
	_escape_t = 0.0
	_chase_time = 0.0
	suspicion = 0.0
	_warned = false
	visible = true
	global_position.x = player.global_position.x
	if _siren == null:
		_siren = Sound.make_loop(self, "siren", -20.0)
	else:
		_siren.play()
	Sound.play("horn", -6.0, 0.8)
	_toast("ДПС на хвосте! Газу!", Art.RED)


func _caught(player) -> void:
	state = State.RETREAT
	gap = 0.0
	_cooldown = 10.0
	_toast("ДПС: штраф! −30% прочности", Art.RED)
	player.police_catch()


func _escaped(player) -> void:
	state = State.RETREAT
	_cooldown = 8.0
	var sc = player.get_node_or_null("scoreComponent")
	if sc and sc.has_method("add_bonus"):
		sc.add_bonus(ESCAPE_BONUS)
	Missions.event("escape")
	Sound.play("record", -6.0, 1.2, 0.0)
	_toast("Оторвались от погони! +%d" % ESCAPE_BONUS, Art.GREEN)


func _toast(text: String, color: Color) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(text, color, 2.2)


## Насколько близко полиция: 0 — далеко, 1 — вплотную (для индикатора в HUD)
func get_threat() -> float:
	if state != State.CHASE:
		return 0.0
	return clampf(1.0 - gap / ESCAPE_GAP, 0.0, 1.0)


func _draw() -> void:
	# Мигалка подсвечивает асфальт вокруг
	var blink := int(_t * 6.0) % 2 == 0
	Art.glow(self, Vector2(-14, -4), 90, Color(1.0, 0.2, 0.25, 0.35 if blink else 0.1))
	Art.glow(self, Vector2(14, -4), 90, Color(0.25, 0.45, 1.0, 0.1 if blink else 0.35))
	Art.draw_car(self, L, W, Color("eef0f6"), {"deco": "police", "lights": true, "time": _t})
