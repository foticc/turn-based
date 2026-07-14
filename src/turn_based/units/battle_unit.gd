class_name BattleUnit
extends TurnParticipant
## 可战斗的单位，包含 HP、MP、攻防与基础行动。

var max_hp: int = 100
var hp: int = 100
var max_mp: int = 30
var mp: int = 30
var attack_power: int = 10
var defense: int = 0
var is_defending: bool = false
var player_controlled: bool = false

var _actions: Array[TurnAction] = []


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


func on_turn_start() -> void:
	is_defending = false
	for action in _actions:
		if action is SkillAction:
			(action as SkillAction).tick_cooldown()


func spend_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	return true


func restore_mp(amount: int) -> void:
	mp = mini(mp + amount, max_mp)


func take_damage(amount: int) -> int:
	var reduction := defense if is_defending else 0
	var actual := maxi(amount - reduction, 1)
	hp = maxi(hp - actual, 0)
	if hp <= 0:
		is_alive = false
	return actual


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


func get_valid_targets(action: TurnAction, all_participants: Array) -> Array:
	var targets: Array = []
	for p in all_participants:
		if not p.is_alive or p == self:
			continue
		match action.target_type:
			TurnAction.TargetType.SINGLE_ENEMY:
				if p.team != team:
					targets.append(p)
			TurnAction.TargetType.SINGLE_ALLY:
				if p.team == team:
					targets.append(p)
			TurnAction.TargetType.ANY_SINGLE:
				targets.append(p)
	return targets
