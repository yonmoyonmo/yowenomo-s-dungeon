# combat_engine.gd
# 전투 전용 로직 모듈
# - 주사위 판정(D20)
# - 공격/방어/도망 처리
# - 전투 로그 누적
class_name CombatEngine
extends RefCounted

# 전투 상태 변경 이벤트
signal combat_updated(text: String)
signal combat_ended(result: String, reward: Dictionary)
signal player_died()

var player_stats: Dictionary
var monster: Dictionary
var log: Array[String] = []

const RUN_DC: int = 12

func start(_player_stats: Dictionary, _monster: Dictionary) -> void:
	# 전투 시작
	player_stats = _player_stats
	monster = _monster
	log = []
	log.append("Encountered %s" % str(monster.get("id", "monster")))
	_emit_update()

func fight_turn() -> void:
	# 플레이어 선공 -> 몬스터 반격
	if monster.is_empty():
		return
	var atk_roll: Dictionary = _roll_attack(player_stats, monster)
	if atk_roll["hit"]:
		var dmg: int = _calc_damage(player_stats, monster)
		monster["hp"] = int(monster.get("hp", 0)) - dmg
		log.append("You hit %d" % dmg)
	else:
		log.append("You missed")
	if int(monster.get("hp", 0)) <= 0:
		var reward := _roll_reward(monster)
		log.append("Defeated %s" % str(monster.get("id", "monster")))
		_emit_update()
		emit_signal("combat_ended", "won", reward)
		return

	var m_roll: Dictionary = _roll_attack(monster, player_stats)
	if m_roll["hit"]:
		var dmg_m: int = _calc_damage(monster, player_stats)
		player_stats["hp"] = int(player_stats.get("hp", 0)) - dmg_m
		log.append("Took %d" % dmg_m)
	else:
		log.append("Enemy missed")
	if int(player_stats.get("hp", 0)) <= 0:
		_emit_update()
		emit_signal("player_died")
		return
	_emit_update()

func try_run() -> void:
	# 도망 시도(실패 시 몬스터 무료 공격)
	if monster.is_empty():
		return
	var roll: int = _roll_d20() + _get_stat(player_stats, "level", 1)
	if roll >= RUN_DC:
		log.append("Escape successful")
		_emit_update()
		emit_signal("combat_ended", "ran", {})
	else:
		log.append("Failed to run")
		# Free hit on failed run
		var m_roll: Dictionary = _roll_attack(monster, player_stats, true)
		if m_roll["hit"]:
			var dmg_m: int = _calc_damage(monster, player_stats)
			player_stats["hp"] = int(player_stats.get("hp", 0)) - dmg_m
			log.append("Took %d" % dmg_m)
		else:
			log.append("Enemy missed")
		if int(player_stats.get("hp", 0)) <= 0:
			_emit_update()
			emit_signal("player_died")
			return
		_emit_update()

func get_log_text() -> String:
	return "\n".join(log)

func get_monster_hp() -> int:
	return int(monster.get("hp", 0))

func _emit_update() -> void:
	emit_signal("combat_updated", get_log_text())

func _roll_attack(attacker: Dictionary, defender: Dictionary, force_adv: bool = false) -> Dictionary:
	# 공격 판정: d20 + atk vs 10 + def
	var roll: int = _roll_d20()
	if force_adv:
		roll = max(roll, _roll_d20())
	var atk: int = _get_stat(attacker, "atk", 0)
	var def: int = _get_stat(defender, "def", 0)
	var total: int = roll + atk
	var dc: int = 10 + def
	if roll == 20:
		return {"hit": true, "crit": true, "roll": roll, "total": total, "dc": dc}
	if roll == 1:
		return {"hit": false, "crit": false, "roll": roll, "total": total, "dc": dc}
	return {"hit": total >= dc, "crit": false, "roll": roll, "total": total, "dc": dc}

func _calc_damage(attacker: Dictionary, defender: Dictionary) -> int:
	# 기본 피해 공식
	var atk: int = _get_stat(attacker, "atk", 1)
	var def: int = _get_stat(defender, "def", 0)
	return max(1, atk - def)

func _roll_reward(_monster: Dictionary) -> Dictionary:
	# 간단 드랍 테이블
	return {"gold": randi_range(1, 3)}

func _roll_d20() -> int:
	return randi_range(1, 20)

func _get_stat(src: Dictionary, key: String, default_value: int) -> int:
	if src.has(key):
		return int(src[key])
	return default_value
