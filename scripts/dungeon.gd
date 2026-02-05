# dungeon.gd
# 던전 씬 메인 컨트롤러
# - 던전 생성/플레이어 스폰
# - 미니맵/레이캐스트 뷰 갱신
# - 골드/몬스터 스폰 및 전투 진입
extends Control

const DungeonGeneratorModule = preload("res://scripts/random_dungeon_generator.gd")
const MiniMapRendererModule = preload("res://scripts/minimap.gd")
const CombatEngineModule = preload("res://scripts/combat_engine.gd")

@onready var player: Node = $World/Player
@onready var hud: Control = $HUD
@onready var ray_view: Control = $HUD/RaycastView
@onready var turn_label: Label = $HUD/TurnLabel
@onready var log_label: Label = $HUD/LogLabel
@onready var dir_label: Label = $HUD/DirLabel
@onready var gold_label: Label = $HUD/GoldLabel
@onready var modal_layer: Control = $HUD/ModalLayer
@onready var modal_title: Label = $HUD/ModalLayer/Panel/Title
@onready var modal_body: RichTextLabel = $HUD/ModalLayer/Panel/Body
@onready var controls: Control = $HUD/Controls
@onready var modal_btn_close: Button = $HUD/ModalLayer/Panel/BtnClose
@onready var modal_btn_fight: Button = $HUD/ModalLayer/Panel/BtnFight
@onready var modal_btn_run: Button = $HUD/ModalLayer/Panel/BtnRun

@export var map_w := 21
@export var map_h := 21
@export var seed_value := Time.get_unix_time_from_system()
@export var corridor_density := 0.7
@export var monster_count := 6

var dungeon_gen: RandomDungeonGenerator
var minimap_renderer: MiniMapRenderer
var dungeon: Array = []
var tile_size := 64.0
var start_cell := Vector2i.ZERO
var end_cell := Vector2i.ZERO
var gold_cell: Variant = null
var monsters: Array = []
var turn := 0
var in_combat: bool = false
var current_monster: Dictionary = {}
var combat: CombatEngine

func _ready() -> void:
	# 1) 던전 생성
	dungeon_gen = DungeonGeneratorModule.new()
	var result := dungeon_gen.generate(map_w, map_h, seed_value, corridor_density)
	dungeon = result["grid"]
	map_h = dungeon.size()
	if map_h > 0:
		map_w = dungeon[0].size()
	start_cell = result["start"]
	end_cell = result["exit"]

	# 2) 렌더러/스폰 데이터 준비
	minimap_renderer = MiniMapRendererModule.new()
	_place_gold()
	_place_monsters()
	combat = CombatEngineModule.new()
	combat.combat_updated.connect(_on_combat_updated)
	combat.combat_ended.connect(_on_combat_ended)
	combat.player_died.connect(_on_player_died)

	# 3) 플레이어 스폰
	player.cell = start_cell
	player.dir = 0
	tile_size = player.tile_size
	player.position = Vector2(player.cell) * tile_size

	# 4) 시그널 연결
	# (형님 기존 흐름: hud.action_requested -> 게임컨트롤러가 처리)
	hud.action_requested.connect(_on_action_requested)
	player.acted.connect(_on_player_acted)
	player.try_move.connect(_on_player_try_move)

	# 5) 초기 화면
	_update_dir_label()
	turn_label.text = "TURN: %d" % turn
	log_label.text = "ready"
	_update_gold_label()
	_update_view()

func _on_action_requested(action: String) -> void:
	# 전투 중에는 전투 액션만 허용
	if in_combat and action not in ["fight", "run"]:
		return
	match action:
		"turn_left":
			player.act_turn(-1)
			log_label.text = "turn left"
		"turn_right":
			player.act_turn(1)
			log_label.text = "turn right"
		"forward":
			player.act_move_to(player.front_cell(), "forward")
			log_label.text = "forward"
		"back":
			player.act_move_to(player.back_cell(), "back")
			log_label.text = "back"
		"left":
			player.act_move_to(player.left_cell(), "left")
			log_label.text = "left"
		"right":
			player.act_move_to(player.right_cell(), "right")
			log_label.text = "right"
		"die":
			_return_to_town("died")
		"status":
			_show_status()
		"inventory":
			_show_inventory()
		"fight":
			_resolve_fight_turn()
		"run":
			_try_run()
		"close_modal":
			_hide_modal()
		_:
			pass

func _on_player_try_move(next_cell: Vector2i, action_text: String) -> void:
	# 벽 충돌 처리
	if _is_wall(next_cell):
		# 벽이면 이동 불가(기존 로직처럼 HUD에 로그 띄우고 싶으면 여기서)
		player.emit_signal("acted", "bumped into wall")
		return

	player.cell = next_cell
	player.position = Vector2(player.cell) * tile_size
	player.emit_signal("acted", action_text)

func _on_player_acted(_action_text: String) -> void:
	# 턴 진행 후 갱신
	turn += 1
	turn_label.text = "TURN: %d" % turn
	log_label.text = _action_text
	_update_dir_label()
	_check_gold_pickup()
	_check_monster_encounter()
	_update_view()
	if player.cell == end_cell:
		_return_to_town("cleared")

func _update_view() -> void:
	# 미니맵과 레이캐스트 뷰 갱신
	_update_minimap()
	$HUD/RaycastView.set_state(dungeon, tile_size, player.cell, player.dir, monsters)

func _update_dir_label() -> void:
	dir_label.text = "DIR: " + player.get_dir_name()

func _update_gold_label() -> void:
	gold_label.text = "GOLD: %d" % GameState.gold

func _return_to_town(reason: String) -> void:
	# 던전 종료 후 타운 복귀
	log_label.text = reason
	var err := get_tree().change_scene_to_file("res://scenes/Town.tscn")
	if err != OK:
		push_error("Failed to change scene: %s" % err)

func _update_minimap() -> void:
	var tex := minimap_renderer.build_minimap(
		dungeon,
		map_w,
		map_h,
		start_cell,
		end_cell,
		player.cell,
		gold_cell,
		monsters
	)
	$HUD/MiniMap.texture = tex

func _place_gold() -> void:
	# 골드 1개 랜덤 스폰
	if dungeon.is_empty():
		gold_cell = null
		return
	var floors: Array[Vector2i] = []
	for y: int in range(map_h):
		for x: int in range(map_w):
			if dungeon[y][x] == 1:
				var c: Vector2i = Vector2i(x, y)
				if c != start_cell and c != end_cell:
					floors.append(c)
	if floors.is_empty():
		gold_cell = null
		return
	gold_cell = floors[randi() % floors.size()]

func _place_monsters() -> void:
	# 몬스터 랜덤 스폰
	monsters = []
	if dungeon.is_empty():
		return
	var floors: Array[Vector2i] = []
	for y: int in range(map_h):
		for x: int in range(map_w):
			if dungeon[y][x] == 1:
				var c: Vector2i = Vector2i(x, y)
				if c != start_cell and c != end_cell:
					floors.append(c)
	if floors.is_empty():
		return
	var count: int = clamp(monster_count, 0, floors.size())
	for i: int in range(count):
		var idx: int = randi() % floors.size()
		var c: Vector2i = floors[idx]
		floors.remove_at(idx)
		if gold_cell is Vector2i and c == gold_cell:
			continue
		monsters.append({"cell": c, "id": "slime", "hp": 8, "atk": 2, "def": 0})

func _check_monster_encounter() -> void:
	# 몬스터 칸 도달 시 전투 시작
	for i: int in range(monsters.size()):
		var m: Dictionary = monsters[i]
		if m.has("cell") and m["cell"] == player.cell:
			_start_combat(i, m)
			return
func _start_combat(index: int, monster: Dictionary) -> void:
	# 전투 UI 열기 + 전투 엔진 시작
	in_combat = true
	current_monster = monster.duplicate(true)
	current_monster["index"] = index
	modal_layer.visible = true
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_modal_buttons(true)
	combat.start(GameState.stats, current_monster)

func _update_combat_modal() -> void:
	# 전투 모달 내용 갱신
	modal_title.text = "Battle"
	var m_name: String = str(current_monster.get("id", "monster"))
	var m_hp: int = combat.get_monster_hp()
	var p_hp: int = int(GameState.stats.get("hp", 0))
	var p_max: int = int(GameState.stats.get("max_hp", 0))
	var header := "%s\nHP %d\n\nYou: %d/%d\n\n" % [m_name, m_hp, p_hp, p_max]
	modal_body.text = header + combat.get_log_text()

func _resolve_fight_turn() -> void:
	# 전투 한 턴 진행
	if not in_combat:
		return
	combat.fight_turn()

func _try_run() -> void:
	# 도망 시도
	if not in_combat:
		return
	combat.try_run()

func _on_combat_updated(_text: String) -> void:
	# 전투 엔진에서 로그 갱신 시 호출
	_update_combat_modal()

func _on_combat_ended(result: String, reward: Dictionary) -> void:
	# 전투 종료 처리(보상/몬스터 제거)
	if not in_combat:
		return
	if result == "won":
		var idx: int = int(current_monster.get("index", -1))
		if idx >= 0 and idx < monsters.size():
			monsters.remove_at(idx)
		if reward.has("gold"):
			GameState.gold += int(reward["gold"])
			_update_gold_label()
		log_label.text = "defeated %s" % str(current_monster.get("id", "monster"))
	elif result == "ran":
		log_label.text = "ran away"
	in_combat = false
	current_monster = {}
	_hide_modal()

func _on_player_died() -> void:
	_return_to_town("died")


func _check_gold_pickup() -> void:
	# 골드 칸에 도착하면 획득
	if gold_cell is Vector2i and player.cell == gold_cell:
		GameState.gold += 1
		log_label.text = "picked gold"
		gold_cell = null
		_update_gold_label()

func _is_wall(cell: Vector2i) -> bool:
	# 던전 벽 판정
	if cell.y < 0 or cell.y >= dungeon.size():
		return true
	var row = dungeon[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return true
	return int(row[cell.x]) == 0 # WALL=0

func _show_status() -> void:
	# 스탯 모달
	modal_layer.visible = true
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_modal_buttons(false)
	modal_title.text = "Status"
	var s: Dictionary = GameState.stats
	var hp: int = int(s.get("hp", 0))
	var max_hp: int = int(s.get("max_hp", 0))
	var level: int = int(s.get("level", 1))
	var atk: int = int(s.get("atk", 0))
	var dfn: int = int(s.get("def", 0))
	modal_body.text = "LV %d\nHP %d/%d\nATK %d\nDEF %d\nGOLD %d" % [
		level, hp, max_hp, atk, dfn, GameState.gold
	]

func _show_inventory() -> void:
	# 인벤 모달
	modal_layer.visible = true
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_modal_buttons(false)
	modal_title.text = "Inventory"
	var lines: Array[String] = []
	for item in GameState.inventory:
		var name: String = str(item.get("name", "Unknown"))
		var qty: int = int(item.get("qty", 1))
		var desc: String = str(item.get("desc", ""))
		lines.append("%s x%d" % [name, qty])
		if desc != "":
			lines.append("  - " + desc)
	if lines.is_empty():
		lines.append("Empty")
	modal_body.text = "\n".join(lines)

func _hide_modal() -> void:
	# 모달 닫기
	modal_layer.visible = false
	controls.mouse_filter = Control.MOUSE_FILTER_STOP

func _set_modal_buttons(combat_mode: bool) -> void:
	# 전투 모드일 때만 Fight/Run 표시
	modal_btn_close.visible = not combat_mode
	modal_btn_fight.visible = combat_mode
	modal_btn_run.visible = combat_mode
