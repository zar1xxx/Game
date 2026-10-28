extends Node
## Обучение — первый заезд с подсказками.
## Шаги идут по очереди: руль → встречные → тормоз → бензин → нитро → комбо → камера.
## Пока идут подсказки, обычный спавн, дорожные события и погони выключены,
## а машина не может разбиться или остаться без бензина.
## После последнего шага заезд продолжается как обычный.

const EnemyScene := preload("res://scenes/EnemyCar.tscn")
const FuelScene := preload("res://scenes/FuelCan.tscn")
const NitroScene := preload("res://scenes/obstacles/NitroPickup.tscn")

const STEPS := ["steer", "dodge", "brake", "fuel", "nitro", "combo", "camera", "done"]

var _p = null
var _events = null
var _step: int = -1
var _step_t: float = 0.0
var _wait: float = 0.0                # пауза перед следующим шагом (после «Отлично!»)
var _success: bool = false
var _progress: float = 0.0            # 0..1 для полоски шага
var _left_t: float = 0.0
var _right_t: float = 0.0
var _brake_t: float = 0.0
var _spawned: Array = []
var _spawn_left: int = 0
var _spawn_t: float = 0.0
var _fuel_prev: float = 0.0
var _near: bool = false
var _started: bool = false
var _touch: bool = false
var _finished: bool = false

var _layer: CanvasLayer
var _card: PanelContainer
var _title: Label
var _text: Label
var _counter: Label
var _bar: ProgressBar
var _skip: Button
var _marks: Control
var _t: float = 0.0


func _ready() -> void:
	if not SaveManager.tutorial_running:
		queue_free()
		return
	_touch = MobileInput.is_touch_device()
	_p = get_tree().get_first_node_in_group("player")
	if _p:
		_p.near_miss.connect(func(_pts, _c, _cl): _near = true)
	_build_ui()


# ---------------------------------------------------------------------------
# Интерфейс: карточка подсказки сверху и кнопка «Пропустить»
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 6
	_layer.add_to_group("hide_on_game_over")
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_marks = Control.new()
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_layer.add_child(_marks)
	_card = PanelContainer.new()
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -270
	_card.offset_right = 270
	_card.offset_top = 106
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_card.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	_title = Label.new()
	_title.add_theme_font_override("font", Art.font_title)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Art.ORANGE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_skip = Button.new()
	_skip.text = "Пропустить"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.custom_minimum_size = Vector2(0, 30)
	_skip.add_theme_font_size_override("font_size", 13)
	_skip.pressed.connect(_on_skip)
	_skip.hide()
	head.add_child(_skip)
	var gap := Control.new()
	gap.custom_minimum_size.x = 10
	head.add_child(gap)
	_counter = Label.new()
	_counter.add_theme_font_size_override("font_size", 13)
	_counter.add_theme_color_override("font_color", Art.UI_MUTED)
	head.add_child(_counter)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 500
	_text.add_theme_font_size_override("font_size", 16)
	vb.add_child(_text)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Art.GREEN
	fill.set_corner_radius_all(5)
	_bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(_bar)
	_card.modulate.a = 0.0



func _show_card(title: String, text: String, show_bar: bool = true) -> void:
	_title.text = title
	_text.text = text
	_bar.visible = show_bar
	_bar.value = 0.0
	var n := STEPS.size() - 1
	_counter.text = "Шаг %d из %d" % [mini(_step + 1, n), n] if _step < n else ""
	_card.pivot_offset = Vector2(270, 40)
	_card.scale = Vector2(0.9, 0.9)
	var tw := _card.create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _good(msg: String = "Отлично!") -> void:
	_success = true
	_wait = 1.3
	_bar.value = 1.0
	_title.text = msg
	_title.add_theme_color_override("font_color", Art.GREEN)
	Sound.play("pickup", -4.0, 1.2, 0.0)
	MobileInput.vibrate(25)


# ---------------------------------------------------------------------------
# Логика шагов
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	_marks.queue_redraw()
	if _p != null and is_instance_valid(_p) and _p.is_dead:
		_layer.visible = false
	if _finished or _p == null or not is_instance_valid(_p) or _p.is_dead or get_tree().paused:
		return
	_protect()
	if not _started:
		# Ждём, пока машина тронется после светофора
		if _p.current_speed > 250.0:
			_started = true
			_skip.show()
			_next_step()
		return
	_step_t += delta
	if _success:
		_wait -= delta
		if _wait <= 0.0:
			_next_step()
		return
	match STEPS[_step]:
		"steer":
			if _p.steer_input < -0.3:
				_left_t += delta
			elif _p.steer_input > 0.3:
				_right_t += delta
			_progress = (minf(_left_t, 0.5) + minf(_right_t, 0.5)) / 1.0
			if _left_t >= 0.5 and _right_t >= 0.5:
				_good()
		"dodge":
			_spawn_wave(delta, "enemy_my_lane")
			var passed := 0
			for e in _spawned:
				if not is_instance_valid(e) or e.global_position.y > _p.global_position.y + 140.0:
					passed += 1
			_progress = passed / 3.0
			if _spawn_left == 0 and passed >= 3:
				_good("Ловко!")
		"brake":
			if _p.is_braking:
				_brake_t += delta
			_progress = clampf(_brake_t / 0.8, 0.0, 1.0)
			if _brake_t >= 0.8:
				_good()
		"fuel":
			if _p.current_fuel > _fuel_prev + 4.0:
				_good("Бак полный!")
			_fuel_prev = _p.current_fuel
			_respawn_if_missed(FuelScene)
		"nitro":
			if _p.nitro_time_left > 0.0:
				_good("Полный газ!")
			_respawn_if_missed(NitroScene)
		"combo":
			_spawn_wave(delta, "enemy_side")
			_progress = clampf(_step_t / 20.0, 0.0, 1.0)
			if _near:
				_good("На волоске!")
			elif _step_t > 20.0:
				_good("Получится в заезде!")
		"camera":
			if _events == null:
				_events = get_tree().get_first_node_in_group("road_events")
			if _events and not _events.busy() and _step_t > 1.0:
				_good("Без штрафа?")
			elif _events and _events.busy():
				_progress = clampf(_step_t / 9.0, 0.0, 0.95)
		"done":
			if _step_t > 4.5:
				_finish()
	_bar.value = _progress


## Машина в обучении неразрушима и не остаётся без бензина, полиция не гонится
func _protect() -> void:
	_p.slow_excuse = 1.0
	if _p.current_health < _p.max_health * 0.4:
		_p.current_health = _p.max_health * 0.4
		if _p.health_bar:
			_p.health_bar.value = _p.current_health
	var floor_k := 0.12 if _step >= 0 and STEPS[_step] == "fuel" else 0.35
	if _p.current_fuel < _p.max_fuel * floor_k:
		_p.add_fuel(_p.max_fuel * floor_k - _p.current_fuel)


func _next_step() -> void:
	_step += 1
	_step_t = 0.0
	_success = false
	_progress = 0.0
	_spawned.clear()
	_title.add_theme_color_override("font_color", Art.ORANGE)
	match STEPS[_step]:
		"steer":
			_show_card("Руль", "Жмите ◀ и ▶ слева внизу — машина поворачивает. Попробуйте в обе стороны." if _touch
				else "← → или A / D — руль. Покрутите в обе стороны.")
		"dodge":
			_spawn_left = 3
			_spawn_t = 0.3
			_show_card("Встречные", "Навстречу едут машины. Объезжайте их — каждый удар отнимает прочность.")
		"brake":
			_show_card("Тормоз", "Педаль ТОРМОЗ справа сбрасывает скорость. Притормозите." if _touch
				else "↓ или S — тормоз. Притормозите.")
		"fuel":
			_p.current_fuel = minf(_p.current_fuel, _p.max_fuel * 0.3)
			_p.add_fuel(0.0)
			_fuel_prev = _p.current_fuel
			_show_card("Бензин", "Бензин всё время тратится — полоска справа вверху. Подберите канистру!", false)
			_spawn_pickup(FuelScene, 0)
			_spawn_pickup(FuelScene, 420.0)
		"nitro":
			_show_card("Нитро", "Синий бонус — нитро: машина резко ускоряется. Подберите его!", false)
			_spawn_pickup(NitroScene, 0)
		"combo":
			_near = false
			_spawn_left = 6
			_spawn_t = 0.5
			_show_card("Комбо", "Пролетите впритирку к встречной — «На волоске!» даёт очки. Несколько подряд — множитель до ×8.")
		"camera":
			_events = get_tree().get_first_node_in_group("road_events")
			if _events:
				_events._start("camera", _p)
			_show_card("Камеры", "Знак «60» — впереди камера или пост ДПС. Сбросьте скорость до 60 км/ч, иначе штраф монетами. Сейчас штраф понарошку.")
		"done":
			_skip.hide()
			SaveManager.complete_tutorial()
			Achievements.event("tutorial")
			Sound.play("record", -2.0, 1.1, 0.0)
			_show_card("Готово! +%d монет" % SaveManager.TUTORIAL_REWARD,
				"Дальше — настоящий заезд: ямы, погони, АЗС и коллекторы. Гудок — %s. Удачи!" % ("кнопка БИП" if _touch else "H или пробел"), false)
			_title.add_theme_color_override("font_color", Art.GREEN)


func _finish() -> void:
	_finished = true
	var tw := _card.create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
	var ev = get_tree().get_first_node_in_group("road_events")
	if ev:
		ev._next = 12.0


func _on_skip() -> void:
	if _finished:
		return
	SaveManager.complete_tutorial()
	_skip.hide()
	_step = STEPS.size() - 2
	_success = false
	_next_step()
	_step_t = 3.5


# ---------------------------------------------------------------------------
# Спавн для шагов
# ---------------------------------------------------------------------------
func _cam_top() -> float:
	var cam := get_viewport().get_camera_2d()
	return cam.global_position.y - Art.VIEW_H / 2.0 if cam else _p.global_position.y - 600.0


func _player_lane() -> int:
	return clampi(int((_p.global_position.x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)


func _lane_x(lane: int) -> float:
	return Art.ROAD_LEFT + Art.LANE_W * (lane + 0.5)


func _spawn_wave(delta: float, kind: String) -> void:
	if _spawn_left <= 0:
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	var lane := _player_lane()
	if kind == "enemy_side":
		var dir := -1 if _spawn_left % 2 == 0 else 1
		if lane + dir < 0 or lane + dir >= Art.LANES:
			dir = -dir
		lane += dir
		_spawn_t = 1.6
	else:
		_spawn_t = 1.5
	_spawn_left -= 1
	var e = EnemyScene.instantiate()
	e.behavior = 0
	e.global_position = Vector2(_lane_x(lane), _cam_top() - 700.0)
	get_tree().current_scene.add_child(e)
	_spawned.append(e)


func _spawn_pickup(scene: PackedScene, extra_y: float) -> void:
	var lane := _player_lane()
	if extra_y > 0.0:
		lane = clampi(lane + (1 if lane < Art.LANES - 1 else -1), 0, Art.LANES - 1)
	var n = scene.instantiate()
	n.global_position = Vector2(_lane_x(lane), _cam_top() - 160.0 - extra_y)
	get_tree().current_scene.add_child(n)
	_spawned.append(n)


## Бонус проехали мимо — через пару секунд ставим новый
func _respawn_if_missed(scene: PackedScene) -> void:
	for n in _spawned:
		if is_instance_valid(n) and n.global_position.y < _p.global_position.y + 200.0:
			return
	if _step_t > 1.0:
		_spawned.clear()
		_step_t = 0.0
		_spawn_pickup(scene, 0)


# ---------------------------------------------------------------------------
# Подсветка нужных кнопок и полосок
# ---------------------------------------------------------------------------
func _draw_marks() -> void:
	if _finished or _step < 0 or _success:
		return
	var vs := _marks.get_viewport_rect().size
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var col := Color(Art.YELLOW, 0.5 + 0.5 * pulse)
	match STEPS[_step]:
		"steer":
			if _touch:
				_ring(Vector2(26 + 62, vs.y - 26 - 62), 72 + pulse * 6, col)
				_ring(Vector2(26 + 62 * 3 + 24, vs.y - 26 - 62), 72 + pulse * 6, col)
		"brake":
			if _touch:
				_marks.draw_rect(Rect2(vs.x - 26 - 128 - 8, vs.y - 26 - 150 - 8, 144, 166), col, false, 4.0)
		"fuel":
			var hud = get_tree().get_first_node_in_group("hud")
			if hud:
				var r: Rect2 = hud.fuel_bar.get_global_rect().grow(6)
				_marks.draw_rect(r, col, false, 4.0)
				_arrow(r.position + Vector2(r.size.x / 2.0, r.size.y + 30 + pulse * 8), col)


func _ring(c: Vector2, r: float, col: Color) -> void:
	_marks.draw_arc(c, r, 0, TAU, 48, col, 4.0, true)


func _arrow(tip_below: Vector2, col: Color) -> void:
	# Стрелка вверх (к полоске)
	var t := tip_below - Vector2(0, 22)
	_marks.draw_colored_polygon(PackedVector2Array([t, t + Vector2(-14, 20), t + Vector2(14, 20)]), col)
	_marks.draw_rect(Rect2(t.x - 5, t.y + 20, 10, 22), col)
