extends Node

# 전역 상태 저장용 Autoload
# 씬이 바뀌어도 유지되어야 하는 데이터는 여기에서 관리한다.

enum SceneType { BOOT, TITLE, TOWN, DUNGEON, RESULT }
var current_scene: SceneType = SceneType.BOOT
var gold: int = 0

# 임시 스탯(나중에 구조화 예정)
var stats := {
	"level": 1,
	"hp": 20,
	"max_hp": 20,
	"atk": 5,
	"def": 2
}

# 임시 인벤토리(나중에 구조화 예정)
var inventory: Array = [
	{"id": "potion_small", "name": "Small Potion", "qty": 2, "desc": "Heals 5 HP"},
	{"id": "rusty_sword", "name": "Rusty Sword", "qty": 1, "desc": "+1 ATK"}
]
