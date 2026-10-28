extends Node2D
## «Демо-режим» для фона главного меню: камера едет вверх,
## машина игрока сама перестраивается между полосами, навстречу едет поток.

@export var cruise_speed: float = 520.0
@export var traffic_speed: float = 200.0

var _cars: Array = []          # встречные машины: {pos, color, truck}
var _hero_x: float = 0.0
var _hero_lane: int = 1
var _hero_vx: float = 0.0
var _t: float = 0.0
var _decide_in: float = 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_hero_x = _lane_x(_hero_lane)


func _lane_x(lane: int) -> float:
	return Art.ROAD_LEFT + Art.LANE_W * (lane + 0.5)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	cam.global_position.y -= cruise_speed * delta
	var hero_y := cam.global_position.y + 190.0

	# Встречный поток
	var top := cam.global_position.y - Art.VIEW_H / 2.0
	while _cars.size() < 5:
		var lane := _rng.randi() % Art.LANES
		var y := top - _rng.randf_range(150.0, 900.0)
		var ok := true
		for c in _cars:
			if absf(c.pos.x - _lane_x(lane)) < 10.0 and absf(c.pos.y - y) < 260.0:
				ok = false
		if ok:
			_cars.append({"pos": Vector2(_lane_x(lane), y),
				"color": Art.ENEMY_COLORS[_rng.randi() % Art.ENEMY_COLORS.size()],
				"truck": _rng.randf() < 0.15})
	for c in _cars.duplicate():
		c.pos = c.pos + Vector2(0, traffic_speed * delta)
		if c.pos.y > cam.global_position.y + Art.VIEW_H:
			_cars.erase(c)

	# Машина игрока объезжает встречных
	_decide_in -= delta
	var danger := false
	for c in _cars:
		if absf(c.pos.x - _lane_x(_hero_lane)) < 10.0 and c.pos.y < hero_y and hero_y - c.pos.y < 520.0:
			danger = true
	if danger or _decide_in <= 0.0:
		_decide_in = _rng.randf_range(1.5, 3.5)
		var best := _hero_lane
		var best_free := -1.0
		for lane in Art.LANES:
			var free := 2000.0
			for c in _cars:
				if absf(c.pos.x - _lane_x(lane)) < 10.0 and c.pos.y < hero_y:
					free = minf(free, hero_y - c.pos.y)
			free -= absf(lane - _hero_lane) * 120.0
			if free > best_free:
				best_free = free
				best = lane
		_hero_lane = best
	var target := _lane_x(_hero_lane)
	var new_x := move_toward(_hero_x, target, 260.0 * delta)
	_hero_vx = (new_x - _hero_x) / maxf(delta, 0.0001)
	_hero_x = new_x
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	for c in _cars:
		if c.truck:
			Art.draw_truck(self, 190, 66, c.color, Art.SILVER, {"flip": true, "base": Transform2D(0, c.pos)})
		else:
			Art.draw_car(self, 100, 50, c.color, {"flip": true, "lights": true, "base": Transform2D(0, c.pos)})
	var hero := Vector2(_hero_x, cam.global_position.y + 190.0)
	var tilt := clampf(_hero_vx / 900.0, -0.35, 0.35)
	# Едет машина, выбранная в магазине
	Art.draw_vehicle(self, GameData.get_car(SaveManager.selected_car), {"lights": true, "time": _t,
		"steer": tilt * 2.0, "base": Transform2D(tilt, hero)})
