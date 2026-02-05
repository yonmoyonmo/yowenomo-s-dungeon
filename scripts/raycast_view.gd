# raycast_view.gd
extends Control

# 게임에서 주입할 값들
var dungeon: Array = []          # 2D array, WALL=0, FLOOR=1
var tile_size: float = 64.0

var player_cell: Vector2i = Vector2i(1, 1)
var player_dir: int = 0          # 0:N,1:E,2:S,3:W

# 렌더 파라미터
@export var fov_deg: float = 70.0
@export var rays: int = 240
@export var max_steps: int = 64
@export var wall_texture: Texture2D
@export var enable_smoothing: bool = true

const SMOOTH_TIME: float = 0.12

var _anim_t: float = 1.0
var _prev_pos: Vector2 = Vector2.ZERO
var _prev_ang: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _target_ang: float = 0.0

func set_state(_dungeon: Array, _tile_size: float, _cell: Vector2i, _dir: int) -> void:
	dungeon = _dungeon
	tile_size = _tile_size
	player_cell = _cell
	player_dir = _dir

	var new_pos: Vector2 = Vector2(player_cell) + Vector2(0.5, 0.5)
	var new_ang: float = _dir_to_angle(player_dir)

	if not enable_smoothing:
		_prev_pos = new_pos
		_prev_ang = new_ang
		_target_pos = new_pos
		_target_ang = new_ang
		_anim_t = 1.0
		queue_redraw()
		return

	if _anim_t >= 1.0:
		_prev_pos = new_pos
		_prev_ang = new_ang
	else:
		_prev_pos = _get_interp_pos()
		_prev_ang = _get_interp_ang()

	_target_pos = new_pos
	_target_ang = new_ang
	_anim_t = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not enable_smoothing:
		return
	if _anim_t >= 1.0:
		return
	_anim_t = min(1.0, _anim_t + delta / SMOOTH_TIME)
	queue_redraw()

func _draw() -> void:
	if dungeon.is_empty():
		return

	var w: float = size.x
	var h: float = size.y

	# 간단 천장/바닥
	draw_rect(Rect2(Vector2(0, 0), Vector2(w, h * 0.5)), Color(0.08, 0.08, 0.10))
	draw_rect(Rect2(Vector2(0, h * 0.5), Vector2(w, h * 0.5)), Color(0.05, 0.05, 0.06))

	var fov: float = deg_to_rad(fov_deg)
	var plane: float = (w * 0.5) / tan(fov * 0.5)

	var base_ang: float = _get_interp_ang()
	var ppos: Vector2 = _get_interp_pos()

	var line_w: float = (w / float(rays)) + 1.0

	var tex: Texture2D = wall_texture
	var tex_w: float = 1.0
	var tex_h: float = 1.0
	if tex:
		var sz: Vector2 = tex.get_size()
		tex_w = max(1.0, sz.x)
		tex_h = max(1.0, sz.y)

	for i in rays:
		var t: float = (float(i) / float(rays - 1)) * 2.0 - 1.0
		var ray_ang: float = base_ang + t * (fov * 0.5)
		var ray_dir: Vector2 = Vector2(cos(ray_ang), sin(ray_ang))

		var hit: Dictionary = _cast_dda(ppos, ray_dir)
		var dist: float = float(hit.get("dist", 1.0))
		var side: int = int(hit.get("side", 0))
		var hit_cell: Vector2i = hit.get("cell", Vector2i.ZERO)
		var hit_x: float = float(hit.get("hit_x", 0.0))

		# 피쉬아이 보정(중요)
		var dist_corr: float = dist * cos(ray_ang - base_ang)
		dist_corr = max(0.001, dist_corr)

		var wall_h: float = (1.0 / dist_corr) * plane
		var max_wall_h: float = h * 1.2
		if wall_h > max_wall_h:
			wall_h = max_wall_h

		var x: float = (float(i) / float(rays)) * w
		x = floor(x)

		var y1: float = h * 0.5 - wall_h * 0.5
		var y2: float = h * 0.5 + wall_h * 0.5

		# 거리 음영 + 사이드 음영 + 셀 변조
		var shade: float = clamp(1.2 - dist_corr * 0.12, 0.15, 1.0)
		if side == 1:
			shade *= 0.75
		shade *= _cell_brightness(hit_cell)
		var col: Color = Color(shade, shade, shade)

		if tex:
			var tx: float = clamp(hit_x, 0.0, 0.999) * tex_w
			var src: Rect2 = Rect2(Vector2(tx, 0.0), Vector2(1.0, tex_h))
			var dst: Rect2 = Rect2(Vector2(x, y1), Vector2(line_w, y2 - y1))
			draw_texture_rect_region(tex, dst, src, col)
		else:
			draw_line(Vector2(x, y1), Vector2(x, y2), col, line_w)

func _dir_to_angle(d: int) -> float:
	# Godot 좌표: +x 오른쪽, +y 아래
	# N(0,-1) = -PI/2, E(1,0)=0, S(0,1)=PI/2, W(-1,0)=PI
	match d & 3:
		0: return -PI * 0.5
		1: return 0.0
		2: return PI * 0.5
		_: return PI

func _is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= dungeon.size():
		return true
	var row: PackedInt32Array = dungeon[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return true
	return int(row[cell.x]) == 0  # WALL=0

func _cast_dda(pos_g: Vector2, dir_g: Vector2) -> Dictionary:
	# DDA in grid-space (tile_size가 아니라 "타일 1칸=1" 단위)
	var map_x: int = int(floor(pos_g.x))
	var map_y: int = int(floor(pos_g.y))

	var ray_dx: float = dir_g.x
	var ray_dy: float = dir_g.y

	var delta_x: float = (abs(1.0 / ray_dx) if ray_dx != 0.0 else 1e30)
	var delta_y: float = (abs(1.0 / ray_dy) if ray_dy != 0.0 else 1e30)

	var step_x: int = -1 if ray_dx < 0.0 else 1
	var step_y: int = -1 if ray_dy < 0.0 else 1

	var side_x: float
	var side_y: float

	if ray_dx < 0.0:
		side_x = (pos_g.x - float(map_x)) * delta_x
	else:
		side_x = (float(map_x) + 1.0 - pos_g.x) * delta_x

	if ray_dy < 0.0:
		side_y = (pos_g.y - float(map_y)) * delta_y
	else:
		side_y = (float(map_y) + 1.0 - pos_g.y) * delta_y

	var side: int = 0 # 0=x hit, 1=y hit

	for _i in max_steps:
		if side_x < side_y:
			side_x += delta_x
			map_x += step_x
			side = 0
		else:
			side_y += delta_y
			map_y += step_y
			side = 1

		var c: Vector2i = Vector2i(map_x, map_y)
		if _is_wall(c):
			# 벽까지의 "perp distance" (grid-space)
			var dist: float
			var hit_x: float
			if side == 0:
				dist = (float(map_x) - pos_g.x + (1.0 - float(step_x)) * 0.5) / ray_dx
				var hit_y: float = pos_g.y + dist * ray_dy
				hit_x = hit_y - floor(hit_y)
			else:
				dist = (float(map_y) - pos_g.y + (1.0 - float(step_y)) * 0.5) / ray_dy
				var hit_xf: float = pos_g.x + dist * ray_dx
				hit_x = hit_xf - floor(hit_xf)
			dist = abs(dist)
			dist = max(0.001, dist)
			return {"dist": dist, "side": side, "cell": c, "hit_x": hit_x}

	return {"dist": float(max_steps), "side": side, "cell": Vector2i(map_x, map_y), "hit_x": 0.0}

func _cell_brightness(cell: Vector2i) -> float:
	var hx: int = int(cell.x) * 374761393
	var hy: int = int(cell.y) * 668265263
	var h: int = hx ^ hy
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var t: float = float(h & 0xFFFF) / 65535.0
	return lerp(0.90, 1.05, t)

func _get_interp_pos() -> Vector2:
	if not enable_smoothing:
		return Vector2(player_cell) + Vector2(0.5, 0.5)
	var t: float = _ease(_anim_t)
	return _prev_pos.lerp(_target_pos, t)

func _get_interp_ang() -> float:
	if not enable_smoothing:
		return _dir_to_angle(player_dir)
	var t: float = _ease(_anim_t)
	var diff: float = wrapf(_target_ang - _prev_ang, -PI, PI)
	return _prev_ang + diff * t

func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
