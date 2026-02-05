class_name FPViewController
extends RefCounted

var center_nodes: Array[TextureRect] = []
var left_nodes: Array[TextureRect] = []
var right_nodes: Array[TextureRect] = []
var top_nodes: Array[TextureRect] = []
var bottom_nodes: Array[TextureRect] = []

const DEPTH_SHADES := [1.0, 0.5, 0.25]

var tex_top: Texture2D
var tex_bottom: Texture2D
var tex_center: Texture2D
var tex_left: Texture2D
var tex_right: Texture2D

func _init(
		center: Array[TextureRect],
		left: Array[TextureRect],
		right: Array[TextureRect],
		top: Array[TextureRect],
		bottom: Array[TextureRect],
		textures: Dictionary
	) -> void:
	center_nodes = center
	left_nodes = left
	right_nodes = right
	top_nodes = top
	bottom_nodes = bottom
	tex_top = textures.get("top")
	tex_bottom = textures.get("bottom")
	tex_center = textures.get("center")
	tex_left = textures.get("left")
	tex_right = textures.get("right")
	_apply_textures()
	_apply_depth_shading()

func clear():
	for node in center_nodes:
		node.visible = false
	for node in left_nodes:
		node.visible = false
	for node in right_nodes:
		node.visible = false
	for node in top_nodes:
		node.visible = false
	for node in bottom_nodes:
		node.visible = false

func update_depth(
		player_cell: Vector2i,
		front_vec: Vector2i,
		left_vec: Vector2i,
		right_vec: Vector2i,
		is_wall: Callable
	) -> void:
	clear()

	var depth: int = center_nodes.size()
	for i in range(depth):
		var d := i + 1
		var f: Vector2i = player_cell + (front_vec * d)
		var f_wall: bool = is_wall.call(f)

		var l: Vector2i = f + left_vec
		var r: Vector2i = f + right_vec

		var l_wall: bool = is_wall.call(l)
		var r_wall: bool = is_wall.call(r)

		_set_node(top_nodes, i, true)
		_set_node(bottom_nodes, i, true)

		if not f_wall:
			_set_node(left_nodes, i, l_wall)
			_set_node(right_nodes, i, r_wall)

		# front wall blocks further view
		if f_wall:
			_set_node(center_nodes, i, true)
			break

func _set_node(nodes: Array[TextureRect], idx: int, on: bool) -> void:
	if idx < nodes.size():
		nodes[idx].visible = on

func _apply_textures() -> void:
	var depth: int = min(
		center_nodes.size(),
		left_nodes.size(),
		right_nodes.size(),
		top_nodes.size(),
		bottom_nodes.size()
	)
	for i in range(depth):
		center_nodes[i].texture = tex_center
		left_nodes[i].texture = tex_left
		right_nodes[i].texture = tex_right
		top_nodes[i].texture = tex_top
		bottom_nodes[i].texture = tex_bottom

func _apply_depth_shading() -> void:
	var depth: int = min(center_nodes.size(), DEPTH_SHADES.size())
	for i in range(depth):
		var shade: float = DEPTH_SHADES[i]
		var color := Color(shade, shade, shade, 1.0)
		center_nodes[i].modulate = color
		left_nodes[i].modulate = color
		right_nodes[i].modulate = color
		top_nodes[i].modulate = color
		bottom_nodes[i].modulate = color
