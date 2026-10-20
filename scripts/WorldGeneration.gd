extends TileMapLayer

# Размер одного чанка в тайлах
const CHUNK_SIZE: int = 16
# Радиус видимости в чанках вокруг игрока
@export var render_distance: int = 4

# Длина закрашенного штриха желтой линии (в тайлах)
@export var dash_length: int = 5
# Длина пустого промежутка между штрихами (в тайлах)
@export var gap_length: int = 3


# ШИРИНА ОДНОЙ ПОЛОСЫ ДОРОГИ (в тайлах) между линиями разметки
@export var lane_width: int = 11

# Константы для тайлов дороги (укажите свои координаты из TileSet)
# Назначаем индивидуальный ID источника для каждого типа тайла
const SOURCE_ROAD_ID = 0      # Асфальт берем из источника 1
const TILE_ROAD = Vector2i(0, 0) 

const SOURCE_MARKING_ID = 3   # Разметку берем из источника 3
const TILE_MARKING = Vector2i(0, 0)


var player: Node2D = null

# Хранилище сгенерированных чанков
var generated_chunks: Dictionary = {}

func _ready() -> void:
	# Дорога генерируется даже во время паузы (например, во время отсчёта перед стартом),
	# чтобы игрок не видел пустой экран
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Автоматически добавляем игрока в группу через код, если забыли в интерфейсе
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _process(_delta: float) -> void:
	if player == null:
		# Если игрок еще не нашелся, пробуем найти его снова
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		return
		
	# Переводим позицию игрока в координаты чанка
	var player_tile_pos = local_to_map(player.global_position)
	var player_chunk_x = floori(float(player_tile_pos.x) / CHUNK_SIZE)
	var player_chunk_y = floori(float(player_tile_pos.y) / CHUNK_SIZE)
	var current_chunk = Vector2i(player_chunk_x, player_chunk_y)
	
	# Проверяем и генерируем чанки вокруг игрока
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			var chunk_to_generate = current_chunk + Vector2i(x, y)
			
			if not generated_chunks.has(chunk_to_generate):
				generate_chunk(chunk_to_generate)

# Функция генерации бесконечного шоссе
func generate_chunk(chunk_pos: Vector2i) -> void:
	generated_chunks[chunk_pos] = true
	
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	var total_dash_cycle = dash_length + gap_length
	
	for x in range(start_x, start_x + CHUNK_SIZE):
		for y in range(start_y, start_y + CHUNK_SIZE):
			
			# Проверяем линию разметки
			if x % (lane_width + 1) == 0:
				var y_pos_in_cycle = posmod(y, total_dash_cycle)
				
				if y_pos_in_cycle < dash_length:
					# Рисуем разметку: передаем SOURCE_MARKING_ID (3)
					set_cell(Vector2i(x, y), SOURCE_MARKING_ID, TILE_MARKING)
				else:
					# Пропуск разметки (асфальт): передаем SOURCE_ROAD_ID (1)
					set_cell(Vector2i(x, y), SOURCE_ROAD_ID, TILE_ROAD)
			else:
				# Обычные полосы (асфальт): передаем SOURCE_ROAD_ID (1)
				set_cell(Vector2i(x, y), SOURCE_ROAD_ID, TILE_ROAD)
