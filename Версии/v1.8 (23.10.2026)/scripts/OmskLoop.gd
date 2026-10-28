extends Node2D
## Режим «Омск не отпускает» (трасса omsk_loop).
## Каждые несколько километров над дорогой появляется арка «ОМСК» — вы снова в Омске.
## С каждым кругом абсурда больше: ямы размножаются, дорога плывёт, по ней гуляют
## гигантские утки, небо меняет цвет, маршрутки сходят с ума, а круги становятся короче.

const GiantDuck := preload("res://scripts/obstacles/GiantDuck.gd")
const BASE_LEN := 16000.0          # длина круга в пикселях (≈ 3,2 «км» на табло)
const PX_PER_KM := 5000.0
const SUBTITLES := ["", "СНОВА", "ОПЯТЬ", "ВСЁ ЕЩЁ", "НУ ВЫ ПОНЯЛИ", "ЭТО НЕ БАГ", "НАВСЕГДА", "∞", "ОМСК ОМСК"]
const ABSURD := [
	"",
	"Ямы размножаются",
	"Дорога плывёт",
	"По дороге гуляют гигантские утки",
	"Небо меняет цвет",
	"Маршрутки сошли с ума",
	"Круги становятся короче",
	"Дорога плывёт ещё сильнее",
	"Омск ускоряется",
]

var loop: int = 0
var sign_y: float = 0.0
var _start_y: float = 0.0
var _loop_len: float = BASE_LEN
var _t: float = 0.0
var _duck_t: float = 8.0
var _wobble: float = 0.0
var _tint: float = 0.0
var _pill: Control
var _tint_node: Node2D
var _spawner: Node = null


func _ready() -> void:
	add_to_group("omsk_loop")
	z_index = 8                     # арка висит над машинами
	var p = get_tree().get_first_node_in_group("player")
	_start_y = p.global_position.y if p else 0.0
	sign_y = _start_y - _loop_len
	_spawner = get_tree().current_scene.get_node_or_null("EnemySpawner")
	# Цветное «небо» — поверх мира, но под интерфейсом
	_tint_node = Node2D.new()
	_tint_node.z_index = 40
	_tint_node.draw.connect(_draw_tint)
	add_child(_tint_node)
	# Плашка «Круг N • до Омска X км» сверху по центру
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_pill = Control.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pill.draw.connect(_draw_pill)
	layer.add_child(_pill)


func _exit_tree() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.rotation = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if not p.is_dead:
		if p.global_position.y < sign_y:
			_next_loop(p)
		if loop >= 3:
			_duck_t -= delta
			if _duck_t <= 0.0:
				_duck_t = randf_range(maxf(3.0, 9.0 - loop), 11.0 - minf(loop, 6.0))
				_spawn_duck()
	# Дорога плывёт: камера покачивается
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.ignore_rotation = false
		var amp := _wobble
		cam.rotation = sin(_t * 0.9) * amp + sin(_t * 2.3) * amp * 0.3
	queue_redraw()
	_tint_node.queue_redraw()
	_pill.queue_redraw()


func _next_loop(p) -> void:
	loop += 1
	var bonus := 100 * loop
	var sc = p.get_node_or_null("scoreComponent")
	if sc and sc.has_method("add_bonus"):
		sc.add_bonus(bonus)
	Sound.play("record", -2.0, 1.0, 0.0)
	Sound.play("horn", -8.0, 0.9, 0.0)
	MobileInput.vibrate(80)
	var hud = get_tree().get_first_node_in_group("hud")
	var absurd: String = ABSURD[mini(loop, ABSURD.size() - 1)] if loop < ABSURD.size() else "Омска становится ещё больше"
	if hud:
		hud.toast("Вы снова въезжаете в Омск! Круг %d: %s  +%d" % [loop + 1, absurd.to_lower(), bonus], Art.YELLOW, 3.2)
		if hud.has_method("_pop_center"):
			hud._pop_center("ОМСК × %d" % (loop + 1), Art.YELLOW)
	_apply_absurd()
	# Следующий круг короче (но не до бесконечности)
	_loop_len = maxf(9000.0, BASE_LEN * pow(0.92, loop if loop >= 6 else 0))
	sign_y -= _loop_len


func _apply_absurd() -> void:
	if _spawner:
		_spawner._loop_level = loop
		for entry in _spawner.hazard_table:
			if entry.kind == "pothole":
				entry.weight = int(entry.weight * 1.25) + 1
			elif entry.kind == "zigzag" and loop >= 5:
				entry.weight += 6
				entry.unlock = 0
	if loop >= 2:
		_wobble = minf(0.02 + 0.006 * (loop - 2), 0.055)
	if loop >= 4:
		_tint = minf(0.06 + 0.02 * (loop - 4), 0.16)
	if loop >= 8:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.base_max_speed *= 1.05


func _spawn_duck() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var duck = GiantDuck.new()
	var from_left := randf() < 0.5
	duck.global_position = Vector2(Art.ROAD_LEFT - 60.0 if from_left else Art.ROAD_RIGHT + 60.0,
		cam.global_position.y - Art.VIEW_H / 2.0 - randf_range(80.0, 260.0))
	get_tree().current_scene.add_child(duck)


func km_left() -> float:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return 0.0
	return maxf(0.0, (p.global_position.y - sign_y) / PX_PER_KM)


# ---------------------------------------------------------------------------
# Рисование: арка «ОМСК» над дорогой
# ---------------------------------------------------------------------------
func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or absf(sign_y - cam.global_position.y) > 1400.0:
		return
	var y := sign_y
	var L := Art.ROAD_LEFT - 30.0
	var R := Art.ROAD_RIGHT + 30.0
	# Опоры на тротуарах и тень балки на асфальте
	draw_rect(Rect2(L, y + 30, R - L, 46), Color(0, 0, 0, 0.18))
	for x in [L, R]:
		draw_circle(Vector2(x + 6, y + 12), 16, Art.SHADOW)
		draw_circle(Vector2(x, y), 15, Color("8a8f9c"))
		draw_circle(Vector2(x, y), 9, Color("6d7182"))
	Art.rrect(self, Rect2(L, y - 10, R - L, 20), Color("6d7182"), 6, 2, Art.INK)
	# Синяя табличка «ОМСК» и подпись круга
	var w := 420.0
	var plate := Rect2((L + R) / 2.0 - w / 2.0, y - 46, w, 86)
	Art.rrect(self, Rect2(plate.position + Vector2(8, 14), plate.size), Art.SHADOW, 10)
	Art.rrect(self, plate, Color("2a5bd7"), 10, 4, Color("eef0f6"))
	var next_loop := loop + 1
	var sub: String = SUBTITLES[mini(next_loop, SUBTITLES.size() - 1)]
	Art.text_center(self, plate.get_center() + Vector2(0, -12 if sub != "" else 0), "ОМСК", 44, Color("eef0f6"), true)
	if sub != "":
		Art.text_center(self, plate.get_center() + Vector2(0, 26), sub, 18, Art.YELLOW, true)
	# «Омск 0 км» на обочине перед аркой
	var st := Rect2(Art.ROAD_RIGHT + 4, y + 120, 48, 40)
	Art.rrect(self, st, Color("2a5bd7"), 4, 2, Color("eef0f6"))
	Art.text_center(self, st.get_center() + Vector2(0, -7), "ОМСК", 9, Color("eef0f6"), true)
	Art.text_center(self, st.get_center() + Vector2(0, 8), "0 км", 9, Color("eef0f6"))


## «Небо меняет цвет»: мягкая переливающаяся подсветка всего мира
func _draw_tint() -> void:
	if _tint <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := Color.from_hsv(fmod(_t * 0.07, 1.0), 0.8, 1.0, _tint)
	_tint_node.draw_rect(Rect2(cam.global_position - Vector2(1400, 900), Vector2(2800, 1800)), c)


func _draw_pill() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.is_dead:
		return
	var vs := _pill.get_viewport_rect().size
	var w := 300.0
	var r := Rect2(vs.x / 2.0 - w / 2.0, 12, w, 40)
	Art.rrect(_pill, r, Color(Art.UI_PANEL, 0.88), 10, 2, Color("2a5bd7"))
	var txt := "Круг %d  •  до Омска %s км" % [loop + 1, ("%.1f" % km_left()).replace(".", ",")]
	Art.text_center(_pill, r.get_center(), txt, 15, Art.UI_TEXT, true)
