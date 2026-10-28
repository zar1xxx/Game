extends Control
## Экранные эффекты поверх игры:
##  • линии скорости по краям при нитро и на большой скорости;
##  • красная виньетка, когда машина почти разбита, и вспышка при ударе;
##  • светофор для отсчёта перед стартом;
##  • конфетти при новом рекорде;
##  • всплывающие надписи у машины («На волоске! +15»).

var player = null
var _t: float = 0.0
var _lines: Array = []
var _confetti: Array = []
var _hit_flash: float = 0.0
var _last_hp: float = -1.0
var light_state: int = -1        # светофор: -1 скрыт, 0 красный, 1 жёлтый, 2 зелёный
var _light_alpha: float = 0.0

# --- Омск: птица и её «подарки» на лобовом стекле ---
var omsk: bool = false
var _bird: Dictionary = {}
var _bird_timer: float = 12.0
var _splats: Array = []
var _omsk_toast_timer: float = 25.0
const OMSK_TOASTS := [
	"Вы покидаете Омск… нет, не покидаете",
	"Добро пожаловать в Омск! Снова.",
	"Навигатор: «Вы прибыли в Омск». Опять.",
	"Степаныч машет вам из люка",
	"Говорят, в Омске строят вторую станцию метро. С 1992 года",
	"Табличка: «Омск 0 км». Едем дальше…",
	"Если долго ехать из Омска, приедешь в Омск",
	"Любочка на скамейке болеет за вас!",
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 26:
		_lines.append({"y": randf(), "side": -1.0 if i % 2 == 0 else 1.0, "len": randf_range(60, 200),
			"spd": randf_range(1.2, 2.4), "x": randf_range(0.0, 0.22)})


func _process(delta: float) -> void:
	_t += delta
	# Слой всегда во весь экран (на телефонах с другим соотношением сторон тоже)
	var vs := get_viewport_rect().size
	if size != vs:
		position = Vector2.ZERO
		size = vs
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	var paused := get_tree().paused
	if player and not paused:
		var hp: float = player.current_health
		if _last_hp >= 0.0 and hp < _last_hp - 0.5:
			_hit_flash = 1.0
		_last_hp = hp
		for l in _lines:
			l.y += l.spd * delta
			if l.y > 1.1:
				l.y = -0.15
				l.x = randf_range(0.0, 0.22)
				l.len = randf_range(60, 200)
	if omsk and not paused and player and not player.is_dead:
		_update_omsk(delta)
	for sp in _splats:
		sp.life -= delta
	_splats = _splats.filter(func(sp): return sp.life > 0.0)
	_hit_flash = move_toward(_hit_flash, 0.0, delta * 3.0)
	_light_alpha = move_toward(_light_alpha, 1.0 if light_state >= 0 else 0.0, delta * 4.0)
	for c in _confetti:
		c.v.y += 380.0 * delta
		c.v.x *= 1.0 - 0.8 * delta
		c.p += c.v * delta
		c.r += c.w * delta
		c.life -= delta
	_confetti = _confetti.filter(func(c): return c.life > 0.0)
	queue_redraw()


func _draw() -> void:
	_draw_bird()
	_draw_splats()
	_draw_speed_lines()
	_draw_vignette()
	_draw_traffic_light()
	for c in _confetti:
		draw_set_transform(c.p, c.r, Vector2.ONE)
		var w: float = 10.0 * absf(cos(c.r * 2.0)) + 2.0
		draw_rect(Rect2(-w / 2.0, -4, w, 8), Color(c.col, clampf(c.life, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_speed_lines() -> void:
	if player == null or player.is_dead:
		return
	var cruise: float = player.get_cruise_speed()
	var k := 0.0
	if player.nitro_time_left > 0.0:
		k = 1.0
	else:
		k = clampf((player.current_speed / cruise - 1.02) * 6.0, 0.0, 0.6)
	if k <= 0.01:
		return
	var col := Art.TEAL if player.nitro_time_left > 0.0 else Art.UI_TEXT
	for l in _lines:
		var x: float = size.x * l.x if l.side < 0 else size.x * (1.0 - l.x)
		var y: float = size.y * l.y
		draw_line(Vector2(x, y), Vector2(x, y + l.len * (0.6 + k)), Color(col, 0.38 * k), 2.5)


func _draw_vignette() -> void:
	var a := 0.0
	if player and not player.is_dead:
		var hp_k: float = player.current_health / player.max_health
		if hp_k < 0.3:
			a = (0.3 - hp_k) / 0.3 * (0.55 + 0.25 * sin(_t * 6.0))
	a = maxf(a, _hit_flash * 0.6)
	if a <= 0.01:
		return
	# Виньетка из полупрозрачных полос по краям
	var steps := 10
	for i in steps:
		var w := 70.0 * (1.0 - float(i) / steps)
		var c := Color(Art.RED, a * 0.12)
		draw_rect(Rect2(0, 0, w, size.y), c)
		draw_rect(Rect2(size.x - w, 0, w, size.y), c)
		draw_rect(Rect2(0, 0, size.x, w * 0.7), c)
		draw_rect(Rect2(0, size.y - w * 0.7, size.x, w * 0.7), c)


func _draw_traffic_light() -> void:
	if _light_alpha <= 0.01:
		return
	var a := _light_alpha
	var w := 74.0
	var h := 196.0
	var pos := Vector2(size.x / 2.0 - w / 2.0, size.y * 0.5 - 130.0 - h * 0.5 + (1.0 - a) * -60.0)
	Art.rrect(self, Rect2(pos + Vector2(6, 8), Vector2(w, h)), Color(0, 0, 0, 0.35 * a), 16)
	Art.rrect(self, Rect2(pos, Vector2(w, h)), Color(Art.INK, a), 16)
	Art.rrect(self, Rect2(pos + Vector2(4, 4), Vector2(w - 8, h - 8)), Color(Art.UI_PANEL_LIGHT, a), 13)
	var cols := [Art.RED, Art.YELLOW, Art.GREEN]
	for i in 3:
		var cc := pos + Vector2(w / 2.0, 36.0 + i * 62.0)
		var on := light_state == i or (light_state == 2 and i == 2)
		if on:
			Art.glow(self, cc, 64.0, Color(cols[i], 0.55 * a))
			draw_circle(cc, 24.0, Color(cols[i], a))
			draw_circle(cc + Vector2(-7, -7), 7.0, Color(1, 1, 1, 0.35 * a))
		else:
			draw_circle(cc, 24.0, Color(cols[i].darkened(0.75), a))


# ---------------------------------------------------------------------------
func confetti(amount: int = 120) -> void:
	var cols := [Art.ORANGE, Art.YELLOW, Art.TEAL, Art.RED, Art.PURPLE, Art.GREEN, Art.BLUE]
	for i in amount:
		var from_left := i % 2 == 0
		_confetti.append({
			"p": Vector2(-10.0 if from_left else size.x + 10.0, size.y * randf_range(0.45, 0.9)),
			"v": Vector2((1.0 if from_left else -1.0) * randf_range(250, 700), randf_range(-750, -350)),
			"r": randf() * TAU, "w": randf_range(-10, 10),
			"col": cols[randi() % cols.size()], "life": randf_range(2.0, 3.2)})


## Надпись, всплывающая в точке экрана и улетающая вверх
func popup(text: String, screen_pos: Vector2, color: Color, font_size: int = 26) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Art.font_title)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Art.INK)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(320, 40)
	label.position = screen_pos - Vector2(160, 20)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(0.4, 0.4)
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "position:y", label.position.y - 70.0, 0.9)
	tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(label.queue_free)


# ---------------------------------------------------------------------------
# Омская птица
# ---------------------------------------------------------------------------
func _update_omsk(delta: float) -> void:
	_omsk_toast_timer -= delta
	if _omsk_toast_timer <= 0.0:
		_omsk_toast_timer = randf_range(30.0, 45.0)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.toast(OMSK_TOASTS.pick_random(), Art.YELLOW, 3.0)
	if _bird.is_empty():
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = randf_range(14.0, 24.0)
			var from_left := randf() < 0.5
			_bird = {"x": -60.0 if from_left else size.x + 60.0, "dir": 1.0 if from_left else -1.0,
				"y": size.y * randf_range(0.15, 0.45), "t": 0.0, "drop": randf() < 0.55, "dropped": false}
			Sound.play("bird", -4.0)
		return
	_bird.t += delta
	_bird.x += _bird.dir * 430.0 * delta
	_bird.y += sin(_bird.t * 3.0) * 20.0 * delta
	# Пролетая над серединой экрана, птица может «отметиться» на лобовом стекле
	if _bird.drop and not _bird.dropped and absf(_bird.x - size.x / 2.0) < 120.0:
		_bird.dropped = true
		_splat(Vector2(size.x / 2.0 + randf_range(-220, 220), size.y * randf_range(0.35, 0.7)))
	if _bird.x < -100.0 or _bird.x > size.x + 100.0:
		_bird = {}


func _splat(pos: Vector2) -> void:
	var blobs: Array = []
	for i in randi_range(5, 8):
		blobs.append([Vector2(randf_range(-40, 40), randf_range(-30, 30)), randf_range(14, 34)])
	var drips: Array = []
	for i in randi_range(2, 4):
		drips.append([randf_range(-30, 30), randf_range(30, 90), randf_range(5, 9)])
	_splats.append({"pos": pos, "blobs": blobs, "drips": drips, "life": 5.5, "age": 0.0})
	Sound.play("splat", 0.0)
	MobileInput.vibrate(30)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.toast(["Омская птица оставила вам подарок!", "Прямо в лобовое! Это к деньгам",
			"Дворники бессильны против омской птицы"].pick_random(), Art.UI_TEXT, 2.5)


func _draw_bird() -> void:
	if _bird.is_empty():
		return
	var p := Vector2(_bird.x, _bird.y)
	var flap := sin(_bird.t * 16.0)
	var d: float = _bird.dir
	# Тень на дороге, ниже птицы
	draw_set_transform(p + Vector2(30, 140), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := Color("4a4d57")
	var wing_y := -22.0 * flap
	draw_colored_polygon(PackedVector2Array([p + Vector2(-6 * d, 0), p + Vector2(-30 * d, wing_y - 6), p + Vector2(4 * d, -4)]), body.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-6 * d, 0), p + Vector2(-26 * d, -wing_y + 6), p + Vector2(4 * d, 4)]), body.darkened(0.1))
	draw_set_transform(p, 0.0, Vector2(1.6, 1.0))
	draw_circle(Vector2.ZERO, 9, body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(p + Vector2(14 * d, -4), 7, body.lightened(0.1))
	draw_circle(p + Vector2(17 * d, -6), 2, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([p + Vector2(20 * d, -5), p + Vector2(28 * d, -3), p + Vector2(20 * d, -1)]), Art.ORANGE)


func _draw_splats() -> void:
	for sp in _splats:
		var a := clampf(sp.life / 1.5, 0.0, 1.0) * 0.92
		var grow := clampf((5.5 - sp.life) * 8.0, 0.2, 1.0)
		var c := Color(0.93, 0.92, 0.86, a)
		var edge := Color(0.6, 0.6, 0.55, a)
		var p: Vector2 = sp.pos
		for dr in sp.drips:
			var len: float = dr[1] * clampf((5.5 - sp.life) / 2.0, 0.0, 1.0)
			draw_line(p + Vector2(dr[0], 0), p + Vector2(dr[0], len), c, dr[2])
			draw_circle(p + Vector2(dr[0], len), dr[2] * 0.6, c)
		for b in sp.blobs:
			draw_circle(p + b[0] * grow, b[1] * grow + 2.0, edge)
		for b in sp.blobs:
			draw_circle(p + b[0] * grow, b[1] * grow, c)
		draw_circle(p + Vector2(-8, -6) * grow, 10.0 * grow, Color(0.35, 0.33, 0.28, a * 0.6))
