extends Control

const DungeonGeneratorModule = preload("res://scripts/dungeon_generator.gd")
const MiniMapRendererModule = preload("res://scripts/minimap.gd")
const FPViewControllerModule = preload("res://scripts/fp_view.gd")
const TEX_SIDE = preload("res://art/side.png")
const TEX_OUTER_L = preload("res://art/outer_corner_L.png")
const TEX_OUTER_R = preload("res://art/outer_corner_R.png")
const TEX_INNER_L = preload("res://art/inner_corner_L.png")
const TEX_INNER_R = preload("res://art/inner_corner_R.png")

# =========================
# HUD / Player references
# =========================
@onready var turn_label: Label = $HUD/TurnLabel
@onready var log_label: Label = $HUD/LogLabel
@onready var dir_label: Label = $HUD/DirLabel
@onready var player = $World/Player
@onready var hud = $HUD

# =========================
# FPView (Depth 3) ColorRects
# =========================
@onready var fp_nf: TextureRect = $HUD/FPView/Near/Front
@onready var fp_nl: TextureRect = $HUD/FPView/Near/Left
@onready var fp_nr: TextureRect = $HUD/FPView/Near/Right

@onready var fp_mf: TextureRect = $HUD/FPView/Mid/Front
@onready var fp_ml: TextureRect = $HUD/FPView/Mid/Left
@onready var fp_mr: TextureRect = $HUD/FPView/Mid/Right

@onready var fp_ff: TextureRect = $HUD/FPView/Far/Front
@onready var fp_fl: TextureRect = $HUD/FPView/Far/Left
@onready var fp_fr: TextureRect = $HUD/FPView/Far/Right

# =========================
# Procedural map params
# =========================
@export var map_w := 21
@export var map_h := 21
@export var seed_value := Time.get_unix_time_from_system()
@export var corridor_density := 0.7

# dungeon[y][x] : 1 wall, 0 floor
var dungeon: Array = []
var start_cell := Vector2i.ZERO
var end_cell := Vector2i.ZERO

var turn := 0
var dungeon_gen: DungeonGenerator
var minimap_renderer: MiniMapRenderer
var fp_view: FPViewController


# =========================
# Lifecycle
# =========================
func _ready():
	dungeon_gen = DungeonGeneratorModule.new()
	print("Dungeon seed:", seed_value)
	var result = dungeon_gen.generate(map_w, map_h, seed_value, corridor_density)
	dungeon = result["grid"]
	map_h = dungeon.size()
	if map_h > 0:
		map_w = dungeon[0].size()
	start_cell = result["start"]
	end_cell = result["exit"]

	minimap_renderer = MiniMapRendererModule.new()
	fp_view = FPViewControllerModule.new(
		[fp_nf, fp_mf, fp_ff],
		[fp_nl, fp_ml, fp_fl],
		[fp_nr, fp_mr, fp_fr],
		{
			"side_continue": TEX_SIDE,
			"side_end": TEX_SIDE,
			"outer_left": TEX_OUTER_L,
			"outer_right": TEX_OUTER_R,
			"inner_left": TEX_INNER_L,
			"inner_right": TEX_INNER_R
		}
	)
	_build_minimap()
	
	# spawn on floor
	player.cell = start_cell
	player.position = Vector2(player.cell) * player.tile_size

	turn_label.text = "TURN: %d" % turn
	log_label.text = "ready"
	_update_dir_label()

	if not player.acted.is_connected(_on_player_acted):
		player.acted.connect(_on_player_acted)
	if not player.try_move.is_connected(_on_player_try_move):
		player.try_move.connect(_on_player_try_move)
	if hud.has_signal("action_requested"):
		hud.action_requested.connect(_on_hud_action)

	_update_fp_depth3()

# =========================
# Player interaction
# =========================
func _on_player_try_move(next: Vector2i, action_text: String):
	if is_wall(next):
		player.emit_signal("acted", "bumped into wall")
	else:
		player.cell = next
		player.position = Vector2(next) * player.tile_size
		player.emit_signal("acted", action_text)

func _on_hud_action(action: String):
	if not player.can_act:
		return
	match action:
		"turn_left":
			player.act_turn(-1)
		"turn_right":
			player.act_turn(1)
		"forward":
			player.act_move_to(player.front_cell(), "forward")
		"back":
			player.act_move_to(player.back_cell(), "back")
		"left":
			player.act_move_to(player.left_cell(), "left")
		"right":
			player.act_move_to(player.right_cell(), "right")

func _on_player_acted(action_text: String):
	turn += 1
	turn_label.text = "TURN: %d" % turn
	_update_dir_label()
	_update_fp_depth3()
	_build_minimap()

func _update_dir_label():
	dir_label.text = "DIR: " + player.get_dir_name()

# =========================
# Dungeon query
# =========================
func is_wall(cell: Vector2i) -> bool:
	if dungeon.is_empty():
		return true
	# out of bounds = wall
	if cell.y < 0 or cell.y >= dungeon.size():
		return true
	if cell.x < 0 or cell.x >= dungeon[cell.y].size():
		return true
	return dungeon[cell.y][cell.x] == 0

# =========================
# Direction vectors (based on player.dir)
# =========================
func _front_vec() -> Vector2i:
	match player.dir:
		0: return Vector2i(0, -1) # N
		1: return Vector2i(1, 0)  # E
		2: return Vector2i(0, 1)  # S
		_: return Vector2i(-1, 0) # W

func _left_vec() -> Vector2i:
	match player.dir:
		0: return Vector2i(-1, 0)
		1: return Vector2i(0, -1)
		2: return Vector2i(1, 0)
		_: return Vector2i(0, 1)

func _right_vec() -> Vector2i:
	match player.dir:
		0: return Vector2i(1, 0)
		1: return Vector2i(0, 1)
		2: return Vector2i(-1, 0)
		_: return Vector2i(0, -1)

# =========================
# FPView rendering (Depth 3)
# =========================
func _update_fp_depth3():
	fp_view.update_depth(
		player.cell,
		_front_vec(),
		_left_vec(),
		_right_vec(),
		Callable(self, "is_wall")
	)
	log_label.text = _build_corner_debug()

func _build_corner_debug() -> String:
	var f = player.cell + _front_vec()
	var l = f + _left_vec()
	var r = f + _right_vec()
	var fl = l + _front_vec()
	var fr = r + _front_vec()

	var f_wall: bool = is_wall(f)
	var l_wall: bool = is_wall(l)
	var r_wall: bool = is_wall(r)
	var fl_wall: bool = is_wall(fl)
	var fr_wall: bool = is_wall(fr)

	var l_type := _side_type(f_wall, l_wall, fl_wall)
	var r_type := _side_type(f_wall, r_wall, fr_wall)
	return "F=%s L=%s R=%s | L:%s R:%s" % [
		"W" if f_wall else "O",
		"W" if l_wall else "O",
		"W" if r_wall else "O",
		l_type,
		r_type
	]

func _side_type(f_wall: bool, side_wall: bool, diag_wall: bool) -> String:
	if side_wall and not f_wall and diag_wall:
		return "outer_corner"
	if (not side_wall) and f_wall and diag_wall:
		return "inner_corner"
	if side_wall and diag_wall:
		return "side_continue"
	if side_wall and (not diag_wall):
		return "side_end"
	return "empty"

func _build_minimap():
	var tex := minimap_renderer.build_minimap(
		dungeon,
		map_w,
		map_h,
		start_cell,
		end_cell,
		player.cell
	)
	$HUD/MiniMap.texture = tex
