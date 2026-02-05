extends Control

# 타운 씬 컨트롤러

@onready var btn_shop: Button = $BtnShop
@onready var gold_label: Label = $GoldLabel
@onready var modal_layer: Control = $ModalLayer
@onready var modal_title: Label = $ModalLayer/Panel/Title
@onready var modal_body: RichTextLabel = $ModalLayer/Panel/Body

func _on_btn_enter_dungeon_pressed() -> void:
	# 던전 입장
	var err := get_tree().change_scene_to_file("res://scenes/Dungeon.tscn")
	if err != OK:
		push_error("Failed to change scene: %s" % err)

func _on_btn_shop_pressed() -> void:
	# 상점은 추후 구현
	if btn_shop:
		btn_shop.text = "Shop (WIP)"

func _ready() -> void:
	# 골드 표시 갱신
	_update_gold_label()

func _update_gold_label() -> void:
	gold_label.text = "GOLD: %d" % GameState.gold

func _on_btn_status_pressed() -> void:
	# 스탯 모달 열기
	_show_status()

func _on_btn_inventory_pressed() -> void:
	# 인벤 모달 열기
	_show_inventory()

func _on_btn_close_modal_pressed() -> void:
	# 모달 닫기
	_hide_modal()

func _show_status() -> void:
	# 스탯 내용 출력
	modal_layer.visible = true
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
	# 인벤 목록 출력
	modal_layer.visible = true
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
