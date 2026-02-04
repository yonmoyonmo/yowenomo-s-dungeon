class_name FPViewController
extends RefCounted

var front_nodes: Array
var left_nodes: Array
var right_nodes: Array
var ceiling_nodes: Array
var floor_nodes: Array

func _init(
		front: Array,
		left: Array,
		right: Array,
		ceiling: Array,
		floor_nodes_in: Array
	) -> void:
	front_nodes = front
	left_nodes = left
	right_nodes = right
	ceiling_nodes = ceiling
	floor_nodes = floor_nodes_in

func clear():
	for node in front_nodes:
		node.visible = false
	for node in left_nodes:
		node.visible = false
	for node in right_nodes:
		node.visible = false
	for node in ceiling_nodes:
		node.visible = false
	for node in floor_nodes:
		node.visible = false

func update_depth(
		player_cell: Vector2i,
		front_vec: Vector2i,
		left_vec: Vector2i,
		right_vec: Vector2i,
		is_wall: Callable
	) -> void:
	clear()

	var depth: int = front_nodes.size()
	for i in range(depth):
		var d := i + 1
		var f: Vector2i = player_cell + (front_vec * d)

		# front wall blocks further view
		if is_wall.call(f):
			_set_node(front_nodes, i, true)
			break

		_set_node(ceiling_nodes, i, true)
		_set_node(floor_nodes, i, true)

		# side walls at this depth
		var l: Vector2i = f + left_vec
		var r: Vector2i = f + right_vec
		_set_node(left_nodes, i, is_wall.call(l))
		_set_node(right_nodes, i, is_wall.call(r))

func _set_node(nodes: Array, idx: int, on: bool) -> void:
	if idx < nodes.size():
		nodes[idx].visible = on
