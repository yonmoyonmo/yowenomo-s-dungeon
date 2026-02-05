extends ColorRect

# 그리드 기반 플레이어 컨트롤러
# 이동/회전은 턴제이며, 시그널로 게임 컨트롤러에 전달한다.

@export var tile_size := 32
@export var use_keyboard := false
var can_act := true

signal acted(action_text: String)
signal try_move(next_cell: Vector2i, action_text: String)

var cell := Vector2i(2, 2) # 시작 위치
# 0:N, 1:E, 2:S, 3:W (시계 방향)
var dir := 0

func _unhandled_input(event):
	# 키보드 입력(옵션)
	if not use_keyboard:
		return
	if not can_act:
		return

	# 1) 회전 (턴 소비)
	if event.is_action_pressed("turn_left"):
		act_turn(-1)
		return
	if event.is_action_pressed("turn_right"):
		act_turn(+1)
		return

	# 2) 전진 (턴 소비)
	if event.is_action_pressed("move_forward"):
		act_forward()
		return

func act_turn(delta: int):
	# 회전(턴 소비)
	can_act = false
	dir = (dir + delta) % 4
	if dir < 0:
		dir += 4

	emit_signal("acted", "turn " + _dir_name())
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(0.12).timeout
	can_act = true

func act_forward():
	# 전진(턴 소비)
	can_act = false
	var next := cell + _dir_vec()
	emit_signal("try_move", next, "forward")
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(0.12).timeout
	can_act = true

func act_move_to(next: Vector2i, action_text: String):
	# 임의 방향 이동(턴 소비)
	if not can_act:
		return
	can_act = false
	emit_signal("try_move", next, action_text)
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(0.12).timeout
	can_act = true


func _dir_vec() -> Vector2i:
	# 현재 방향 벡터
	match dir:
		0: return Vector2i(0, -1) # N
		1: return Vector2i(1, 0)  # E
		2: return Vector2i(0, 1)  # S
		_: return Vector2i(-1, 0) # W

func _left_vec() -> Vector2i:
	# 왼쪽 방향 벡터
	match dir:
		0: return Vector2i(-1, 0)
		1: return Vector2i(0, -1)
		2: return Vector2i(1, 0)
		_: return Vector2i(0, 1)

func _right_vec() -> Vector2i:
	# 오른쪽 방향 벡터
	match dir:
		0: return Vector2i(1, 0)
		1: return Vector2i(0, 1)
		2: return Vector2i(-1, 0)
		_: return Vector2i(0, -1)

func front_cell() -> Vector2i:
	return cell + _dir_vec()

func back_cell() -> Vector2i:
	return cell - _dir_vec()

func left_cell() -> Vector2i:
	return cell + _left_vec()

func right_cell() -> Vector2i:
	return cell + _right_vec()

func _dir_name() -> String:
	match dir:
		0: return "N"
		1: return "E"
		2: return "S"
		_: return "W"
		
func get_dir_name() -> String:
	return _dir_name()
