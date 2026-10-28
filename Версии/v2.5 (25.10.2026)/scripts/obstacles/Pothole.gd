extends Area2D
## Яма на дороге. Ощутимая тряска, урон и резкая потеря скорости.

## Варианты: «pothole» — яма, «snowdrift» — сугроб (зима: урона меньше, но вязнет)
## «icehole» — полынья (лёд: из неё выныривает нерпа), «mud» — яма с грязью (тайга)
@export_enum("pothole", "snowdrift", "icehole", "mud") var variant: String = "pothole"
@export var damage: float = 8.0
@export var speed_multiplier: float = 0.6
@export var shake_strength: float = 12.0
@export var radius: Vector2 = Vector2(46, 30)

var _hit: bool = false
var _water: bool = false     # омская яма-озеро (иногда с уткой)
var _duck: bool = false
var _t: float = 0.0
var _points: PackedVector2Array
var _seal_phase: float = 0.0


func _ready() -> void:
	add_to_group("hazards")
	if Art.theme == "omsk" and variant == "pothole":
		# Омские ямы: разного калибра, часть залита водой
		radius *= randf_range(0.9, 1.45)
		_water = randf() < 0.35
		_duck = _water and randf() < 0.5
	_apply_variant()
	body_entered.connect(_on_body_entered)
	rotation = randf_range(-0.4, 0.4)
	_seal_phase = randf() * TAU
	# Неровный край ямы
	for i in 18:
		var a := TAU * i / 18.0
		var r := randf_range(0.8, 1.1)
		_points.append(Vector2(cos(a) * radius.x * r, sin(a) * radius.y * r))


func _draw() -> void:
	if variant == "icehole":
		_draw_icehole()
		return
	if variant == "mud":
		draw_colored_polygon(PackedVector2Array(Array(_points).map(func(v): return v * 1.15)), Color("4a3622"))
		draw_colored_polygon(_points, Color("5e4429"))
		for k in 3:
			var c := Vector2(sin(_t + k * 2.0) * radius.x * 0.4, cos(_t * 0.7 + k) * radius.y * 0.3)
			draw_circle(c, 5 + k, Color("745536"))
		draw_arc(Vector2.ZERO, radius.y * 0.5, PI * 1.1, PI * 1.8, 8, Color(1, 1, 1, 0.15), 2.0)
		return
	if variant == "snowdrift":
		var pts := PackedVector2Array()
		for p in _points:
			pts.append(p * 1.1)
		draw_colored_polygon(PackedVector2Array(Array(pts).map(func(v): return v + Vector2(8, 10))), Color(0.3, 0.35, 0.45, 0.35))
		draw_colored_polygon(pts, Color("eef3f8"))
		draw_colored_polygon(PackedVector2Array(Array(_points).map(func(v): return v * 0.55 + Vector2(-6, -6))), Color("ffffff"))
		return
	var outer := PackedVector2Array()
	for p in _points:
		outer.append(p * 1.18)
	draw_colored_polygon(outer, Art.ASPHALT_PATCH.lightened(0.08))  # раскрошенный край
	draw_colored_polygon(_points, Art.INK)                          # сама яма
	var inner := PackedVector2Array()
	for p in _points:
		inner.append(p * 0.6 + Vector2(radius.x * 0.12, radius.y * 0.15))
	draw_colored_polygon(inner, Color("0f1118"))
	draw_polyline(outer + PackedVector2Array([outer[0]]), Art.ASPHALT_CRACK, 2.0)
	if _water:
		var water := PackedVector2Array()
		for p in _points:
			water.append(p * 0.9)
		draw_colored_polygon(water, Color("3a5f7d"))
		draw_arc(Vector2(sin(_t) * 4.0, 0), radius.y * 0.4, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.3), 2.0)
		if _duck:
			# Резиновая уточка — местная достопримечательность
			var dp := Vector2(sin(_t * 0.8) * radius.x * 0.3, cos(_t * 0.6) * radius.y * 0.2)
			draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
			draw_circle(dp + Vector2(2, 3), 8, Color(0, 0, 0, 0.3))
			draw_circle(dp, 8, Art.YELLOW)
			draw_circle(dp + Vector2(0, -7), 5, Art.YELLOW)
			draw_circle(dp + Vector2(0, -12), 2.5, Art.ORANGE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _apply_variant() -> void:
	if variant == "snowdrift":
		damage = 3.0
		speed_multiplier = 0.5
		shake_strength = 6.0
	elif variant == "icehole":
		damage = 6.0
		speed_multiplier = 0.55
		shake_strength = 9.0
		radius *= 1.15
	elif variant == "mud":
		damage = 2.0
		speed_multiplier = 0.5
		shake_strength = 5.0
		radius *= 1.25


## Полынья: тёмная вода, кромка льда и нерпа, которая высовывает голову
func _draw_icehole() -> void:
	draw_colored_polygon(PackedVector2Array(Array(_points).map(func(v): return v * 1.2)), Color("d6ecf7"))
	draw_colored_polygon(_points, Color("1b4a6b"))
	draw_arc(Vector2.ZERO, radius.y * 0.5 + fmod(_t * 8.0, 10.0), 0, TAU, 18, Color(1, 1, 1, 0.25), 1.5)
	var up := clampf(sin(_t * 1.4 + _seal_phase) * 1.8, 0.0, 1.0)
	if up > 0.05:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		draw_circle(Vector2(0, 4 - up * 8), 12 * up + 2, Color("7a8090"))
		draw_circle(Vector2(-4, -2 - up * 9), 2.2 * up, Art.INK)
		draw_circle(Vector2(4, -2 - up * 9), 2.2 * up, Art.INK)
		draw_circle(Vector2(0, 2 - up * 7), 2.0 * up, Color("3d4152"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_body_entered(body: Node2D) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	Achievements.event("pothole")
	if body.has_method("hit_hazard"):
		body.hit_hazard(damage, speed_multiplier, shake_strength,
			{"snowdrift": "snowdrift", "mud": "mud"}.get(variant, "pothole"))
	if _water or variant == "icehole" or variant == "mud":
		Sound.play("splash", -3.0, 0.8 if variant == "mud" else 1.0)
	if variant == "icehole":
		var hud0 = get_tree().get_first_node_in_group("hud")
		if hud0 and randf() < 0.5:
			hud0.toast(["Нерпа обиделась и нырнула", "Буль! Колесо в полынье", "Нерпа: «Понаехали»"].pick_random(), Art.TEAL, 1.8)
	if Art.theme == "omsk" and randf() < 0.3:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.toast(["Яма! Историческая, охраняется государством", "Это не яма, это омский ландшафт",
				"Подвеска передаёт привет из Омска", "Яму обещали заделать ещё в 1716 году"].pick_random(), Art.YELLOW, 2.0)


func _physics_process(delta: float) -> void:
	if _water or variant == "icehole" or variant == "mud":
		_t += delta
		queue_redraw()
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view_height := get_viewport_rect().size.y / camera.zoom.y
		if global_position.y > camera.global_position.y + view_height / 2.0 + 200.0:
			if not _hit:
				Missions.event("holes")      # объехали яму — в зачёт задания
			queue_free()
