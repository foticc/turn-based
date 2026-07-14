extends Control
## 回合制框架测试场景控制器。

@onready var turn_manager: TurnManager = $TurnManager
@onready var status_label: Label = $MarginContainer/VBox/StatusLabel
@onready var player_list: VBoxContainer = $MarginContainer/VBox/TeamsHBox/PlayerPanel/PlayerList
@onready var enemy_list: VBoxContainer = $MarginContainer/VBox/TeamsHBox/EnemyPanel/EnemyList
@onready var action_panel: HBoxContainer = $MarginContainer/VBox/ActionPanel
@onready var target_panel: HBoxContainer = $MarginContainer/VBox/TargetPanel
@onready var log_label: RichTextLabel = $MarginContainer/VBox/LogLabel
@onready var restart_button: Button = $MarginContainer/VBox/RestartButton

var _units: Array[BattleUnit] = []
var _unit_labels: Dictionary = {}
var _command_menu := BattleCommandMenu.new()


func _ready() -> void:
	_command_menu.setup(action_panel, target_panel)
	_command_menu.action_chosen.connect(_on_command_action_chosen)
	_command_menu.no_targets.connect(_on_no_targets)
	_connect_signals()
	restart_button.pressed.connect(_start_test_battle)
	_start_test_battle()


func _connect_signals() -> void:
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.action_requested.connect(_on_action_requested)
	turn_manager.action_completed.connect(_on_action_completed)
	turn_manager.battle_finished.connect(_on_battle_finished)
	turn_manager.log_message.connect(_append_log)


const ALL_SKILL_PATHS: PackedStringArray = [
	"res://src/turn_based/skills/power_slash.tres",
	"res://src/turn_based/skills/fireball.tres",
	"res://src/turn_based/skills/smash.tres",
	"res://src/turn_based/skills/thrust.tres",
]


func _start_test_battle() -> void:
	_clear_ui()
	var hero := BattleUnit.new("hero", "勇者", 0, 100, 18, 12, true, 40)
	_add_all_skills(hero)

	var mage := BattleUnit.new("mage", "法师", 0, 70, 22, 9, true, 50)
	_add_all_skills(mage)

	var goblin := BattleUnit.new("goblin", "哥布林", 1, 50, 10, 11, false, 20)
	_add_all_skills(goblin)

	var orc := BattleUnit.new("orc", "兽人", 1, 90, 14, 7, false, 25)
	_add_all_skills(orc)

	_units = [hero, mage, goblin, orc]
	_build_unit_display()
	restart_button.disabled = true
	_append_log("[color=yellow]新战斗开始[/color]")
	turn_manager.start_battle(_units)


func _add_all_skills(unit: BattleUnit) -> void:
	for path in ALL_SKILL_PATHS:
		unit.add_skill(_load_skill(path))


func _load_skill(path: String) -> SkillAction:
	var def := load(path) as SkillDefinition
	return def.create_action()


func _build_unit_display() -> void:
	for unit in _units:
		var label := Label.new()
		label.text = _format_unit(unit)
		_unit_labels[unit.id] = label
		if unit.team == 0:
			player_list.add_child(label)
		else:
			enemy_list.add_child(label)


func _format_unit(unit: BattleUnit) -> String:
	var defend_tag := " [防御中]" if unit.is_defending else ""
	var status := "存活" if unit.is_alive else "倒下"
	return "%s  HP:%d/%d  MP:%d/%d  ATK:%d  SPD:%d%s  [%s]" % [
		unit.display_name, unit.hp, unit.max_hp, unit.mp, unit.max_mp,
		unit.attack_power, unit.speed, defend_tag, status
	]


func _refresh_unit_display() -> void:
	for unit in _units:
		if _unit_labels.has(unit.id):
			_unit_labels[unit.id].text = _format_unit(unit)


func _clear_ui() -> void:
	_command_menu.hide_all()
	for child in player_list.get_children():
		child.queue_free()
	for child in enemy_list.get_children():
		child.queue_free()
	_unit_labels.clear()
	log_label.clear()


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	status_label.text = "阶段: %s" % TurnManager.Phase.keys()[phase]


func _on_round_started(round_number: int) -> void:
	status_label.text = "第 %d 回合" % round_number


func _on_turn_started(participant: TurnParticipant) -> void:
	status_label.text = "当前行动: %s" % participant.display_name
	_refresh_unit_display()


func _on_action_requested(participant: TurnParticipant, _actions: Array) -> void:
	_command_menu.show_for(participant, _units)


func _on_command_action_chosen(action: TurnAction, target: TurnParticipant) -> void:
	turn_manager.submit_action(action, target)


func _on_no_targets() -> void:
	_append_log("[color=red]没有可用目标[/color]")


func _on_action_completed(_action: TurnAction, _actor: TurnParticipant, _result: Dictionary) -> void:
	_refresh_unit_display()


func _on_battle_finished(_winning_team: int) -> void:
	_command_menu.hide_all()
	restart_button.disabled = false
	_refresh_unit_display()


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
