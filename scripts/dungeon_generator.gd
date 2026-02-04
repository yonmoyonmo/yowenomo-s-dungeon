class_name DungeonGenerator
extends RefCounted

# This generator builds a single-tile-width corridor path (no rooms, no 2x2 floors).
# Core constraints enforced:
# 1) No 2x2 FLOOR blocks.
# 2) Every FLOOR tile has 1~2 orthogonal FLOOR neighbors (no junctions, no wide corridors).

const WALL := 0
const FLOOR := 1

var _last_start: Vector2i = Vector2i.ZERO
var _last_exit: Vector2i = Vector2i.ZERO

func generate(width: int, height: int, seed_value: int, corridor_density: float = 0.7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var w: int = _ensure_odd(width)
	var h: int = _ensure_odd(height)

	var max_attempts := 60
	for attempt in range(max_attempts):
		var grid: Array = _make_grid(w, h, WALL)

		var odd_cells: Array = _odd_cells(w, h)
		if odd_cells.size() < 2:
			continue

		var target_cells: int = clampi(int(odd_cells.size() * clampf(corridor_density, 0.05, 1.0)), 2, odd_cells.size())

		var start: Vector2i = _pick_start(odd_cells, rng)
		var path_cells: Array = _build_path(start, target_cells, rng, w, h)
		if path_cells.is_empty():
			continue

		_carve_path_cells(grid, path_cells)
		var exit: Vector2i = _pick_exit_far(path_cells, start, w, h, rng)
		if exit == Vector2i.ZERO:
			continue

		_last_start = start
		_last_exit = exit

		if is_valid(grid, start, exit):
			return {
				"grid": grid,
				"start": start,
				"exit": exit
			}

	# fallback (empty)
	return {
		"grid": _make_grid(w, h, WALL),
		"start": Vector2i.ZERO,
		"exit": Vector2i.ZERO
	}

func is_valid(grid: Array, start: Vector2i = Vector2i(-1, -1), exit: Vector2i = Vector2i(-1, -1)) -> bool:
	if start == Vector2i(-1, -1):
		start = _last_start
	if exit == Vector2i(-1, -1):
		exit = _last_exit

	var h: int = grid.size()
	if h == 0:
		return false
	var w: int = grid[0].size()

	# 1) 2x2 FLOOR check
	for y in range(h - 1):
		for x in range(w - 1):
			if grid[y][x] == FLOOR \
				and grid[y][x + 1] == FLOOR \
				and grid[y + 1][x] == FLOOR \
				and grid[y + 1][x + 1] == FLOOR:
				return false

	# 2) neighbor count 1~2 for every FLOOR
	for y in range(h):
		for x in range(w):
			if grid[y][x] != FLOOR:
				continue
			var n := _floor_neighbors(grid, x, y)
			if n < 1 or n > 2:
				return false

	# 3) BFS connectivity start -> all floors (and exit reachable)
	if not _in_bounds(start, w, h) or not _in_bounds(exit, w, h):
		return false
	if grid[start.y][start.x] != FLOOR or grid[exit.y][exit.x] != FLOOR:
		return false

	var visited: Dictionary = {}
	var queue: Array = [start]
	visited[_key(start)] = true
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cur.x + dir.x
			var ny: int = cur.y + dir.y
			if not _in_bounds_xy(nx, ny, w, h):
				continue
			if grid[ny][nx] != FLOOR:
				continue
			var k: String = "%d,%d" % [nx, ny]
			if visited.has(k):
				continue
			visited[k] = true
			queue.append(Vector2i(nx, ny))

	# ensure all floors reachable
	for y in range(h):
		for x in range(w):
			if grid[y][x] == FLOOR:
				if not visited.has("%d,%d" % [x, y]):
					return false

	return visited.has(_key(exit))

func print_grid(grid: Array, start: Vector2i, exit: Vector2i) -> void:
	var h: int = grid.size()
	if h == 0:
		print("(empty grid)")
		return
	var w: int = grid[0].size()
	for y in range(h):
		var line: String = ""
		for x in range(w):
			if start == Vector2i(x, y):
				line += "S"
			elif exit == Vector2i(x, y):
				line += "E"
			elif grid[y][x] == FLOOR:
				line += "."
			else:
				line += "#"
		print(line)

func _ready() -> void:
	var result := generate(41, 41, 12345, 0.7)
	var grid: Array = result["grid"]
	var start: Vector2i = result["start"]
	var exit: Vector2i = result["exit"]
	var floor_count: int = _count_floors(grid)
	print("start=", start, " exit=", exit, " floors=", floor_count)
	print_grid(grid, start, exit)

func _build_path(start: Vector2i, target_cells: int, rng: RandomNumberGenerator, w: int, h: int) -> Array:
	var path: Array = [start]
	var visited: Dictionary = {}
	visited[_key(start)] = true

	var max_iter: int = w * h * 10
	var iter := 0
	while path.size() < target_cells and iter < max_iter:
		iter += 1
		var cur: Vector2i = path[path.size() - 1]
		var next: Vector2i = _pick_unvisited_neighbor(cur, visited, rng, w, h)
		if next == Vector2i.ZERO:
			# backtrack
			if path.size() <= 1:
				break
			visited.erase(_key(cur))
			path.pop_back()
			continue

		path.append(next)
		visited[_key(next)] = true

	if path.size() < 2:
		return []
	return path

func _carve_path_cells(grid: Array, path: Array) -> void:
	# carve all nodes and walls between consecutive nodes
	grid[path[0].y][path[0].x] = FLOOR
	for i in range(1, path.size()):
		var prev: Vector2i = path[i - 1]
		var cur: Vector2i = path[i]
		var mid := Vector2i(int((prev.x + cur.x) / 2.0), int((prev.y + cur.y) / 2.0))
		grid[mid.y][mid.x] = FLOOR
		grid[cur.y][cur.x] = FLOOR

func _pick_unvisited_neighbor(cur: Vector2i, visited: Dictionary, rng: RandomNumberGenerator, w: int, h: int) -> Vector2i:
	var candidates: Array = []
	for dir in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var nx: int = cur.x + dir.x
		var ny: int = cur.y + dir.y
		if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1:
			continue
		var k: String = "%d,%d" % [nx, ny]
		if visited.has(k):
			continue
		candidates.append(Vector2i(nx, ny))

	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _pick_exit_far(path_cells: Array, start: Vector2i, w: int, h: int, rng: RandomNumberGenerator) -> Vector2i:
	var min_dist: int = int((w + h) / 4.0)
	var candidates: Array = []
	for c in path_cells:
		if start == c:
			continue
		var d: int = abs(c.x - start.x) + abs(c.y - start.y)
		if d >= min_dist:
			candidates.append(c)

	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _odd_cells(w: int, h: int) -> Array:
	var cells: Array = []
	for y in range(1, h - 1, 2):
		for x in range(1, w - 1, 2):
			cells.append(Vector2i(x, y))
	return cells

func _pick_start(cells: Array, rng: RandomNumberGenerator) -> Vector2i:
	return cells[rng.randi_range(0, cells.size() - 1)]

func _make_grid(w: int, h: int, value: int) -> Array:
	var grid: Array = []
	for y in range(h):
		var row: Array = []
		row.resize(w)
		for x in range(w):
			row[x] = value
		grid.append(row)
	return grid

func _count_floors(grid: Array) -> int:
	var count: int = 0
	for row in grid:
		for v in row:
			if v == FLOOR:
				count += 1
	return count

func _floor_neighbors(grid: Array, x: int, y: int) -> int:
	var w: int = grid[0].size()
	var h: int = grid.size()
	var n: int = 0
	if x > 0 and grid[y][x - 1] == FLOOR:
		n += 1
	if x < w - 1 and grid[y][x + 1] == FLOOR:
		n += 1
	if y > 0 and grid[y - 1][x] == FLOOR:
		n += 1
	if y < h - 1 and grid[y + 1][x] == FLOOR:
		n += 1
	return n

func _ensure_odd(v: int) -> int:
	if v % 2 == 0:
		return v - 1
	return v

func _in_bounds(pos: Vector2i, w: int, h: int) -> bool:
	return _in_bounds_xy(pos.x, pos.y, w, h)

func _in_bounds_xy(x: int, y: int, w: int, h: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h

func _key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
