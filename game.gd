extends Control

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
@onready var fp_fc: TextureRect = $HUD/FPView/Far/Ceiling
@onready var fp_fo: TextureRect = $HUD/FPView/Far/Floor

@onready var fp_f2f: TextureRect = $HUD/FPView/Far2/Front
@onready var fp_f2l: TextureRect = $HUD/FPView/Far2/Left
@onready var fp_f2r: TextureRect = $HUD/FPView/Far2/Right
@onready var fp_f2c: TextureRect = $HUD/FPView/Far2/Ceiling
@onready var fp_f2o: TextureRect = $HUD/FPView/Far2/Floor

@onready var fp_f3f: TextureRect = $HUD/FPView/Far3/Front
@onready var fp_f3l: TextureRect = $HUD/FPView/Far3/Left
@onready var fp_f3r: TextureRect = $HUD/FPView/Far3/Right
@onready var fp_f3c: TextureRect = $HUD/FPView/Far3/Ceiling
@onready var fp_f3o: TextureRect = $HUD/FPView/Far3/Floor

@onready var fp_mc: TextureRect = $HUD/FPView/Mid/Ceiling
@onready var fp_mo: TextureRect = $HUD/FPView/Mid/Floor

@onready var fp_nc: TextureRect = $HUD/FPView/Near/Ceiling
@onready var fp_no: TextureRect = $HUD/FPView/Near/Floor

# =========================
# Procedural map params
# =========================
@export var map_w := 31
@export var map_h := 31
@export var room_attempts := 20
@export var room_min := 3
@export var room_max := 7

# dungeon[y][x] : 1 wall, 0 floor
var dungeon: Array = []
var room_centers: Array = []
var start_cell := Vector2i.ZERO
var end_cell := Vector2i.ZERO

var turn := 0


# =========================
# Lifecycle
# =========================
func _ready():
	randomize()
	_generate_dungeon()
	_assign_start_end()
	_build_minimap()
	
	# spawn on floor
	player.cell = start_cell
	player.position = Vector2(player.cell) * player.tile_size

	turn_label.text = "TURN: %d" % turn
	log_label.text = "ready"
	_update_dir_label()

	player.acted.connect(_on_player_acted)
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
	log_label.text = action_text
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
	return dungeon[cell.y][cell.x] == 1

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
func _clear_fp():
	fp_nf.visible = false
	fp_nl.visible = false
	fp_nr.visible = false
	fp_nc.visible = false
	fp_no.visible = false

	fp_mf.visible = false
	fp_ml.visible = false
	fp_mr.visible = false
	fp_mc.visible = false
	fp_mo.visible = false

	fp_ff.visible = false
	fp_fl.visible = false
	fp_fr.visible = false
	fp_fc.visible = false
	fp_fo.visible = false

	fp_f2f.visible = false
	fp_f2l.visible = false
	fp_f2r.visible = false
	fp_f2c.visible = false
	fp_f2o.visible = false

	fp_f3f.visible = false
	fp_f3l.visible = false
	fp_f3r.visible = false
	fp_f3c.visible = false
	fp_f3o.visible = false

func _update_fp_depth3():
	_clear_fp()

	for d in [1, 2, 3, 4, 5]:
		var f: Vector2i = player.cell + (_front_vec() * d)

		# front wall blocks further view
		if is_wall(f):
			_set_front(d, true)
			break

		_set_ceiling(d, true)
		_set_floor(d, true)

		# side walls at this depth
		var l: Vector2i = f + _left_vec()
		var r: Vector2i = f + _right_vec()
		_set_left(d, is_wall(l))
		_set_right(d, is_wall(r))

func _set_front(d: int, on: bool):
	match d:
		1: fp_nf.visible = on
		2: fp_mf.visible = on
		3: fp_ff.visible = on
		4: fp_f2f.visible = on
		5: fp_f3f.visible = on

func _set_left(d: int, on: bool):
	match d:
		1: fp_nl.visible = on
		2: fp_ml.visible = on
		3: fp_fl.visible = on
		4: fp_f2l.visible = on
		5: fp_f3l.visible = on

func _set_right(d: int, on: bool):
	match d:
		1: fp_nr.visible = on
		2: fp_mr.visible = on
		3: fp_fr.visible = on
		4: fp_f2r.visible = on
		5: fp_f3r.visible = on

func _set_ceiling(d: int, on: bool):
	match d:
		1: fp_nc.visible = on
		2: fp_mc.visible = on
		3: fp_fc.visible = on
		4: fp_f2c.visible = on
		5: fp_f3c.visible = on

func _set_floor(d: int, on: bool):
	match d:
		1: fp_no.visible = on
		2: fp_mo.visible = on
		3: fp_fo.visible = on
		4: fp_f2o.visible = on
		5: fp_f3o.visible = on

# =========================
# Procedural generation
# =========================
func _generate_dungeon():
	# keep odd sizes for nicer corridors
	if map_w % 2 == 0:
		map_w += 1
	if map_h % 2 == 0:
		map_h += 1

	# 1) fill with walls
	dungeon = []
	for y in range(map_h):
		var row := []
		row.resize(map_w)
		for x in range(map_w):
			row[x] = 1
		dungeon.append(row)

	# 2) border walls
	for x in range(map_w):
		dungeon[0][x] = 1
		dungeon[map_h - 1][x] = 1
	for y in range(map_h):
		dungeon[y][0] = 1
		dungeon[y][map_w - 1] = 1

	# 3) rooms + corridors
	var rooms: Array = []
	room_centers = []
	for i in range(room_attempts):
		var w := randi_range(room_min, room_max)
		var h := randi_range(room_min, room_max)

		# clamp to map
		w = clamp(w, 3, map_w - 2)
		h = clamp(h, 3, map_h - 2)

		var x := randi_range(1, map_w - w - 2)
		var y := randi_range(1, map_h - h - 2)
		var rect := Rect2i(x, y, w, h)

		# avoid overlap (grow by 1 for spacing)
		var overlapped := false
		for r in rooms:
			if rect.grow(1).intersects(r):
				overlapped = true
				break
		if overlapped:
			continue

		_carve_room(rect)
		rooms.append(rect)
		room_centers.append(_rect_center(rect))

		# connect to previous room
		if rooms.size() >= 2:
			var prev: Rect2i = rooms[rooms.size() - 2]
			var a := _rect_center(prev)
			var b := _rect_center(rect)
			_carve_corridor(a, b)

func _carve_room(rect: Rect2i):
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			dungeon[y][x] = 0

func _rect_center(rect: Rect2i) -> Vector2i:
	return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)

func _carve_corridor(a: Vector2i, b: Vector2i):
	# L shaped corridor
	if randi() % 2 == 0:
		_carve_h(a.x, b.x, a.y)
		_carve_v(a.y, b.y, b.x)
	else:
		_carve_v(a.y, b.y, a.x)
		_carve_h(a.x, b.x, b.y)

func _carve_h(x1: int, x2: int, y: int):
	var from: int = mini(x1, x2)
	var to: int = maxi(x1, x2)
	for x in range(from, to + 1):
		dungeon[y][x] = 0

func _carve_v(y1: int, y2: int, x: int):
	var from: int = min(y1, y2)
	var to : int = max(y1, y2)
	for y in range(from, to + 1):
		dungeon[y][x] = 0

func _find_spawn_cell() -> Vector2i:
	# find random floor cell
	for attempt in range(4000):
		var x := randi_range(1, map_w - 2)
		var y := randi_range(1, map_h - 2)
		if dungeon[y][x] == 0:
			return Vector2i(x, y)
	# fallback
	return Vector2i(map_w / 2, map_h / 2)

func _assign_start_end():
	if room_centers.is_empty():
		start_cell = _find_spawn_cell()
		end_cell = start_cell
		return
	start_cell = room_centers[0]
	end_cell = _pick_farthest_cell(room_centers, start_cell)

func _pick_farthest_cell(centers: Array, start: Vector2i) -> Vector2i:
	var best: Vector2i = start
	var best_d := -1
	for c in centers:
		var d = abs(c.x - start.x) + abs(c.y - start.y)
		if d > best_d:
			best_d = d
			best = c
	return best

func _build_minimap():
	var w = map_w
	var h = map_h
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK) # 기본 배경

	for y in range(h):
		for x in range(w):
			if dungeon[y][x] == 1:
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1)) # 벽
			else:
				img.set_pixel(x, y, Color(0.9, 0.9, 0.9)) # 바닥
	
	if start_cell != Vector2i.ZERO or end_cell != Vector2i.ZERO:
		img.set_pixel(start_cell.x, start_cell.y, Color(0.2, 0.5, 1.0)) # 시작
		img.set_pixel(end_cell.x, end_cell.y, Color(1.0, 0.2, 0.2)) # 끝

	img.set_pixel(player.cell.x, player.cell.y, Color(0.0, 0.681, 0.203, 1.0)) # 플레이어

	var tex := ImageTexture.create_from_image(img)
	$HUD/MiniMap.texture = tex
