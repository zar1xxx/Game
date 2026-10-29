extends Node2D
## Озеро «Звенящий лёд»: время от времени впереди по льду с треском бегут трещины.
## Это только картинка и звук — ехать по трещине можно, но сердце ёкает.

var _cracks: Array = []           # {"pts": PackedVector2Array, "grow": осталось вырасти (px), "dir": Vector2}
var _next: float = 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = -15
	_rng.seed = SaveManager.run_seed + 404


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(4.0, 8.0)
		var start := Vector2(_rng.randf_range(Art.ROAD_LEFT + 40, Art.ROAD_RIGHT - 40), cam.global_position.y - Art.half_view_h() + 60.0)
		var dir := Vector2(_rng.randf_range(-0.6, 0.6), -1.0).normalized()
		_cracks.append({"pts": PackedVector2Array([start]), "grow": _rng.randf_range(500.0, 900.0), "dir": dir, "branches": []})
		Sound.play("crack", -6.0, _rng.randf_range(0.85, 1.2), 0.0)
	var changed := false
	for c in _cracks:
		if c.grow > 0.0:
			var step := minf(c.grow, 650.0 * delta)
			c.grow -= step
			var last: Vector2 = c.pts[c.pts.size() - 1]
			c.dir = (c.dir + Vector2(_rng.randf_range(-0.5, 0.5), 0.0)).normalized()
			var np: Vector2 = last + c.dir * step
			np.x = clampf(np.x, Art.ROAD_LEFT + 10, Art.ROAD_RIGHT - 10)
			c.pts.append(np)
			# Иногда отходит ветка
			if _rng.randf() < 0.12:
				c.branches.append(PackedVector2Array([np, np + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-50, -10))]))
			changed = true
	# Трещины позади камеры удаляем
	var bottom := cam.global_position.y + Art.half_view_h() + 200.0
	var i := _cracks.size() - 1
	while i >= 0:
		var pts: PackedVector2Array = _cracks[i].pts
		var max_y := -INF
		for p in pts:
			max_y = maxf(max_y, p.y)
		if pts[pts.size() - 1].y > bottom and max_y > bottom:
			_cracks.remove_at(i)
			changed = true
		i -= 1
	if changed:
		queue_redraw()


func _draw() -> void:
	for c in _cracks:
		if c.pts.size() < 2:
			continue
		draw_polyline(c.pts, Color(1, 1, 1, 0.25), 6.0)
		draw_polyline(c.pts, Color(0.92, 0.98, 1.0, 0.95), 2.0)
		for b in c.branches:
			draw_polyline(b, Color(0.92, 0.98, 1.0, 0.8), 1.5)
