extends "res://scripts/events/RoadEvent.gd"
## Колонна фур: две соседние полосы заняты встречными грузовиками бампер к бамперу.
## Обогнать или «протиснуться» нельзя — нужно заранее уйти с этих полос и переждать.
## Прошли колонну без единого удара — бонус.

const EnemyScene := preload("res://scenes/EnemyCar.tscn")
const SPACING := 236.0

var lanes: Array = []
var count: int = 5
var trucks: Array = []
var _hp_start: float = -1.0
var _spawned: bool = false


func _init() -> void:
	kind = "convoy"
	length = 400.0
	max_age = 20.0
	# Пока идёт колонна, спавнер ставит только бонусы, а дорогу впереди расчищаем целиком:
	# сама колонна и есть испытание
	spawn_policy = "pickups"
	clear_all_lanes = true


func setup(first_lane: int, n: int) -> void:
	lanes = [first_lane, first_lane + 1]
	lanes_blocked = lanes.duplicate()
	count = n


func start() -> void:
	toast("Колонна фур навстречу! Уходи с полос и пережди", Art.YELLOW, 2.6)
	call_deferred("_spawn_trucks")


func _spawn_trucks() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p:
		_hp_start = p.current_health
	var location: Dictionary = GameData.get_location(SaveManager.selected_location)
	var palette := [Color("c94f3d"), Color("3d6fc9"), Color("e0a326"), Color("4f9a62"), Color("7a5c9e")]
	for li in lanes.size():
		var lane: int = lanes[li]
		for i in count:
			var truck = EnemyScene.instantiate()
			truck.behavior = 2           # грузовик
			truck.no_yield = true
			truck.max_speed = 260.0 * location.get("enemy_speed", 1.0)
			truck.global_position = Vector2(lane_center(lane), global_position.y - i * SPACING - li * 110.0)
			get_tree().current_scene.add_child(truck)
			truck.body_color = palette[(i + li) % palette.size()]
			trucks.append(truck)
	_spawned = true


func _is_done(p) -> bool:
	if not _spawned:
		return false
	for t in trucks:
		# Грузовик, упёршийся в ограждение, колонну не держит
		if is_instance_valid(t) and not t._blocked and t.global_position.y < p.global_position.y + 160.0:
			return false
	return true


func _on_finished(p) -> void:
	lanes_blocked = []
	if _hp_start >= 0.0 and p.current_health >= _hp_start - 0.01:
		add_score(60)
		Sound.play("record", -6.0, 1.15, 0.0)
		toast("Колонна пропущена без единой царапины! +60", Art.GREEN, 2.2)


func _gone_behind(_cam_bottom: float) -> bool:
	return finished


func hud_info(p) -> Dictionary:
	if not _spawned or finished:
		return {}
	var in_danger := false
	var lane := clampi(int((p.global_position.x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)
	in_danger = lane in lanes
	return {"title": "Колонна фур", "text": "Уходи с полос!" if in_danger else "Пережди, обгона нет",
		"color": Art.RED if in_danger else Art.YELLOW, "lanes_closed": lanes}
