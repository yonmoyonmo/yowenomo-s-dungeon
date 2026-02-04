class_name FPViewController
extends RefCounted

var front_nodes: Array
var left_nodes: Array
var right_nodes: Array

const SIDE_LAYOUTS := [
	{"x_scale": 0.22, "x_offset": 0.0},
	{"x_scale": 0.18, "x_offset": 6.0},
	{"x_scale": 0.14, "x_offset": 12.0}
]

var tex_side_continue: Texture2D
var tex_side_end: Texture2D
var tex_outer_left: Texture2D
var tex_outer_right: Texture2D
var tex_inner_left: Texture2D
var tex_inner_right: Texture2D

func _init(
		front: Array,
		left: Array,
		right: Array,
		textures: Dictionary
	) -> void:
	front_nodes = front
	left_nodes = left
	right_nodes = right
	tex_side_continue = textures.get("side_continue")
	tex_side_end = textures.get("side_end")
	tex_outer_left = textures.get("outer_left")
	tex_outer_right = textures.get("outer_right")
	tex_inner_left = textures.get("inner_left")
	tex_inner_right = textures.get("inner_right")
	_apply_depth_layouts()

func clear():
	for node in front_nodes:
		node.visible = false
	for node in left_nodes:
		node.visible = false
	for node in right_nodes:
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
		var f_wall: bool = is_wall.call(f)

		var l: Vector2i = f + left_vec
		var r: Vector2i = f + right_vec
		var fl: Vector2i = l + front_vec
		var fr: Vector2i = r + front_vec

		var l_wall: bool = is_wall.call(l)
		var r_wall: bool = is_wall.call(r)
		var fl_wall: bool = is_wall.call(fl)
		var fr_wall: bool = is_wall.call(fr)

		_apply_side_texture(i, false, f_wall, l_wall, fl_wall)
		_apply_side_texture(i, true, f_wall, r_wall, fr_wall)

		# front wall blocks further view
		if f_wall:
			_set_node(front_nodes, i, true)
			break

func _set_node(nodes: Array, idx: int, on: bool) -> void:
	if idx < nodes.size():
		nodes[idx].visible = on

func _apply_side_texture(idx: int, is_right: bool, f_wall: bool, side_wall: bool, diag_wall: bool) -> void:
	var node: TextureRect = right_nodes[idx] if is_right else left_nodes[idx]
	var tex: Texture2D = _pick_side_texture(is_right, f_wall, side_wall, diag_wall)
	if tex == null:
		node.visible = false
		return
	node.texture = tex
	node.visible = true
	if is_right:
		node.flip_h = (tex == tex_side_continue or tex == tex_side_end)
	else:
		node.flip_h = false

func _pick_side_texture(is_right: bool, f_wall: bool, side_wall: bool, diag_wall: bool) -> Texture2D:
	# Priority: outer/inner corner, then side_continue/side_end, then empty.
	if _is_outer_corner(f_wall, side_wall, diag_wall):
		return tex_outer_right if is_right else tex_outer_left
	if _is_inner_corner(f_wall, side_wall, diag_wall):
		return tex_inner_right if is_right else tex_inner_left
	if side_wall and diag_wall:
		return tex_side_continue
	if side_wall and not diag_wall:
		return tex_side_end
	return null

func _is_outer_corner(f_wall: bool, side_wall: bool, diag_wall: bool) -> bool:
	return side_wall and not f_wall and diag_wall

func _is_inner_corner(f_wall: bool, side_wall: bool, diag_wall: bool) -> bool:
	return not side_wall and f_wall and diag_wall

func _apply_depth_layouts() -> void:
	var depth: int = min(left_nodes.size(), right_nodes.size(), SIDE_LAYOUTS.size())
	for i in range(depth):
		var layout: Dictionary = SIDE_LAYOUTS[i]
		_apply_side_layout(left_nodes[i], layout, false)
		_apply_side_layout(right_nodes[i], layout, true)

func _apply_side_layout(node: Control, layout: Dictionary, is_right: bool) -> void:
	var x_scale: float = layout.get("x_scale", 0.2)
	var x_offset: float = layout.get("x_offset", 0.0)
	if is_right:
		node.anchor_left = 1.0 - x_scale
		node.anchor_right = 1.0
		node.offset_left = -x_offset
		node.offset_right = -x_offset
	else:
		node.anchor_left = 0.0
		node.anchor_right = x_scale
		node.offset_left = x_offset
		node.offset_right = x_offset
