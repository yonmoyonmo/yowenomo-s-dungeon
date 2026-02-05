# raycast_view.gd
# 레이캐스트 기반 1인칭 렌더러
# - 벽 텍스처 스트립 렌더링
# - 몬스터 스프라이트(빌보드) 렌더링
# - 시각적 스무딩(이동/회전 보간)
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
@export var monster_texture: Texture2D
@export var sprite_scale: float = 1.0
@export var max_sprite_height_ratio: float = 0.9
@export var min_sprite_height: float = 8.0
@export var max_sprite_distance: float = 30.0

@export var move_smooth_time: float = 0.16
@export var turn_smooth_time: float = 0.45

var _anim_t: float = 1.0
var _anim_duration: float = 0.16
var _has_pending: bool = false
var _pending_pos: Vector2 = Vector2.ZERO
var _pending_ang: float = 0.0
var _anim_tween: Tween
var _prev_pos: Vector2 = Vector2.ZERO
var _prev_ang: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _target_ang: float = 0.0
var monster_list: Array = []

func set_state(_dungeon: Array, _tile_size: float, _cell: Vector2i, _dir: int, _monsters: Array = []) -> void:
	# 외부에서 상태를 주입받아 렌더링 트리거
	dungeon = _dungeon
	tile_size = _tile_size
	player_cell = _cell
	player_dir = _dir
	monster_list = _monsters

	var new_pos: Vector2 = Vector2(player_cell) + Vector2(0.5, 0.5)
	var new_ang: float = _dir_to_angle(player_dir)

	# 동일 타깃이면 애니메이션 리셋하지 않음
	if new_pos == _target_pos and new_ang == _target_ang:
		queue_redraw()
		return

	var turn_only: bool = (new_pos == _target_pos and new_ang != _target_ang)
	# 애니 중이면 최신 타깃을 대기열에 저장
	if _anim_t < 1.0:
		_pending_pos = new_pos
		_pending_ang = new_ang
		_has_pending = true
		queue_redraw()
		return

	if not enable_smoothing:
		_prev_pos = new_pos
		_prev_ang = new_ang
		_target_pos = new_pos
		_target_ang = new_ang
		_anim_t = 1.0
		if _anim_tween:
			_anim_tween.kill()
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
	_anim_duration = turn_smooth_time if turn_only else move_smooth_time
	_anim_t = 0.0
	_start_anim_tween()
	queue_redraw()

func _process(_delta: float) -> void:
	# Tween 진행 중에는 지속적으로 다시 그리기
	if enable_smoothing and _anim_t < 1.0:
		queue_redraw()

func _draw() -> void:
	# 메인 렌더링
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

	var zbuf: PackedFloat32Array = PackedFloat32Array()
	zbuf.resize(rays)

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

		zbuf[i] = dist_corr

	# 몬스터 빌보드 렌더링
	_draw_monsters(ppos, base_ang, fov, plane, zbuf)

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
	# DDA 레이 캐스팅(그리드 좌표 기준)
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
	# 셀 기반 밝기 변조(반복감 감소)
	var hx: int = int(cell.x) * 374761393
	var hy: int = int(cell.y) * 668265263
	var h: int = hx ^ hy
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var t: float = float(h & 0xFFFF) / 65535.0
	return lerp(0.90, 1.05, t)

func _get_interp_pos() -> Vector2:
	# 보간 위치
	if not enable_smoothing:
		return Vector2(player_cell) + Vector2(0.5, 0.5)
	var t: float = _ease(_anim_t)
	return _prev_pos.lerp(_target_pos, t)

func _get_interp_ang() -> float:
	# 보간 각도
	if not enable_smoothing:
		return _dir_to_angle(player_dir)
	var t: float = _ease(_anim_t)
	var diff: float = wrapf(_target_ang - _prev_ang, -PI, PI)
	return _prev_ang + diff * t

func _ease(t: float) -> float:
	# 무게감 있는 이징
	# More weighty ease: smoothstep squared
	var s: float = t * t * (3.0 - 2.0 * t)
	return s * s

func _start_anim_tween() -> void:
	# 애니메이션 Tween 시작
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_QUAD)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "_anim_t", 1.0, _anim_duration)
	_anim_tween.finished.connect(_on_anim_finished)

func _on_anim_finished() -> void:
	# 대기 중인 타깃이 있으면 이어서 재생
	if _has_pending:
		var next_pos: Vector2 = _pending_pos
		var next_ang: float = _pending_ang
		_has_pending = false

		_prev_pos = _get_interp_pos()
		_prev_ang = _get_interp_ang()
		_target_pos = next_pos
		_target_ang = next_ang
		var turn_only: bool = (next_pos == _prev_pos and next_ang != _prev_ang)
		_anim_duration = turn_smooth_time if turn_only else move_smooth_time
		_anim_t = 0.0
		_start_anim_tween()

func _draw_monsters(ppos: Vector2, base_ang: float, fov: float, plane: float, zbuf: PackedFloat32Array) -> void:
	# 몬스터 스프라이트 렌더링(시야각/거리/가시성 체크)
	if monster_texture == null:
		return
	if monster_list.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	var tex: Texture2D = monster_texture
	var tex_size: Vector2 = tex.get_size()
	var tex_w: float = max(1.0, tex_size.x)
	var tex_h: float = max(1.0, tex_size.y)

	# Draw farthest first for simple sorting
	var sorted: Array = monster_list.duplicate()
	sorted.sort_custom(func(a, b):
		var ac: Vector2 = Vector2(a["cell"]) + Vector2(0.5, 0.5)
		var bc: Vector2 = Vector2(b["cell"]) + Vector2(0.5, 0.5)
		return ac.distance_squared_to(ppos) > bc.distance_squared_to(ppos)
	)

	for m in sorted:
		if not (m is Dictionary) or not m.has("cell"):
			continue
		var mpos: Vector2 = Vector2(m["cell"]) + Vector2(0.5, 0.5)
		var to_m: Vector2 = mpos - ppos
		var dist: float = to_m.length()
		if dist <= 0.001:
			continue
		var ang: float = atan2(to_m.y, to_m.x)
		var rel: float = wrapf(ang - base_ang, -PI, PI)
		if abs(rel) > (fov * 0.5):
			continue

		var dist_corr: float = dist * cos(rel)
		dist_corr = max(0.001, dist_corr)
		if dist_corr > max_sprite_distance:
			continue

		# Line-of-sight check (single DDA)
		var los: Dictionary = _cast_dda(ppos, to_m.normalized())
		var wall_dist: float = float(los.get("dist", dist_corr))
		if wall_dist + 0.01 < dist_corr:
			continue

		var screen_x: float = (0.5 + (rel / (fov * 0.5)) * 0.5) * w
		var sprite_h: float = (1.0 / dist_corr) * plane * sprite_scale
		var max_h: float = h * max_sprite_height_ratio
		if sprite_h < min_sprite_height:
			sprite_h = min_sprite_height
		if sprite_h > max_h:
			sprite_h = max_h
		var sprite_w: float = sprite_h * (tex_w / tex_h)

		var x0: float = screen_x - sprite_w * 0.5
		var y0: float = h * 0.5 - sprite_h * 0.5

		# Simple occlusion against wall z-buffer
		var col_start: int = int(clamp(floor(x0 / (w / float(rays))), 0, rays - 1))
		var col_end: int = int(clamp(floor((x0 + sprite_w) / (w / float(rays))), 0, rays - 1))
		var any_visible: bool = false
		for i in range(col_start, col_end + 1):
			if i >= 0 and i < zbuf.size():
				if zbuf[i] <= 0.0 or zbuf[i] >= dist_corr:
					any_visible = true
					break
		if not any_visible:
			continue

		var dst: Rect2 = Rect2(Vector2(x0, y0), Vector2(sprite_w, sprite_h))
		draw_texture_rect(tex, dst, false)
