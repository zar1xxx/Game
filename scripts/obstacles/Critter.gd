extends Area2D
## Живность и прохожие новых трасс, которые выходят на дорогу:
##   moose  — лось (трасса): неспешно пересекает дорогу, удар больной;
##   bear   — медведь (тайга): выходит на середину, встаёт на задние лапы и рычит;
##   granny — бабушка с тачкой (дачи): в последний момент отскакивает, а вот тачка с навозом…;
##   dog    — собака (дачи): выскакивает с обочины и гонится за машиной, лая. Не опасна.
## Узел создаётся кодом (без сцены): Critter.new() + kind, позиция — у края дороги.

var kind: String = "moose"
var _dir: float = 1.0
var _speed: float = 60.0
var _t: float = 0.0
var _pause: float = 0.0
var _paused_once: bool = false
var _hit: bool = false
var _dodge: bool = false           # бабушка отскочила
var _chase_t: float = 0.0          # собака: сколько уже гонится
var _barked: bool = false
var _gave_up: bool = false
var _seed: float = 0.0


func _ready() -> void:
	add_to_group("hazards")
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = {"moose": 30.0, "bear": 30.0, "granny": 22.0, "dog": 14.0}.get(kind, 26.0)
	shape.shape = c
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_dir = 1.0 if global_position.x < Art.ROAD_LEFT + Art.ROAD_W / 2.0 else -1.0
	_t = randf() * TAU
	_seed = randf() * 100.0
	match kind:
		"moose":
			_speed = randf_range(55.0, 80.0)
		"bear":
			_speed = randf_range(45.0, 65.0)
		"granny":
			_speed = randf_range(32.0, 45.0)
		"dog":
			_speed = 260.0
	z_index = 1


func _physics_process(delta: float) -> void:
	_t += delta
	var mid := Art.ROAD_LEFT + Art.ROAD_W / 2.0
	match kind:
		"dog":
			_update_dog(delta)
		_:
			if _pause > 0.0:
				_pause -= delta
			else:
				position.x += _dir * _speed * delta
				# Посреди дороги можно и постоять: лось оглядывается, медведь рычит, бабушка отдыхает
				if not _paused_once and absf(global_position.x - mid) < Art.LANE_W * 0.6 and not _dodge:
					_paused_once = true
					if kind == "bear" or randf() < 0.5:
						_pause = randf_range(1.0, 1.8) if kind != "bear" else 1.6
						if kind == "bear":
							Sound.play("growl", -4.0, randf_range(0.9, 1.05), 0.0)
			# Бабушка видит машину и отскакивает (тачка остаётся на месте)
			if kind == "granny" and not _dodge and not _hit:
				var p = get_tree().get_first_node_in_group("player")
				if p and p.global_position.y - global_position.y < 260.0 and p.global_position.y > global_position.y \
						and absf(p.global_position.x - global_position.x) < 90.0:
					_dodge = true
	queue_redraw()
	var camera := get_viewport().get_camera_2d()
	if (camera and global_position.y > camera.global_position.y + Art.half_view_h() + 200.0) \
			or global_position.x < Art.ROAD_LEFT - 420.0 or global_position.x > Art.ROAD_RIGHT + 420.0:
		queue_free()


## Собака: выбегает к машине, бежит рядом, лает и через пару секунд отстаёт
func _update_dog(delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.is_dead:
		return
	var dy: float = p.global_position.y - global_position.y
	if _gave_up:
		position.x += _dir * -90.0 * delta             # уходит обратно на обочину
		return
	if dy > 700.0:
		return                                         # машина ещё далеко — ждёт у забора
	_chase_t += delta
	if not _barked:
		_barked = true
		Sound.play("bark", -6.0, randf_range(0.9, 1.15), 0.0)
	# Бежит чуть сбоку от машины, но не залезает под колёса
	var side := -1.0 if global_position.x < p.global_position.x else 1.0
	var tx: float = p.global_position.x + side * (p.CAR_WIDTH * 0.5 + 34.0)
	var ty: float = p.global_position.y + 10.0 + sin(_t * 3.0) * 20.0
	var k := clampf(delta * 3.0, 0.0, 1.0)
	global_position = global_position.lerp(Vector2(tx, ty), k)
	if fmod(_t, 0.9) < delta:
		Sound.play("bark", -10.0, randf_range(1.0, 1.25), 0.0)
	if _chase_t > 3.2:
		_gave_up = true
		_dir = side
		var hud = get_tree().get_first_node_in_group("hud")
		var sc = p.get_node_or_null("scoreComponent")
		if sc and sc.has_method("add_bonus"):
			sc.add_bonus(10)
		if hud:
			hud.toast(["Собака отстала. Гордая победа! +10", "Тузик вернулся охранять дачу +10",
				"Гав-гав! — сказала собака и отстала +10"].pick_random(), Art.YELLOW, 1.8)


func _draw() -> void:
	match kind:
		"moose":
			_draw_moose()
		"bear":
			_draw_bear()
		"granny":
			_draw_granny()
		"dog":
			_draw_dog()


func _legs(xs: Array, ys: Array, col: Color, walk: float) -> void:
	for lx in xs:
		for ly in ys:
			draw_circle(Vector2(lx + (walk if ly < 0 else -walk), ly), 4, col)


func _draw_moose() -> void:
	var walk := 0.0 if _pause > 0.0 else sin(_t * 7.0) * 4.0
	Art.rrect(self, Rect2(Vector2(-36, -16) + Vector2(6, 8), Vector2(72, 32)), Color(0, 0, 0, 0.25), 14)
	_legs([-22.0, 20.0], [-14.0, 14.0], Color("2a1f18"), walk)
	Art.rrect(self, Rect2(-34, -15, 68, 30), Color("6b4a32"), 14, 2, Color("3f2a1c"))
	draw_circle(Vector2(-8 * _dir, 0), 10, Color("5a3d28"))                    # горб
	var hc := Vector2(40 * _dir, sin(_t * 1.5) * 2.0)
	draw_circle(hc, 12, Color("6b4a32"))
	draw_circle(hc + Vector2(9 * _dir, 0), 8, Color("5a3d28"))                 # длинная морда
	# Лопатообразные рога
	for s in [-1.0, 1.0]:
		var base := hc + Vector2(-4 * _dir, s * 9)
		draw_colored_polygon(PackedVector2Array([base, base + Vector2(-10 * _dir, s * 22), base + Vector2(4 * _dir, s * 28),
			base + Vector2(10 * _dir, s * 18)]), Color("d8c49a"))
	if _pause > 0.0:
		Art.text_center(self, hc + Vector2(0, -34), "?!", 16, Art.UI_TEXT, true)


func _draw_bear() -> void:
	var walk := 0.0 if _pause > 0.0 else sin(_t * 6.0) * 4.0
	var rear := _pause > 0.0
	Art.rrect(self, Rect2(Vector2(-32, -20) + Vector2(6, 8), Vector2(64, 40)), Color(0, 0, 0, 0.28), 18)
	if not rear:
		_legs([-18.0, 18.0], [-17.0, 17.0], Color("2a1a12"), walk)
	Art.rrect(self, Rect2(-30, -19, 60, 38), Color("5a3a22"), 18, 2, Color("2f1e12"))
	draw_circle(Vector2(-6 * _dir, 0), 12, Color("6b4a2e"))
	var hc := Vector2(32 * _dir, 0)
	draw_circle(hc, 14, Color("5a3a22"))
	draw_circle(hc + Vector2(-6 * _dir, -11), 5, Color("5a3a22"))                # уши
	draw_circle(hc + Vector2(-6 * _dir, 11), 5, Color("5a3a22"))
	draw_circle(hc + Vector2(9 * _dir, 0), 6, Color("8a6a4a"))
	draw_circle(hc + Vector2(13 * _dir, 0), 2.5, Art.INK)
	if rear:
		# Встал и рычит: лапы в стороны
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(8 * _dir, s * 26), 7, Color("5a3a22"))
		Art.text_center(self, hc + Vector2(0, -36), "Р-Р-Р!", 16, Art.RED, true)


func _draw_granny() -> void:
	var walk := 0.0 if _pause > 0.0 else sin(_t * 9.0) * 2.5
	# Тачка с навозом впереди бабушки
	var cart := Vector2(18 * _dir, 0)
	Art.rrect(self, Rect2(cart - Vector2(16, 13) + Vector2(4, 5), Vector2(32, 26)), Color(0, 0, 0, 0.22), 6)
	Art.rrect(self, Rect2(cart - Vector2(16, 13), Vector2(32, 26)), Color("6d7f6a"), 6, 2, Color("3d4a3a"))
	draw_circle(cart, 9, Color("5a3d22"))
	draw_circle(cart + Vector2(4, -3), 4, Color("6b4a2e"))
	draw_circle(cart + Vector2(17 * _dir, 0), 5, Art.INK)                        # колесо
	draw_line(cart + Vector2(-14 * _dir, -10), Vector2(-4 * _dir, -6), Color("8a6a4a"), 2.5)
	draw_line(cart + Vector2(-14 * _dir, 10), Vector2(-4 * _dir, 6), Color("8a6a4a"), 2.5)
	if _hit:
		return                                                                      # бабушка уже на обочине
	var gp := Vector2(-10 * _dir, walk)
	if _dodge:
		gp += Vector2(-_dir * 50.0, 0.0)                                            # отскочила назад, к обочине
	draw_circle(gp + Vector2(3, 4), 11, Color(0, 0, 0, 0.22))
	draw_set_transform(gp, 0, Vector2(1.0, 0.8))
	draw_circle(Vector2.ZERO, 11, Color("8a5a9a"))                                 # халат
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_circle(gp, 6, Color("e8505b"))                                            # платок
	draw_circle(gp + Vector2(2 * _dir, 0), 3, Color("e8c49a"))
	if _dodge:
		Art.text_center(self, gp + Vector2(0, -22), "Ой!", 13, Art.UI_TEXT, true)


func _draw_dog() -> void:
	var run := sin(_t * 16.0) * 3.0
	# Пока гонится — бежит вверх вместе с машиной, потом поворачивает к обочине
	var ang := -PI / 2.0 if not _gave_up else (0.0 if _dir > 0.0 else PI)
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	draw_circle(Vector2(4, 5), 10, Color(0, 0, 0, 0.22))
	Art.rrect(self, Rect2(-14, -7, 28, 14), Color("c48a52"), 6)
	draw_circle(Vector2(16, run * 0.3), 7, Color("c48a52"))
	draw_circle(Vector2(14, -5), 3, Color("8a5a30"))
	draw_circle(Vector2(14, 5), 3, Color("8a5a30"))
	draw_line(Vector2(-14, 0), Vector2(-22, run), Color("8a5a30"), 2.5)
	for lx in [-8.0, 8.0]:
		draw_circle(Vector2(lx + run, -7), 2.5, Color("6b4526"))
		draw_circle(Vector2(lx - run, 7), 2.5, Color("6b4526"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _gave_up and _chase_t > 0.0 and fmod(_t, 0.9) < 0.35:
		Art.text_center(self, Vector2(0, -24), "Гав!", 13, Art.UI_TEXT, true)


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player") or kind == "dog":
		return
	_hit = true
	var hud = get_tree().get_first_node_in_group("hud")
	match kind:
		"moose":
			Sound.play("moose", -2.0, randf_range(0.9, 1.05), 0.0)
			if body.has_method("hit_hazard"):
				body.hit_hazard(12.0, 0.45, 10.0, "moose")
			_speed *= 2.5
			_pause = 0.0
			if hud and randf() < 0.6:
				hud.toast(["Лось не уступил дорогу", "Лось: «Это моя трасса»", "Лось сделал вид, что так и надо"].pick_random(), Art.YELLOW, 1.8)
		"bear":
			Sound.play("growl", 0.0, 0.85, 0.0)
			Achievements.event("bear")
			if body.has_method("hit_hazard"):
				body.hit_hazard(15.0, 0.4, 12.0, "bear")
			_speed *= 2.0
			_pause = 0.0
			if hud:
				hud.toast(["Хозяин тайги недоволен", "Медведь записал вас в должники", "Миша обиделся и ушёл в лес"].pick_random(), Art.RED, 2.0)
		"granny":
			Sound.play("splat", -2.0, 0.8, 0.0)
			if body.has_method("hit_hazard"):
				body.hit_hazard(4.0, 0.6, 6.0, "cart")
			_dodge = true
			if hud:
				hud.toast(["Бабушка ловко отскочила. А тачка с навозом — нет!", "Бабушка погрозила вам тяпкой",
					"Навоз на лобовом — к урожаю!"].pick_random(), Art.YELLOW, 2.2)
			if hud and hud.fx and hud.fx.has_method("_splat"):
				hud.fx._splat(Vector2(randf_range(200.0, 900.0), randf_range(120.0, 360.0)))
