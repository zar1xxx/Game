extends Area2D
## Корова (Село Кукуево): не спеша переходит дорогу, иногда останавливается посередине
## и задумчиво жуёт. Наехать на корову — больно и машине, и самолюбию.

@export var damage: float = 8.0
var _dir: float = 1.0
var _speed: float = 60.0
var _t: float = 0.0
var _pause: float = 0.0
var _paused_once: bool = false
var _hit: bool = false
var _spots: Array = []


func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	_dir = 1.0 if global_position.x < Art.ROAD_LEFT + Art.ROAD_W / 2.0 else -1.0
	_speed = randf_range(50.0, 85.0)
	_t = randf() * TAU
	for i in 4:
		_spots.append([Vector2(randf_range(-22, 22), randf_range(-12, 12)), randf_range(6, 11)])
	($CollisionShape2D.shape as CircleShape2D).radius = 30.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _pause > 0.0:
		_pause -= delta
	else:
		position.x += _dir * _speed * delta
		# Посреди дороги корова может остановиться пожевать
		if not _paused_once and absf(global_position.x - (Art.ROAD_LEFT + Art.ROAD_W / 2.0)) < 40.0 and randf() < 0.5:
			_paused_once = true
			_pause = randf_range(1.0, 2.2)
		_paused_once = _paused_once or absf(global_position.x - (Art.ROAD_LEFT + Art.ROAD_W / 2.0)) < 40.0
	queue_redraw()
	var camera := get_viewport().get_camera_2d()
	if (camera and global_position.y > camera.global_position.y + Art.VIEW_H / 2.0 + 200.0) \
			or global_position.x < Art.ROAD_LEFT - 400.0 or global_position.x > Art.ROAD_RIGHT + 400.0:
		queue_free()


func _draw() -> void:
	var walk := 0.0 if _pause > 0.0 else sin(_t * 8.0) * 4.0
	# Тень
	Art.rrect(self, Rect2(Vector2(-34, -16) + Vector2(6, 8), Vector2(68, 34)), Color(0, 0, 0, 0.25), 14)
	# Ноги
	for lx in [-20.0, 18.0]:
		for ly in [-15.0, 15.0]:
			draw_circle(Vector2(lx + (walk if ly < 0 else -walk), ly), 4, Color("3a2f2a"))
	# Туловище (вдоль направления движения)
	Art.rrect(self, Rect2(-32, -16, 64, 32), Color("f4f1ea"), 14, 2, Color("9a958c"))
	for sp in _spots:
		draw_circle(sp[0], sp[1], Art.INK)
	# Хвост
	var tail := Vector2(-34 * _dir, 0)
	draw_line(tail, tail + Vector2(-10 * _dir, sin(_t * 5.0) * 6.0), Color("3a2f2a"), 2.0)
	# Голова с рогами
	var hc := Vector2(38 * _dir, sin(_t * 2.0) * 2.0)
	draw_circle(hc, 13, Color("f4f1ea"))
	draw_circle(hc + Vector2(6 * _dir, 0), 8, Color("f2a8b8"))           # морда
	draw_line(hc + Vector2(-4 * _dir, -10), hc + Vector2(-8 * _dir, -18), Color("d8cfa8"), 3.0)
	draw_line(hc + Vector2(-4 * _dir, 10), hc + Vector2(-8 * _dir, 18), Color("d8cfa8"), 3.0)
	draw_circle(hc + Vector2(-2 * _dir, -5), 2, Art.INK)
	draw_circle(hc + Vector2(-2 * _dir, 5), 2, Art.INK)
	if _pause > 0.0:
		Art.text_center(self, hc + Vector2(0, -30), "Му-у!", 14, Art.UI_TEXT, true)


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	Sound.play("moo", -2.0, randf_range(0.9, 1.1), 0.0)
	Achievements.event("cow")
	if body.has_method("hit_hazard"):
		body.hit_hazard(damage, 0.5, 8.0, "cow")
	# Обиженная корова отпрыгивает и уходит быстрее
	_speed *= 2.5
	_pause = 0.0
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and randf() < 0.6:
		hud.toast(["Корова обиделась", "Бурёнка записала ваш номер", "Молоко теперь будет кислое"].pick_random(), Art.YELLOW, 1.8)
