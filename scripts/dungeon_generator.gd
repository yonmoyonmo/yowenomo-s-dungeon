# res://scripts/dungeon_generator.gd
class_name DungeonGenerator
extends RefCounted

const WALL: int = 0
const FLOOR: int = 1
const DEFAULT_MAX_ATTEMPTS: int = 40

# ---------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------
func generate(width: int, height: int, seed_value: int, corridor_density: float = 0.7) -> Dictionary:
	var w: int = max(width, 5)
	var h: int = max(height, 5)
	if (w % 2) == 0:
		w += 1
	if (h % 2) == 0:
		h += 1

	var density: float = clamp(corridor_density, 0.2, 1.0)

	for attempt: int in range(DEFAULT_MAX_ATTEMPTS):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(seed_value) + attempt * 9973

		var grid: Array[PackedInt32Array] = _make_grid(w, h, WALL)

		# Border is always WALL, so start must be inside the border.
		var start: Vector2i = Vector2i(1, 1)

		_carve_maze_region(grid, start, rng, density)

		var exit: Vector2i = _find_farthest_floor(grid, start)
		if exit == Vector2i(-1, -1):
			continue

		if _is_valid(grid, start, exit):
			return {
				"grid": grid,
				"start": start,
				"exit": exit
			}

	# Fallback (should rarely happen)
	var fallback: Array[PackedInt32Array] = _make_grid(5, 5, WALL)
	fallback[1][1] = FLOOR
	fallback[1][2] = FLOOR
	fallback[1][3] = FLOOR
	return {"grid": fallback, "start": Vector2i(1, 1), "exit": Vector2i(3, 1)}

# ---------------------------------------------------------------------
# Maze carving (odd-cell randomized DFS)
# ---------------------------------------------------------------------
func _carve_maze_region(grid: Array[PackedInt32Array], start: Vector2i, rng: RandomNumberGenerator, density: float) -> void:
	var w: int = grid[0].size()
	var h: int = grid.size()

	# Count odd cells
	var odd_cells: Array[Vector2i] = []
	for y: int in range(1, h - 1, 2):
		for x: int in range(1, w - 1, 2):
			odd_cells.append(Vector2i(x, y))

	var target_cells: int = int(ceil(float(odd_cells.size()) * density))
	target_cells = clamp(target_cells, 2, odd_cells.size())

	# IMPORTANT: visited is NOT erased on backtrack (or you get "snake" dungeons).
	var visited: Dictionary[String, bool] = {}
	var stack: Array[Vector2i] = []

	visited[_key(start)] = true
	stack.append(start)

	grid[start.y][start.x] = FLOOR
	var visited_count: int = 1

	while stack.size() > 0 and visited_count < target_cells:
		var cur: Vector2i = stack[stack.size() - 1]

		var dirs: Array[Vector2i] = [
			Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)
		]
		_shuffle_in_place_vec2i(dirs, rng)

		var advanced: bool = false
		for d: Vector2i in dirs:
			var nxt: Vector2i = cur + d
			if nxt.x <= 0 or nxt.y <= 0 or nxt.x >= w - 1 or nxt.y >= h - 1:
				continue

			var nk: String = _key(nxt)
			if visited.has(nk):
				continue

			# Carve wall between cur and nxt (midpoint is one step away)
			var mid: Vector2i = Vector2i(cur.x + d.x / 2, cur.y + d.y / 2)
			grid[mid.y][mid.x] = FLOOR
			grid[nxt.y][nxt.x] = FLOOR

			visited[nk] = true
			stack.append(nxt)
			visited_count += 1
			advanced = true
			break

		if not advanced:
			stack.pop_back()

# ---------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------
func _is_valid(grid: Array[PackedInt32Array], start: Vector2i, exit: Vector2i) -> bool:
	var w: int = grid[0].size()
	var h: int = grid.size()

	# 1) Border must be walls
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

	# 2) Start/exit must be floor
	if not _in_bounds(grid, start) or grid[start.y][start.x] != FLOOR:
		return false
	if not _in_bounds(grid, exit) or grid[exit.y][exit.x] != FLOOR:
		return false

	# 3) No 2x2 floor blocks (room prevention)
	for y: int in range(h - 1):
		for x: int in range(w - 1):
			if grid[y][x] == FLOOR \
			and grid[y][x + 1] == FLOOR \
			and grid[y + 1][x] == FLOOR \
			and grid[y + 1][x + 1] == FLOOR:
				return false

	# 4) Connectivity: start -> exit reachable
	var d: int = _bfs_dist(grid, start, exit)
	return d >= 0

# ---------------------------------------------------------------------
# Exit selection (BFS farthest)
# ---------------------------------------------------------------------
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
# Debug
# ---------------------------------------------------------------------
func print_grid(grid: Array[PackedInt32Array], start: Vector2i, exit: Vector2i) -> void:
	var h: int = grid.size()
	var w: int = grid[0].size()
	for y: int in range(h):
		var line: String = ""
		for x: int in range(w):
			var p: Vector2i = Vector2i(x, y)
			if p == start:
				line += "S"
			elif p == exit:
				line += "E"
			else:
				line += "." if grid[y][x] == FLOOR else "#"
		print(line)

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

func _shuffle_in_place_vec2i(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	# Fisher–Yates
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
