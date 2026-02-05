# dungeon.gd
extends Control

const DungeonGeneratorModule = preload("res://scripts/dungeon_generator_game2.gd")
const MiniMapRendererModule = preload("res://scripts/minimap.gd")

@onready var player: Node = $World/Player
@onready var hud: Control = $HUD
@onready var ray_view: Control = $HUD/RaycastView
@onready var turn_label: Label = $HUD/TurnLabel
@onready var log_label: Label = $HUD/LogLabel
@onready var dir_label: Label = $HUD/DirLabel

@export var map_w := 21
@export var map_h := 21
@export var seed_value := Time.get_unix_time_from_system()
@export var corridor_density := 0.7

var dungeon_gen: DungeonGeneratorGame2
var minimap_renderer: MiniMapRenderer
var dungeon: Array = []
var tile_size := 64.0
var start_cell := Vector2i.ZERO
var end_cell := Vector2i.ZERO
var turn := 0

func _ready() -> void:
	# 1) 던전 생성 (현재 프로젝트 API에 맞춤)
	dungeon_gen = DungeonGeneratorModule.new()
	var result := dungeon_gen.generate(map_w, map_h, seed_value, corridor_density)
	dungeon = result["grid"]
	map_h = dungeon.size()
	if map_h > 0:
		map_w = dungeon[0].size()
	start_cell = result["start"]
	end_cell = result["exit"]

	minimap_renderer = MiniMapRendererModule.new()

	# 2) 플레이어 스폰
	player.cell = start_cell
	player.dir = 0
	tile_size = player.tile_size
	player.position = Vector2(player.cell) * tile_size

	# 3) 시그널 연결
	# (형님 기존 흐름: hud.action_requested -> 게임컨트롤러가 처리)
	hud.action_requested.connect(_on_action_requested)
	player.acted.connect(_on_player_acted)
	player.try_move.connect(_on_player_try_move)

	# 첫 화면 그리기
	_update_dir_label()
	turn_label.text = "TURN: %d" % turn
	log_label.text = "ready"
	_update_view()

func _on_action_requested(action: String) -> void:
	match action:
		"turn_left":
			player.act_turn(-1)
			log_label.text = "turn left"
		"turn_right":
			player.act_turn(1)
			log_label.text = "turn right"
		"forward":
			player.act_move_to(player.front_cell(), "forward")
			log_label.text = "forward"
		"back":
			player.act_move_to(player.back_cell(), "back")
			log_label.text = "back"
		"left":
			player.act_move_to(player.left_cell(), "left")
			log_label.text = "left"
		"right":
			player.act_move_to(player.right_cell(), "right")
			log_label.text = "right"
		_:
			pass

func _on_player_try_move(next_cell: Vector2i, action_text: String) -> void:
	if _is_wall(next_cell):
		# 벽이면 이동 불가(기존 로직처럼 HUD에 로그 띄우고 싶으면 여기서)
		player.emit_signal("acted", "bumped into wall")
		return

	player.cell = next_cell
	player.position = Vector2(player.cell) * tile_size
	player.emit_signal("acted", action_text)

func _on_player_acted(_action_text: String) -> void:
	turn += 1
	turn_label.text = "TURN: %d" % turn
	log_label.text = _action_text
	_update_dir_label()
	_update_view()

func _update_view() -> void:
	_update_minimap()
	$HUD/RaycastView.set_state(dungeon, tile_size, player.cell, player.dir)

func _update_dir_label() -> void:
	dir_label.text = "DIR: " + player.get_dir_name()

func _update_minimap() -> void:
	var tex := minimap_renderer.build_minimap(
		dungeon,
		map_w,
		map_h,
		start_cell,
		end_cell,
		player.cell
	)
	$HUD/MiniMap.texture = tex

func _is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= dungeon.size():
		return true
	var row = dungeon[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return true
	return int(row[cell.x]) == 0 # WALL=0
