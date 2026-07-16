extends CanvasLayer
## 遇敌战斗层：由大地图触发，结束后发出结果信号。

signal encounter_ended(player_won: bool)

@onready var turn_manager: TurnManager = $BattleRoot/TurnManager
@onready var player_team: Node2D = $BattleRoot/BattleField/Players
@onready var enemy_team: Node2D = $BattleRoot/BattleField/Enemies
@onready var status_label: Label = $BattleRoot/UI/MarginContainer/VBox/StatusLabel
@onready var action_panel: HBoxContainer = $BattleRoot/UI/MarginContainer/VBox/ActionPanel
@onready var target_panel: HBoxContainer = $BattleRoot/UI/MarginContainer/VBox/TargetPanel
@onready var log_label: RichTextLabel = $BattleRoot/UI/MarginContainer/VBox/LogLabel
@onready var title_label: Label = $BattleRoot/UI/MarginContainer/VBox/TitleLabel

const WARRIOR_BATTLE := preload("res://scenes/characters/warrior_battle.tscn")
const MONK_BATTLE := preload("res://scenes/characters/monk_battle.tscn")
const ALL_SKILLS: PackedStringArray = [
	"res://src/turn_based/skills/power_slash.tres",
	"res://src/turn_based/skills/fireball.tres",
	"res://src/turn_based/skills/smash.tres",
	"res://src/turn_based/skills/thrust.tres",
]

var _actors_by_unit: Dictionary = {}
var _last_target_id: String = ""
var _command_menu := BattleCommandMenu.new()
var _signals_connected: bool = false


func _ready() -> void:
	visible = false
	_command_menu.setup(action_panel, target_panel)
	_command_menu.action_chosen.connect(_on_command_action_chosen)
	_command_menu.no_targets.connect(_on_no_targets)
	_connect_signals()


func _connect_signals() -> void:
	if _signals_connected:
		return
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.action_requested.connect(_on_action_requested)
	turn_manager.action_executing.connect(_on_action_executing)
	turn_manager.action_completed.connect(_on_action_completed)
	turn_manager.battle_finished.connect(_on_battle_finished)
	turn_manager.log_message.connect(_append_log)
	_signals_connected = true


func start_encounter(world_enemy: WorldEnemy) -> void:
	_clear_battlefield()
	# 等上一场战斗单位真正清掉
	await get_tree().process_frame

	_actors_by_unit.clear()
	_last_target_id = ""
	log_label.clear()
	_command_menu.hide_all()

	var player := WARRIOR_BATTLE.instantiate() as BattleActor
	player.unit_id = "player"
	player.display_name = "勇者"
	player.team = 0
	player.max_hp = 120
	player.max_mp = 50
	player.attack_power = 18
	player.speed = 14
	player.player_controlled = true
	player.face_right = true
	player.position = Vector2(220, 280)
	player.scale = Vector2(0.85, 0.85)
	player.skills = _load_all_skills()
	player_team.add_child(player)

	var enemy := MONK_BATTLE.instantiate() as BattleActor
	enemy.unit_id = "enemy_%s" % world_enemy.get_instance_id()
	enemy.display_name = world_enemy.enemy_name
	enemy.team = 1
	enemy.max_hp = world_enemy.max_hp
	enemy.max_mp = world_enemy.max_mp
	enemy.attack_power = world_enemy.attack_power
	enemy.speed = world_enemy.speed
	enemy.player_controlled = false
	enemy.face_right = false
	enemy.position = Vector2(900, 280)
	enemy.scale = Vector2(0.85, 0.85)
	enemy.skills.clear()
	for skill_def in world_enemy.skills:
		if skill_def:
			enemy.skills.append(skill_def)
	enemy_team.add_child(enemy)

	title_label.text = "遇敌战斗：%s" % world_enemy.enemy_name
	visible = true

	var units: Array = []
	for actor in _get_all_actors():
		units.append(actor.create_battle_unit())
		_actors_by_unit[actor.battle_unit.id] = actor
		actor.sync_from_unit()
		actor.set_turn_active(false)

	_append_log("[color=yellow]与 %s 的战斗开始！[/color]" % world_enemy.enemy_name)
	turn_manager.start_battle(units)


func _load_all_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for path in ALL_SKILLS:
		var def := load(path) as SkillDefinition
		if def:
			result.append(def)
	return result


func _get_all_actors() -> Array[BattleActor]:
	var actors: Array[BattleActor] = []
	for child in player_team.get_children():
		if child is BattleActor:
			actors.append(child)
	for child in enemy_team.get_children():
		if child is BattleActor:
			actors.append(child)
	return actors


func _clear_battlefield() -> void:
	for child in player_team.get_children():
		child.queue_free()
	for child in enemy_team.get_children():
		child.queue_free()


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	status_label.text = "阶段: %s" % TurnManager.Phase.keys()[phase]


func _on_round_started(round_number: int) -> void:
	status_label.text = "第 %d 回合" % round_number


func _on_turn_started(participant: TurnParticipant) -> void:
	status_label.text = "当前行动: %s" % participant.display_name
	for actor in _actors_by_unit.values():
		actor.set_turn_active(actor.battle_unit == participant)


func _on_action_requested(participant: TurnParticipant, _actions: Array) -> void:
	_command_menu.show_for(participant, turn_manager.participants)


func _on_command_action_chosen(action: TurnAction, target: TurnParticipant) -> void:
	turn_manager.submit_action(action, target)


func _on_no_targets() -> void:
	_append_log("[color=red]没有可用目标[/color]")


func _on_action_executing(action: TurnAction, actor: TurnParticipant, target: TurnParticipant) -> void:
	_last_target_id = target.id if target else ""
	var actor_node: BattleActor = _actors_by_unit.get(actor.id)
	if actor_node == null:
		return
	if action is SkillAction:
		actor_node.play_skill(action as SkillAction)
	elif action.id == "attack":
		actor_node.play_attack()


func _on_action_completed(action: TurnAction, _actor: TurnParticipant, result: Dictionary) -> void:
	for actor_node in _actors_by_unit.values():
		actor_node.sync_from_unit()

	var dealt_damage: bool = result.get("damage", 0) > 0
	var is_offensive := action.id == "attack" or action is SkillAction
	if not is_offensive or _last_target_id == "" or not dealt_damage:
		return

	var target_node: BattleActor = _actors_by_unit.get(_last_target_id)
	if target_node == null:
		return
	if result.get("defended", false):
		target_node.play_defend_on_hit()
	else:
		target_node.play_hurt()


func _on_battle_finished(winning_team: int) -> void:
	_command_menu.hide_all()
	for actor in _actors_by_unit.values():
		actor.set_turn_active(false)

	var player_won := winning_team == 0
	if player_won:
		_append_log("[color=lime]胜利！返回地图[/color]")
	else:
		_append_log("[color=orange]战败…返回地图，敌人仍在[/color]")

	await get_tree().create_timer(1.0).timeout
	visible = false
	_clear_battlefield()
	encounter_ended.emit(player_won)


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
