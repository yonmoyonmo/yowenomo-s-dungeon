extends ColorRect

@export var tile_size := 32
@export var use_keyboard := false
var can_act := true

signal acted(action_text: String)
signal try_move(next_cell: Vector2i, action_text: String)

var cell := Vector2i(2, 2) # 시작 위치
# 0:N, 1:E, 2:S, 3:W (시계 방향)
var dir := 0

func _unhandled_input(event):
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
	can_act = false
	dir = (dir + delta) % 4
	if dir < 0:
		dir += 4

	emit_signal("acted", "turn " + _dir_name())
	await get_tree().create_timer(0.12).timeout
	can_act = true

func act_forward():
	can_act = false
	var next := cell + _dir_vec()
	emit_signal("try_move", next, "forward")
	await get_tree().create_timer(0.12).timeout
	can_act = true

func act_move_to(next: Vector2i, action_text: String):
	if not can_act:
		return
	can_act = false
	emit_signal("try_move", next, action_text)
	await get_tree().create_timer(0.12).timeout
	can_act = true


func _dir_vec() -> Vector2i:
	match dir:
		0: return Vector2i(0, -1) # N
		1: return Vector2i(1, 0)  # E
		2: return Vector2i(0, 1)  # S
		_: return Vector2i(-1, 0) # W

func _left_vec() -> Vector2i:
	match dir:
		0: return Vector2i(-1, 0)
		1: return Vector2i(0, -1)
		2: return Vector2i(1, 0)
		_: return Vector2i(0, 1)

func _right_vec() -> Vector2i:
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
