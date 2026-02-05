# res://scripts/dungeon_generator_game2.gd
class_name DungeonGeneratorGame2
extends RefCounted

const WALL: int = 0
const FLOOR: int = 1
const DEFAULT_MAX_ATTEMPTS: int = 20

@export var room_attempts: int = 40
@export var room_min: int = 3
@export var room_max: int = 7
@export var corridor_width: int = 1

# ---------------------------------------------------------------------
# Public API (same signature as existing generator)
# ---------------------------------------------------------------------
func generate(width: int, height: int, seed_value: int, corridor_density: float = 0.7) -> Dictionary:
	var w: int = max(width, 7)
	var h: int = max(height, 7)
	if (w % 2) == 0:
		w += 1
	if (h % 2) == 0:
		h += 1

	var density: float = clamp(corridor_density, 0.2, 1.0)

	for attempt: int in range(DEFAULT_MAX_ATTEMPTS):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(seed_value) + attempt * 991

		var grid: Array[PackedInt32Array] = _make_grid(w, h, WALL)

		# 1) Rooms
		var rooms: Array[Rect2i] = []
		var attempts: int = int(ceil(float(room_attempts) * density))
		_attempt_rooms(grid, rooms, rng, attempts)

		if rooms.is_empty():
			continue

		# 2) Corridors connecting rooms
		_connect_rooms(grid, rooms, rng)

		# 3) Pick start/exit
		var start: Vector2i = _room_center(rooms[0])
		var exit: Vector2i = _find_farthest_floor(grid, start)
		if exit == Vector2i(-1, -1):
			continue

		if _is_valid(grid, start, exit):
			return {
				"grid": grid,
				"start": start,
				"exit": exit
			}

	# Fallback
	var fallback: Array[PackedInt32Array] = _make_grid(7, 7, WALL)
	_carve_room(fallback, Rect2i(2, 2, 3, 3))
	return {"grid": fallback, "start": Vector2i(3, 3), "exit": Vector2i(4, 3)}

# ---------------------------------------------------------------------
# Rooms
# ---------------------------------------------------------------------
func _attempt_rooms(grid: Array[PackedInt32Array], rooms: Array[Rect2i], rng: RandomNumberGenerator, attempts: int) -> void:
	var w: int = grid[0].size()
	var h: int = grid.size()

	for _i: int in range(attempts):
		var rw: int = rng.randi_range(room_min, room_max)
		var rh: int = rng.randi_range(room_min, room_max)
		var rx: int = rng.randi_range(1, w - rw - 2)
		var ry: int = rng.randi_range(1, h - rh - 2)
		var rect: Rect2i = Rect2i(rx, ry, rw, rh)

		if _overlaps(rect, rooms):
			continue

		_carve_room(grid, rect)
		rooms.append(rect)

func _overlaps(rect: Rect2i, rooms: Array[Rect2i]) -> bool:
	for r: Rect2i in rooms:
		if rect.grow(1).intersects(r):
			return true
	return false

func _carve_room(grid: Array[PackedInt32Array], rect: Rect2i) -> void:
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			grid[y][x] = FLOOR

func _room_center(rect: Rect2i) -> Vector2i:
	return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)

# ---------------------------------------------------------------------
# Corridors
# ---------------------------------------------------------------------
func _connect_rooms(grid: Array[PackedInt32Array], rooms: Array[Rect2i], rng: RandomNumberGenerator) -> void:
	for i: int in range(1, rooms.size()):
		var a: Vector2i = _room_center(rooms[i - 1])
		var b: Vector2i = _room_center(rooms[i])
		if rng.randi() % 2 == 0:
			_dig_h(grid, a.x, b.x, a.y)
			_dig_v(grid, a.y, b.y, b.x)
		else:
			_dig_v(grid, a.y, b.y, a.x)
			_dig_h(grid, a.x, b.x, b.y)

func _dig_h(grid: Array[PackedInt32Array], x1: int, x2: int, y: int) -> void:
	var min_x: int = min(x1, x2)
	var max_x: int = max(x1, x2)
	for x: int in range(min_x, max_x + 1):
		for w: int in range(corridor_width):
			var yy: int = y + w
			if _in_bounds(grid, Vector2i(x, yy)):
				grid[yy][x] = FLOOR

func _dig_v(grid: Array[PackedInt32Array], y1: int, y2: int, x: int) -> void:
	var min_y: int = min(y1, y2)
	var max_y: int = max(y1, y2)
	for y: int in range(min_y, max_y + 1):
		for w: int in range(corridor_width):
			var xx: int = x + w
			if _in_bounds(grid, Vector2i(xx, y)):
				grid[y][xx] = FLOOR

# ---------------------------------------------------------------------
# Validation & Exit
# ---------------------------------------------------------------------
func _is_valid(grid: Array[PackedInt32Array], start: Vector2i, exit: Vector2i) -> bool:
	var w: int = grid[0].size()
	var h: int = grid.size()

	# Border must be walls
	for x: int in range(w):
		if grid[0][x] != WALL:
			return false
		if grid[h - 1][x] != WALL:
			return false
	for y: int in range(h):
		if grid[y][0] != WALL:
			return false
		if grid[y][w - 1] != WALL:
			return false

	# Start/exit must be floor
	if not _in_bounds(grid, start) or grid[start.y][start.x] != FLOOR:
		return false
	if not _in_bounds(grid, exit) or grid[exit.y][exit.x] != FLOOR:
		return false

	# Connectivity: start -> exit reachable
	var d: int = _bfs_dist(grid, start, exit)
	return d >= 0

func _find_farthest_floor(grid: Array[PackedInt32Array], start: Vector2i) -> Vector2i:
	if not _in_bounds(grid, start) or grid[start.y][start.x] != FLOOR:
		return Vector2i(-1, -1)

	var q: Array[Vector2i] = []
	var head: int = 0

	var dist: Dictionary[String, int] = {}
	dist[_key(start)] = 0
	q.append(start)

	var far: Vector2i = start
	var far_d: int = 0

	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1

		var cur_key: String = _key(cur)
		var cur_d: int = dist[cur_key]

		if cur_d > far_d:
			far_d = cur_d
			far = cur

		for n: Vector2i in _neighbors4(cur):
			if not _in_bounds(grid, n):
				continue
			if grid[n.y][n.x] != FLOOR:
				continue
			var nk: String = _key(n)
			if dist.has(nk):
				continue
			dist[nk] = cur_d + 1
			q.append(n)

	return far

func _bfs_dist(grid: Array[PackedInt32Array], start: Vector2i, goal: Vector2i) -> int:
	var q: Array[Vector2i] = []
	var head: int = 0

	var dist: Dictionary[String, int] = {}
	dist[_key(start)] = 0
	q.append(start)

	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1

		if cur == goal:
			return dist[_key(cur)]

		var cur_d: int = dist[_key(cur)]
		for n: Vector2i in _neighbors4(cur):
			if not _in_bounds(grid, n):
				continue
			if grid[n.y][n.x] != FLOOR:
				continue
			var nk: String = _key(n)
			if dist.has(nk):
				continue
			dist[nk] = cur_d + 1
			q.append(n)

	return -1

# ---------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------
func _make_grid(w: int, h: int, fill_value: int) -> Array[PackedInt32Array]:
	var grid: Array[PackedInt32Array] = []
	grid.resize(h)
	for y: int in range(h):
		var row: PackedInt32Array = PackedInt32Array()
		row.resize(w)
		for x: int in range(w):
			row[x] = fill_value
		grid[y] = row
	return grid

func _neighbors4(p: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(p.x + 1, p.y),
		Vector2i(p.x - 1, p.y),
		Vector2i(p.x, p.y + 1),
		Vector2i(p.x, p.y - 1),
	]

func _in_bounds(grid: Array[PackedInt32Array], p: Vector2i) -> bool:
	var h: int = grid.size()
	var w: int = grid[0].size()
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h

func _key(p: Vector2i) -> String:
	return str(p.x) + "," + str(p.y)
