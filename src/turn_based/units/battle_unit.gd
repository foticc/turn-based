class_name BattleUnit
extends TurnParticipant
## 可战斗的单位，包含 HP、MP、攻防、Buff 与基础行动。

signal buffs_changed

var max_hp: int = 100
var hp: int = 100
var max_mp: int = 30
var mp: int = 30
var attack_power: int = 10
var defense: int = 0
var is_defending: bool = false
var player_controlled: bool = false

var _actions: Array[TurnAction] = []
var _buffs: Array[BuffInstance] = []


func _init(
	unit_id: String = "",
	unit_name: String = "Unit",
	unit_team: int = 0,
	unit_hp: int = 100,
	unit_attack: int = 10,
	unit_speed: int = 10,
	controlled_by_player: bool = false,
	unit_mp: int = 30
) -> void:
	id = unit_id
	display_name = unit_name
	team = unit_team
	max_hp = unit_hp
	hp = unit_hp
	max_mp = unit_mp
	mp = unit_mp
	attack_power = unit_attack
	speed = unit_speed
	player_controlled = controlled_by_player
	_setup_actions()


func _setup_actions() -> void:
	_actions = [
		AttackAction.new(),
		DefendAction.new(),
	]


func add_skill(skill: SkillAction) -> void:
	_actions.append(skill)


func get_actions() -> Array[TurnAction]:
	return _actions


func get_basic_actions() -> Array[TurnAction]:
	var basics: Array[TurnAction] = []
	for action in _actions:
		if not action is SkillAction:
			basics.append(action)
	return basics


func get_skills() -> Array[SkillAction]:
	var skills: Array[SkillAction] = []
	for action in _actions:
		if action is SkillAction:
			skills.append(action)
	return skills


func has_skills() -> bool:
	return not get_skills().is_empty()


func get_usable_actions() -> Array[TurnAction]:
	var usable: Array[TurnAction] = []
	for action in _actions:
		if action is SkillAction:
			if not (action as SkillAction).is_ready(self):
				continue
		usable.append(action)
	return usable


func is_player_controlled() -> bool:
	return player_controlled


func get_buffs() -> Array[BuffInstance]:
	return _buffs


func get_effective_attack() -> int:
	var bonus := 0
	for buff in _buffs:
		bonus += buff.get_bonus_attack()
	return attack_power + bonus


func get_effective_defense() -> int:
	var bonus := 0
	for buff in _buffs:
		bonus += buff.get_bonus_defense()
	return defense + bonus


func get_effective_speed() -> int:
	var bonus := 0
	for buff in _buffs:
		bonus += buff.get_bonus_speed()
	return speed + bonus


func apply_buff(def: BuffDefinition) -> void:
	if def == null:
		return
	for existing in _buffs:
		if existing.get_id() == def.id:
			existing.remaining_turns = def.duration_turns
			if def.max_stacks > 1:
				existing.stacks = mini(existing.stacks + 1, def.max_stacks)
			buffs_changed.emit()
			return
	_buffs.append(BuffInstance.new(def))
	buffs_changed.emit()


## 每回合开始：清除防御，技能冷却 -1。
func on_round_start() -> void:
	is_defending = false
	for action in _actions:
		if action is SkillAction:
			(action as SkillAction).tick_cooldown()


## 每回合结束：Buff 持续回合 -1（持续 3 回合 = 经过 3 次回合结束）。
func on_round_end() -> void:
	_tick_buffs()


func on_turn_start() -> void:
	# 兼容旧调用；真正的回合开始逻辑在 on_round_start。
	pass


func _tick_buffs() -> void:
	if _buffs.is_empty():
		return
	var kept: Array[BuffInstance] = []
	for buff in _buffs:
		if not buff.tick():
			kept.append(buff)
	_buffs = kept
	buffs_changed.emit()


func spend_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	return true


func restore_mp(amount: int) -> void:
	mp = mini(mp + amount, max_mp)


func take_damage(amount: int) -> int:
	var reduction := get_effective_defense() if is_defending else 0
	var actual := maxi(amount - reduction, 1)
	hp = maxi(hp - actual, 0)
	if hp <= 0:
		is_alive = false
	return actual


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


func get_valid_targets(action: TurnAction, all_participants: Array) -> Array:
	var targets: Array = []
	match action.target_type:
		TurnAction.TargetType.NONE, TurnAction.TargetType.SELF:
			if is_alive:
				targets.append(self)
			return targets
		_:
			pass

	for p in all_participants:
		if not p.is_alive:
			continue
		match action.target_type:
			TurnAction.TargetType.SINGLE_ENEMY, TurnAction.TargetType.MULTI_ENEMY:
				if p != self and p.team != team:
					targets.append(p)
			TurnAction.TargetType.SINGLE_ALLY, TurnAction.TargetType.MULTI_ALLY:
				if p.team == team:
					targets.append(p)
			TurnAction.TargetType.ANY_SINGLE:
				targets.append(p)
	return targets
