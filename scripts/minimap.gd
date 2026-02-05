class_name MiniMapRenderer
extends RefCounted

func build_minimap(
		dungeon: Array,
		map_w: int,
		map_h: int,
		start_cell: Vector2i,
		end_cell: Vector2i,
		player_cell: Vector2i
	) -> ImageTexture:
	if dungeon.is_empty():
		return ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var img := Image.create(map_w, map_h, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK) # 기본 배경

	for y in range(map_h):
		for x in range(map_w):
			if dungeon[y][x] == 0:
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1)) # 벽
			else:
				img.set_pixel(x, y, Color(0.9, 0.9, 0.9)) # 바닥

	if start_cell != Vector2i.ZERO or end_cell != Vector2i.ZERO:
		img.set_pixel(start_cell.x, start_cell.y, Color(0.2, 0.5, 1.0)) # 시작
		img.set_pixel(end_cell.x, end_cell.y, Color(1.0, 0.2, 0.2)) # 끝

	img.set_pixel(player_cell.x, player_cell.y, Color(0.0, 0.681, 0.203, 1.0)) # 플레이어

	return ImageTexture.create_from_image(img)
