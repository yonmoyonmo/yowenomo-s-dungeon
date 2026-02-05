extends Control

const DungeonGeneratorModule = preload("res://scripts/dungeon_generator.gd")
const MiniMapRendererModule = preload("res://scripts/minimap.gd")
const FPViewControllerModule = preload("res://scripts/fp_view.gd")
const TEX_TOP = preload("res://art/top.png")
const TEX_BOTTOM = preload("res://art/bottom.png")
const TEX_CENTER = preload("res://art/center.png")
const TEX_LEFT = preload("res://art/left.png")
const TEX_RIGHT = preload("res://art/right.png")

# =========================
# HUD / Player references
# =========================
@onready var turn_label: Label = $HUD/TurnLabel
@onready var log_label: Label = $HUD/LogLabel
@onready var dir_label: Label = $HUD/DirLabel
@onready var player = $World/Player
@onready var hud = $HUD

# =========================
# FPView (Depth 3) TextureRects
# =========================
@onready var fp_nt: TextureRect = $HUD/FPView/Near/Top
@onready var fp_nb: TextureRect = $HUD/FPView/Near/Bottom
@onready var fp_nc: TextureRect = $HUD/FPView/Near/Center
@onready var fp_nl: TextureRect = $HUD/FPView/Near/Left
@onready var fp_nr: TextureRect = $HUD/FPView/Near/Right

@onready var fp_mt: TextureRect = $HUD/FPView/Mid/Top
@onready var fp_mb: TextureRect = $HUD/FPView/Mid/Bottom
@onready var fp_mc: TextureRect = $HUD/FPView/Mid/Center
@onready var fp_ml: TextureRect = $HUD/FPView/Mid/Left
@onready var fp_mr: TextureRect = $HUD/FPView/Mid/Right

@onready var fp_ft: TextureRect = $HUD/FPView/Far/Top
@onready var fp_fb: TextureRect = $HUD/FPView/Far/Bottom
@onready var fp_fc: TextureRect = $HUD/FPView/Far/Center
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
		[fp_nc, fp_mc, fp_fc],
		[fp_nl, fp_ml, fp_fl],
		[fp_nr, fp_mr, fp_fr],
		[fp_nt, fp_mt, fp_ft],
		[fp_nb, fp_mb, fp_fb],
		{
			"top": TEX_TOP,
			"bottom": TEX_BOTTOM,
			"center": TEX_CENTER,
			"left": TEX_LEFT,
			"right": TEX_RIGHT
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
	log_label.text = ""

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
