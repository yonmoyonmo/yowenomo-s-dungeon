class_name MiniMapRenderer
extends RefCounted

# 미니맵 텍스처 생성기
func build_minimap(
		dungeon: Array,
		map_w: int,
		map_h: int,
		start_cell: Vector2i,
		end_cell: Vector2i,
		player_cell: Vector2i,
		gold_cell: Variant,
		monsters: Array
	) -> ImageTexture:
	# 던전/플레이어/아이템/몬스터 상태를 픽셀로 렌더링
	if dungeon.is_empty():
		return ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var img := Image.create(map_w, map_h, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK) # 기본 배경

	for y in range(map_h):
		for x in range(map_w):
			# 벽/바닥 색상
			if dungeon[y][x] == 0:
				img.set_pixel(x, y, Color(0.1, 0.1, 0.1)) # 벽
			else:
				img.set_pixel(x, y, Color(0.9, 0.9, 0.9)) # 바닥

	if start_cell != Vector2i.ZERO or end_cell != Vector2i.ZERO:
		# 시작/출구 표시
		img.set_pixel(start_cell.x, start_cell.y, Color(0.2, 0.5, 1.0)) # 시작
		img.set_pixel(end_cell.x, end_cell.y, Color(1.0, 0.2, 0.2)) # 끝

	if gold_cell is Vector2i:
		# 골드 표시
		var g: Vector2i = gold_cell
		if g.x >= 0 and g.y >= 0 and g.y < map_h and g.x < map_w:
			img.set_pixel(g.x, g.y, Color(0.95, 0.85, 0.2)) # 골드

	for m in monsters:
		# 몬스터 표시
		if m is Dictionary and m.has("cell"):
			var c: Vector2i = m["cell"]
			if c.x >= 0 and c.y >= 0 and c.y < map_h and c.x < map_w:
				img.set_pixel(c.x, c.y, Color(1.0, 0.3, 0.7)) # 몬스터

	# 플레이어 표시
	img.set_pixel(player_cell.x, player_cell.y, Color(0.0, 0.681, 0.203, 1.0)) # 플레이어

	return ImageTexture.create_from_image(img)
