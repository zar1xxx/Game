extends "res://scripts/events/RoadEvent.gd"
## Омск: разведённый мост через Иртыш.
## Дорога выходит на мост, по сторонам — река. Посреди моста пролёт разведён,
## под ним как раз проходит баржа. Перед разводом на каждой полосе лежит нитро:
## подобрали — машина перелетает пролёт, нет — купание в Иртыше.

const NitroScene := preload("res://scenes/obstacles/NitroPickup.tscn")
const DECK_START := 180.0
const NITRO_AT := 640.0
const GAP_AT := 1480.0           # ближний край развода
const GAP_LEN := 250.0
const DECK_END := 2350.0
const WATER := Color("2f5d86")
const WATER_LIGHT := Color("3c74a6")

var resolved: bool = false
var jumped: bool = false


func _init() -> void:
	kind = "bridge"
	length = DECK_END + 80.0
	spawn_policy = "none"
	clear_all_lanes = true


func start() -> void:
	toast("Мост через Иртыш разведён! Подбери нитро и прыгай", Art.TEAL, 3.0)
	call_deferred("_place_nitro")


func _place_nitro() -> void:
	for row in 2:
		for lane in Art.LANES:
			var n = NitroScene.instantiate()
			n.global_position = Vector2(lane_center(lane) + (row * 2 - 1) * 18.0, wy(NITRO_AT + row * 260.0))
			get_tree().current_scene.add_child(n)


func _update(p, _delta: float) -> void:
	if resolved:
		return
	var front: float = p.global_position.y - p.CAR_LENGTH * 0.45
	if front > wy(GAP_AT):
		return
	resolved = true
	var fast: bool = p.nitro_time_left > 0.0 or p.current_speed >= p.get_cruise_speed() * 1.2
	if fast:
		jumped = true
		var dur := clampf((GAP_LEN + p.CAR_LENGTH + 140.0) / maxf(p.current_speed, 400.0), 0.35, 0.8)
		p.jump(dur)
		add_score(150)
		Missions.event("bridge")
		toast("Прыжок через Иртыш! +150", Art.TEAL, 2.4)
	else:
		p.fall_into_river(wy(GAP_AT + GAP_LEN) - p.CAR_LENGTH * 0.6)
		toast("Буль! Машину выловили из Иртыша: −40% прочности", Art.BLUE, 2.8)


func hud_info(p) -> Dictionary:
	if resolved:
		return {}
	var dist: float = p.global_position.y - wy(GAP_AT)
	if dist > 1500.0:
		return {}
	var has_nitro: bool = p.nitro_time_left > 0.0
	return {"title": "Мост разведён!", "text": "Нитро есть — жми прямо!" if has_nitro else "Подбери нитро, иначе — в Иртыш",
		"color": Art.TEAL if has_nitro else Art.RED, "dist": dist * 0.1}


func get_lights() -> Array:
	var out := []
	var d := DECK_START
	while d < DECK_END:
		out.append([Vector2(Art.ROAD_LEFT - 16, wy(d)), 150.0, 0.8])
		out.append([Vector2(Art.ROAD_RIGHT + 16, wy(d)), 150.0, 0.8])
		d += 330.0
	out.append([Vector2((Art.ROAD_LEFT + Art.ROAD_RIGHT) / 2.0, wy(GAP_AT + GAP_LEN / 2.0)), 260.0, 0.9])
	return out


func _draw() -> void:
	var deck_b := -DECK_START
	var deck_t := -DECK_END
	var gap_b := -GAP_AT
	var gap_t := -(GAP_AT + GAP_LEN)
	var L := Art.ROAD_LEFT
	var R := Art.ROAD_RIGHT
	# Река по обе стороны (вместо кварталов и тротуаров)
	for rect in [Rect2(-600, deck_t - 80, L - 6 + 600, deck_b - deck_t + 160),
			Rect2(R + 6, deck_t - 80, 1400, deck_b - deck_t + 160)]:
		draw_rect(rect, WATER)
	var wy0 := floorf(deck_t / 60.0) * 60.0
	var k := 0
	while wy0 < deck_b + 80:
		var off := sin(_t * 1.2 + k) * 14.0
		var xs := [-120.0 + Art.hash01(k) * 300, R + 60 + Art.hash01(k + 50) * 260]
		for x in xs:
			draw_line(Vector2(x + off, wy0), Vector2(x + off + 46, wy0), Color(WATER_LIGHT, 0.7), 3.0)
		wy0 += 60.0
		k += 1
	Art.text_center(self, Vector2(L - 120, deck_b - 260), "р. Иртыш", 22, Color(1, 1, 1, 0.35), true)
	# Берега у въезда и съезда
	draw_rect(Rect2(-600, deck_b, 600 + L, 90), Art.pal("sidewalk").darkened(0.15))
	draw_rect(Rect2(R, deck_b, 1400, 90), Art.pal("sidewalk").darkened(0.15))
	draw_rect(Rect2(-600, deck_t - 90, 600 + L, 90), Art.pal("sidewalk").darkened(0.15))
	draw_rect(Rect2(R, deck_t - 90, 1400, 90), Art.pal("sidewalk").darkened(0.15))
	# Пешеходные дорожки моста с перилами
	for side in [-1.0, 1.0]:
		var x0: float = L - 34 if side < 0 else R + 6
		draw_rect(Rect2(x0, deck_t, 28, deck_b - deck_t), Color("8a8fa0"))
		var rail_x: float = x0 + (2.0 if side < 0 else 24.0)
		draw_rect(Rect2(rail_x, deck_t, 4, deck_b - deck_t), Color("c9cdd6"))
		var py := deck_t
		while py < deck_b:
			draw_rect(Rect2(rail_x - 2, py, 8, 6), Color("6d7182"))
			py += 40.0
		var lamp := deck_b - 30.0
		while lamp > deck_t:
			draw_circle(Vector2(rail_x + 2, lamp), 6, Color("3a3f52"))
			draw_circle(Vector2(rail_x + 2, lamp), 3, Art.HEADLIGHT)
			lamp -= 330.0
	# Шевроны и надпись перед разводом
	var cx := (L + R) / 2.0
	for i in 4:
		var cy := gap_b + 120 + i * 60
		for lane in Art.LANES:
			var lx := lane_center(lane)
			draw_polyline(PackedVector2Array([Vector2(lx - 20, cy + 10), Vector2(lx, cy - 8), Vector2(lx + 20, cy + 10)]),
				Color(Art.YELLOW, 0.8), 6.0, true)
	for lane in Art.LANES:
		Art.text_center(self, Vector2(lane_center(lane), -NITRO_AT - 130), "НИТРО", 22, Color(Art.TEAL, 0.55), true)
	# Сам развод: вода и задранные края пролётов
	draw_rect(Rect2(L - 34, gap_t, R - L + 68, GAP_LEN), WATER)
	var wl := gap_t + 30.0
	while wl < gap_b - 20:
		draw_line(Vector2(L + sin(_t + wl) * 20, wl), Vector2(R - 200 + sin(_t + wl) * 20, wl), Color(WATER_LIGHT, 0.6), 3.0)
		wl += 46.0
	# Баржа проходит под мостом
	var barge_x := fmod(_t * 90.0, 1800.0) - 500.0
	var by := (gap_t + gap_b) / 2.0
	Art.rrect(self, Rect2(barge_x + 8, by - 40 + 10, 300, 80), Color(0, 0, 0, 0.25), 30)
	Art.rrect(self, Rect2(barge_x, by - 40, 300, 80), Color("7a3b2e"), 30, 3, Art.INK)
	for c in 3:
		Art.rrect(self, Rect2(barge_x + 40 + c * 72, by - 26, 62, 52), [Art.BLUE, Art.ORANGE, Art.GREEN][c], 4, 2, Art.INK)
	Art.rrect(self, Rect2(barge_x + 260, by - 22, 30, 44), Art.LINE_WHITE, 6, 2, Art.INK)
	# Края пролётов (подняты: светлые, с «зеброй»)
	for edge in [[gap_b - 26, gap_b], [gap_t, gap_t + 26]]:
		draw_rect(Rect2(L - 34, edge[0], R - L + 68, edge[1] - edge[0]), Color("b9bdca"))
		var sx := L - 34.0
		var s := 0
		while sx < R + 34:
			if s % 2 == 0:
				draw_rect(Rect2(sx, edge[0] + 6, 30, 14), Art.YELLOW)
			else:
				draw_rect(Rect2(sx, edge[0] + 6, 30, 14), Art.INK)
			sx += 30.0
			s += 1
	# Тень приподнятого края на воде
	draw_rect(Rect2(L - 34, gap_t + 26, R - L + 68, 24), Color(0, 0, 0, 0.22))
	# Табличка «Разводной мост» перед въездом
	draw_plate(Rect2(R + 4, -40, 46, 40), Art.BLUE, "РАЗВОД\nМОСТА", Art.LINE_WHITE, 8)
