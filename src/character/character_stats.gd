class_name CharacterStats
extends RefCounted
## 角色运行时属性：等级、经验、当前生命/魔力与加成。

signal changed
signal level_up(new_level: int)
signal died

var definition: CharacterDefinition
var level: int = 1
var experience: int = 0

var max_hp: int = 100
var hp: int = 100
var max_mp: int = 30
var mp: int = 30
var attack: int = 10
var defense: int = 0
var speed: int = 10

var bonus_attack: int = 0
var bonus_defense: int = 0
var bonus_speed: int = 0
var bonus_max_hp: int = 0
var bonus_max_mp: int = 0

var is_alive: bool = true


func _init(def: CharacterDefinition = null, start_level: int = 1) -> void:
	if def:
		apply_definition(def, start_level)


func apply_definition(def: CharacterDefinition, start_level: int = 1) -> void:
	definition = def
	level = maxi(start_level, 1)
	experience = 0
	_recalc_base_stats()
	hp = max_hp
	mp = max_mp
	is_alive = true
	changed.emit()


func get_display_name() -> String:
	return definition.display_name if definition else "角色"


func get_total_attack() -> int:
	return attack + bonus_attack


func get_total_defense() -> int:
	return defense + bonus_defense


func get_total_speed() -> int:
	return speed + bonus_speed


func get_total_max_hp() -> int:
	return max_hp + bonus_max_hp


func get_total_max_mp() -> int:
	return max_mp + bonus_max_mp


func get_exp_to_next_level() -> int:
	if definition == null:
		return 999999
	return definition.get_exp_for_level(level + 1)


func get_exp_progress() -> float:
	var need := get_exp_to_next_level()
	if need <= 0:
		return 1.0
	return clampf(float(experience) / float(need), 0.0, 1.0)


func add_exp(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	experience += amount
	while experience >= get_exp_to_next_level() and get_exp_to_next_level() > 0:
		experience -= get_exp_to_next_level()
		_level_up()
	changed.emit()


func take_damage(amount: int) -> int:
	if not is_alive:
		return 0
	var actual := maxi(amount - get_total_defense(), 1)
	hp = maxi(hp - actual, 0)
	if hp <= 0:
		is_alive = false
		died.emit()
	changed.emit()
	return actual


func heal(amount: int) -> int:
	if amount <= 0 or not is_alive:
		return 0
	var before := hp
	hp = mini(hp + amount, get_total_max_hp())
	changed.emit()
	return hp - before


func spend_mp(amount: int) -> bool:
	if amount <= 0 or mp < amount:
		return false
	mp -= amount
	changed.emit()
	return true


func restore_mp(amount: int) -> int:
	if amount <= 0 or not is_alive:
		return 0
	var before := mp
	mp = mini(mp + amount, get_total_max_mp())
	changed.emit()
	return mp - before


func add_bonus(attack_bonus: int = 0, defense_bonus: int = 0, speed_bonus: int = 0) -> void:
	bonus_attack += attack_bonus
	bonus_defense += defense_bonus
	bonus_speed += speed_bonus
	changed.emit()


func apply_equipment_bonuses(
	attack_bonus: int,
	defense_bonus: int,
	speed_bonus: int,
	hp_bonus: int,
	mp_bonus: int
) -> void:
	var old_total_hp := get_total_max_hp()
	var old_total_mp := get_total_max_mp()

	bonus_attack = attack_bonus
	bonus_defense = defense_bonus
	bonus_speed = speed_bonus
	bonus_max_hp = hp_bonus
	bonus_max_mp = mp_bonus

	hp += get_total_max_hp() - old_total_hp
	mp += get_total_max_mp() - old_total_mp
	hp = mini(hp, get_total_max_hp())
	mp = mini(mp, get_total_max_mp())
	changed.emit()


func clear_bonuses() -> void:
	apply_equipment_bonuses(0, 0, 0, 0, 0)


func to_battle_unit(player_controlled: bool = true) -> BattleUnit:
	var unit := BattleUnit.new(
		definition.id if definition else "hero",
		get_display_name(),
		0,
		get_total_max_hp(),
		get_total_attack(),
		get_total_speed(),
		player_controlled,
		get_total_max_mp()
	)
	unit.hp = hp
	unit.mp = mp
	unit.defense = get_total_defense()
	unit.is_alive = is_alive
	return unit


func get_summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = [
		"名称: %s" % get_display_name(),
		"等级: %d" % level,
		"经验: %d / %d" % [experience, get_exp_to_next_level()],
		"生命: %d / %d" % [hp, get_total_max_hp()],
		"魔力: %d / %d" % [mp, get_total_max_mp()],
		"攻击: %d (%d + %d)" % [get_total_attack(), attack, bonus_attack],
		"防御: %d (%d + %d)" % [get_total_defense(), defense, bonus_defense],
		"速度: %d (%d + %d)" % [get_total_speed(), speed, bonus_speed],
		"状态: %s" % ("存活" if is_alive else "倒下"),
	]
	if definition and definition.description.strip_edges() != "":
		lines.append("简介: %s" % definition.description)
	return lines


func _level_up() -> void:
	level += 1
	var old_max_hp := max_hp
	var old_max_mp := max_mp
	_recalc_base_stats()
	hp += max_hp - old_max_hp
	mp += max_mp - old_max_mp
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)
	level_up.emit(level)
	changed.emit()


func _recalc_base_stats() -> void:
	if definition == null:
		return
	var stats := definition.get_stat_at_level(level)
	max_hp = stats.max_hp
	max_mp = stats.max_mp
	attack = stats.attack
	defense = stats.defense
	speed = stats.speed
