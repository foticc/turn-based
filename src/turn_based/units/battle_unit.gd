class_name BattleUnit
extends TurnParticipant
## 可战斗的单位，包含 HP、攻防与基础行动。

var max_hp: int = 100
var hp: int = 100
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
	controlled_by_player: bool = false
) -> void:
	id = unit_id
	display_name = unit_name
	team = unit_team
	max_hp = unit_hp
	hp = unit_hp
	attack_power = unit_attack
	speed = unit_speed
	player_controlled = controlled_by_player
	_setup_actions()


func _setup_actions() -> void:
	_actions = [
		AttackAction.new(),
		DefendAction.new(),
	]


func get_actions() -> Array[TurnAction]:
	return _actions


func is_player_controlled() -> bool:
	return player_controlled


func on_turn_start() -> void:
	is_defending = false


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
