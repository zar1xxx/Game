extends Node2D
## Призрак рекорда.
##  • Во время заезда записывает путь машины: каждые 0,1 с — x, пройденное расстояние и поворот.
##  • Если заезд стал новым рекордом трассы, запись сохраняется (user://ghosts.cfg).
##  • В следующих заездах по той же трассе полупрозрачная машина повторяет лучший заезд.
##    Там, где рекорд закончился, поперёк дороги стоит финишная черта «Рекорд».
## Призрак ни с чем не сталкивается — с ним просто соревнуются.

const SAVE_PATH := "user://ghosts.cfg"
const DT := 0.1
const MAX_SAMPLES := 9000              # 15 минут — хватит на любой рекорд
const M_PER_PX := 0.1                  # те же «метры», что на табличках событий

var _player = null
var _start_y: float = 0.0
var _started: bool = false
var _t: float = 0.0                    # время заезда (только пока игра не на паузе)
var _rec := PackedFloat32Array()
var _next_sample: float = 0.0
var _saved: bool = false

# Воспроизведение
var _ghost: Dictionary = {}            # {car, score, data}
var _ghost_car: Dictionary = {}
var _gpos := Vector2.ZERO
var _grot: float = 0.0
var _g_done: bool = false              # призрак «доехал» до конца своего заезда
var _end_y: float = 0.0
var _passed_end: bool = false
var _overtook_toast: bool = false
var _hud_layer: CanvasLayer
var _hud: Control
var _enabled: bool = true
var _car_node: Node2D
var _label_node: Node2D        # свечение и подпись «РЕКОРД» над призраком (без поворота)
var _finish_drawn: bool = false
var _car_tb: int = -1
var _hud_drawn: String = "?"


func _ready() -> void:
	add_to_group("ghost")
	z_index = 0
	process_mode = Node.PROCESS_MODE_ALWAYS     # чтобы успеть сохранить запись, когда игра встала на паузу
	_car_node = Node2D.new()
	_car_node.modulate = Color(0.75, 1.0, 1.0, 0.45)
	_car_node.draw.connect(_draw_car)
	add_child(_car_node)
	_label_node = Node2D.new()
	_label_node.draw.connect(_draw_label)
	_label_node.visible = false
	add_child(_label_node)
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_start_y = _player.global_position.y
	_enabled = SaveManager.settings.get("ghost", true)
	if _enabled:
		_load_ghost()
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 4
	_hud_layer.add_to_group("hide_on_game_over")
	add_child(_hud_layer)
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.draw.connect(_draw_hud)
	_hud_layer.add_child(_hud)


static func location_key() -> String:
	return SaveManager.record_key()


func _load_ghost() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var key := location_key()
	if not cfg.has_section(key):
		return
	var data: PackedFloat32Array = cfg.get_value(key, "data", PackedFloat32Array())
	if data.size() < 9:
		return
	_ghost = {"car": cfg.get_value(key, "car", "orange"), "score": int(cfg.get_value(key, "score", 0)), "data": data}
	_ghost_car = SaveManager.custom_car(_ghost.car) if SaveManager.is_owned("car", _ghost.car) else GameData.get_car(_ghost.car).duplicate()
	var n := data.size() / 3
	_end_y = _start_y - data[(n - 1) * 3 + 1]


func has_ghost() -> bool:
	return not _ghost.is_empty()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_dead:
		if not _saved:
			_saved = true
			_maybe_save()
			# Плашки призрака не должны висеть поверх итогов заезда
			_hud_layer.visible = false
			_car_node.visible = false
			_label_node.visible = false
			queue_redraw()
		return
	if get_tree().paused:
		return
	# Отсчёт начинается, когда машина тронулась (после светофора)
	if not _started:
		if _start_y - _player.global_position.y > 1.0:
			_started = true
		else:
			return
	_t += delta
	if _t >= _next_sample and _rec.size() / 3 < MAX_SAMPLES:
		_next_sample += DT
		_rec.append(_player.global_position.x)
		_rec.append(_start_y - _player.global_position.y)
		_rec.append(_player.rotation)
	if has_ghost():
		_update_ghost()
	# Всё рисуется заранее и только двигается — перерисовка лишь при изменениях
	if not _finish_drawn and has_ghost():
		_finish_drawn = true
		queue_redraw()                 # финишная черта рекорда (стоит на месте)
	_car_node.visible = has_ghost() and not _g_done
	_car_node.position = _gpos
	_car_node.rotation = _grot
	_label_node.visible = _car_node.visible
	_label_node.position = _gpos
	var tb := int(_t * 12.0)           # мигалки и наклейки машины-призрака
	if tb != _car_tb and _car_node.visible:
		_car_tb = tb
		_car_node.queue_redraw()
	var ht: String = _hud_info()[0]
	if ht != _hud_drawn:
		_hud_drawn = ht
		_hud.queue_redraw()


func _update_ghost() -> void:
	var data: PackedFloat32Array = _ghost.data
	var n := data.size() / 3
	var f := _t / DT
	var i := int(f)
	if i >= n - 1:
		_g_done = true
		i = n - 1
		_gpos = Vector2(data[i * 3], _start_y - data[i * 3 + 1])
		_grot = 0.0
	else:
		var k := f - i
		var a := Vector2(data[i * 3], data[i * 3 + 1])
		var b := Vector2(data[(i + 1) * 3], data[(i + 1) * 3 + 1])
		var p := a.lerp(b, k)
		_gpos = Vector2(p.x, _start_y - p.y)
		_grot = lerpf(data[i * 3 + 2], data[(i + 1) * 3 + 2], k)
	# Обогнали призрака впервые
	if not _overtook_toast and _player.global_position.y < _gpos.y - _player.CAR_LENGTH:
		_overtook_toast = true
		_toast("Вы обогнали призрака рекорда!", Art.TEAL)
	# Проехали дальше, чем рекорд вообще доехал
	if not _passed_end and _player.global_position.y < _end_y:
		_passed_end = true
		Achievements.event("ghost")
		Sound.play("record", -4.0, 1.2, 0.0)
		_toast("Дальше, чем в рекордном заезде! Призрак позади", Art.GREEN)


## Сохраняем запись, если этот заезд лучше сохранённого призрака
func _maybe_save() -> void:
	var sc = _player.get_node_or_null("scoreComponent")
	if sc == null or _rec.size() < 9:
		return
	var score: int = sc.max_score
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var key := location_key()
	if score <= int(cfg.get_value(key, "score", 0)):
		return
	cfg.set_value(key, "car", SaveManager.selected_car)
	cfg.set_value(key, "score", score)
	cfg.set_value(key, "data", _rec)
	cfg.save(SAVE_PATH)


func _toast(text: String, color: Color) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(text, color, 2.2)


# ---------------------------------------------------------------------------
# Рисование
# ---------------------------------------------------------------------------
func _draw() -> void:
	if not has_ghost() or not _finish_drawn:
		return
	# Финишная черта рекорда поперёк дороги (рисуется один раз, дальше просто стоит на месте)
	var L := Art.ROAD_LEFT
	var W := Art.ROAD_W
	var sq := 20.0
	var cols := int(W / sq)
	for row in 2:
		for c in cols:
			var col := Color(1, 1, 1, 0.55) if (row + c) % 2 == 0 else Color(0, 0, 0, 0.45)
			draw_rect(Rect2(L + c * sq, _end_y - sq * 2 + row * sq, sq, sq), col)
	Art.text_center(self, Vector2(L + W / 2.0, _end_y - 64), "РЕКОРД  %d" % _ghost.score, 24, Color(Art.TEAL, 0.9), true)


## Свечение и подпись над машиной-призраком (узел двигается вместе с призраком)
func _draw_label() -> void:
	if _ghost_car.is_empty():
		return
	Art.glow(_label_node, Vector2.ZERO, 80, Color(Art.TEAL, 0.16))
	Art.text_center(_label_node, Vector2(0, _ghost_car.length / 2.0 + 16), "РЕКОРД", 13, Color(Art.TEAL, 0.9), true)


## Машина-призрак (узел полупрозрачный — modulate задан при создании)
func _draw_car() -> void:
	if _ghost_car.is_empty():
		return
	Art.draw_player_car(_car_node, _ghost_car, {"lights": false, "time": _t, "shadow": false, "plate": false})


## Плашка «Призрак: +45 м / −45 м» справа под полосками прочности
func _draw_hud() -> void:
	if not has_ghost() or not _started or _player == null or _player.is_dead:
		return
	var vs := _hud.get_viewport_rect().size
	var r := Rect2(vs.x - 214 - MobileInput.safe_insets(get_viewport()).z, 176, 200, 38)
	Art.rrect(_hud, r, Color(Art.UI_PANEL, 0.85), 10, 2, Color(Art.TEAL, 0.7))
	var info := _hud_info()
	_hud.draw_circle(r.position + Vector2(20, 19), 8, Color(Art.TEAL, 0.8))
	Art.text_center(_hud, r.position + Vector2(r.size.x / 2.0 + 10, 19), info[0], 15, info[1], true)


## Текст и цвет плашки призрака
func _hud_info() -> Array:
	if not has_ghost() or not _started or _player == null or _player.is_dead:
		return ["", Art.UI_TEXT]
	var txt := ""
	var col := Art.UI_TEXT
	if _g_done and _passed_end:
		txt = "Рекорд позади!"
		col = Art.GREEN
	elif _g_done:
		var left: float = (_player.global_position.y - _end_y) * M_PER_PX
		txt = "До рекорда %d м" % int(maxf(left, 0.0))
		col = Art.YELLOW
	else:
		var d: float = (_gpos.y - _player.global_position.y) * M_PER_PX
		if d >= 0.0:
			txt = "Призрак: +%d м" % int(d)
			col = Art.GREEN
		else:
			txt = "Призрак: −%d м" % int(-d)
			col = Art.RED
	return [txt, col]
