extends Node
## Дорожные события (Autoload не нужен — узел создаёт Spawner на время заезда).
## Время от времени на дороге случается что-то одно из списка:
##   АЗС на обочине, знак «60» с камерой или постом ДПС, колонна фур, ремонт дороги,
##   а в Омске ещё разведённый мост через Иртыш и весеннее половодье.
## Одновременно идёт только одно событие; во время погонь новые не начинаются.

const GasStation := preload("res://scripts/events/GasStation.gd")
const SpeedTrap := preload("res://scripts/events/SpeedTrap.gd")
const Convoy := preload("res://scripts/events/Convoy.gd")
const RoadWorks := preload("res://scripts/events/RoadWorks.gd")
const Drawbridge := preload("res://scripts/events/Drawbridge.gd")
const Flood := preload("res://scripts/events/Flood.gd")

var current = null
var fuel_price: float = 62.4
var fines_paid: int = 0
var _next: float = 18.0
var _last_kind: String = ""
var _omsk: bool = false


func _ready() -> void:
	add_to_group("road_events")
	_omsk = GameData.get_location(SaveManager.selected_location).theme == "omsk"
	_next = randf_range(15.0, 21.0)
	fuel_price = randf_range(58.0, 66.0)


func busy() -> bool:
	return current != null and is_instance_valid(current) and not current.finished


func spawn_policy() -> String:
	return current.spawn_policy if busy() else "all"


func is_lane_blocked(lane: int) -> bool:
	return busy() and lane in current.lanes_blocked


func hud_info(p) -> Dictionary:
	if busy():
		return current.hud_info(p)
	return {}


## Штраф монетами: списываем сколько есть. Возвращает фактически списанное.
func charge_fine(amount: int) -> int:
	if SaveManager.tutorial_running:  # в обучении штрафы условные
		return 0
	var paid := mini(amount, SaveManager.coins)
	if paid > 0:
		SaveManager.add_coins(-paid)
	fines_paid += paid
	return paid


func _physics_process(delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.is_dead:
		return
	if current != null and not is_instance_valid(current):
		current = null
	if busy():
		p.slow_excuse = 0.5          # во время события медленная езда полицию не злит
		return
	if p.current_speed < 200.0:      # ещё стоим на старте
		return
	if SaveManager.tutorial_running:  # в обучении событие запускают подсказки
		return
	_next -= delta
	if _next > 0.0:
		return
	var police = get_tree().get_first_node_in_group("police")
	var tck = get_tree().get_first_node_in_group("tck")
	if (police and police.state != police.State.IDLE) or (tck and tck.is_active()):
		_next = 3.0
		return
	var kind := _pick_kind(p)
	if kind == "":
		_next = 5.0
		return
	_start(kind, p)
	_next = randf_range(11.0, 19.0)


func _score(p) -> int:
	var sc = p.get_node_or_null("scoreComponent")
	return sc.max_score if sc else 0


func _pick_kind(p) -> String:
	var score := _score(p)
	var fuel_k: float = p.current_fuel / p.max_fuel
	var table := {
		"station": 2.0 + (3.0 if fuel_k < 0.45 else 0.0) + (3.0 if Missions.is_active("refuel") else 0.0),
		"camera": (2.0 + (3.0 if Missions.is_active("camera_ok") else 0.0)) if score >= 40 else 0.0,
		"convoy": 1.5 if score >= 150 else 0.0,
		"roadworks": 1.6 if score >= 90 else 0.0,
	}
	if _omsk:
		table["bridge"] = (1.6 + (3.0 if Missions.is_active("bridge") else 0.0)) if score >= 100 else 0.0
		table["flood"] = 1.5 if score >= 50 else 0.0
	table.erase(_last_kind)
	var total := 0.0
	for v in table.values():
		total += v
	if total <= 0.0:
		return ""
	var roll := randf() * total
	for k in table.keys():
		roll -= table[k]
		if roll <= 0.0:
			return k
	return table.keys()[-1]


func _start(kind: String, p) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var cam_top: float = cam.global_position.y - Art.VIEW_H / 2.0
	var ev
	match kind:
		"station":
			ev = GasStation.new()
		"camera":
			ev = SpeedTrap.new()
			ev.officer = randf() < 0.4
		"convoy":
			ev = Convoy.new()
			# Колонна занимает две соседние полосы; чаще — там, где сейчас игрок
			var pl := clampi(int((p.global_position.x - Art.ROAD_LEFT) / Art.LANE_W), 0, Art.LANES - 1)
			var first := clampi(pl - randi() % 2, 0, Art.LANES - 2)
			ev.setup(first, randi_range(4, 6))
		"roadworks":
			ev = RoadWorks.new()
			var n := 1 if randf() < 0.45 else 2
			ev.setup(randi() % (Art.LANES - n + 1), n)
		"bridge":
			ev = Drawbridge.new()
		"flood":
			ev = Flood.new()
		_:
			return
	ev.manager = self
	var start_y := cam_top - 260.0
	if kind == "convoy":
		start_y = cam_top - 650.0
	ev.position = Vector2(0, start_y)
	_clear_for(ev, cam_top)
	get_tree().current_scene.add_child(ev)
	current = ev
	_last_kind = kind
	ev.start()


## Перед событием убираем то, что уже стоит/едет на его пути за верхним краем экрана
func _clear_for(ev, cam_top: float) -> void:
	var top: float = ev.position.y - ev.length - 300.0
	var all_lanes: bool = ev.clear_all_lanes or ev.spawn_policy == "none"
	for e in get_tree().get_nodes_in_group("enemies"):
		var y: float = e.global_position.y
		if y < cam_top - 80.0 and (all_lanes and ev.spawn_policy == "none" or _overlaps(e.global_position.x, 30.0, ev.lanes_blocked)):
			e.queue_free()
	for grp in ["hazards", "pickups", "obstacles"]:
		for n in get_tree().get_nodes_in_group(grp):
			var y: float = n.global_position.y
			if y > cam_top - 30.0 or y < top:
				continue
			var half := 30.0
			if "width" in n:
				half = n.width / 2.0
			if all_lanes or _overlaps(n.global_position.x, half, ev.lanes_blocked):
				n.queue_free()


static func _overlaps(x: float, half: float, lanes: Array) -> bool:
	for lane in lanes:
		var l0: float = Art.ROAD_LEFT + lane * Art.LANE_W
		var l1: float = l0 + Art.LANE_W
		if x + half > l0 and x - half < l1:
			return true
	return false
