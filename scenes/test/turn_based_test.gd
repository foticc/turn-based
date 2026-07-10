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
var _pending_action: TurnAction = null
var _unit_labels: Dictionary = {}


func _ready() -> void:
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


func _start_test_battle() -> void:
	_clear_ui()
	_units = [
		BattleUnit.new("hero", "勇者", 0, 100, 18, 12, true),
		BattleUnit.new("mage", "法师", 0, 70, 22, 9, true),
		BattleUnit.new("goblin", "哥布林", 1, 50, 10, 11, false),
		BattleUnit.new("orc", "兽人", 1, 90, 14, 7, false),
	]
	_build_unit_display()
	action_panel.visible = false
	target_panel.visible = false
	restart_button.disabled = true
	_append_log("[color=yellow]新战斗开始[/color]")
	turn_manager.start_battle(_units)


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
	return "%s  HP:%d/%d  ATK:%d  SPD:%d%s  [%s]" % [
		unit.display_name, unit.hp, unit.max_hp, unit.attack_power, unit.speed, defend_tag, status
	]


func _refresh_unit_display() -> void:
	for unit in _units:
		if _unit_labels.has(unit.id):
			_unit_labels[unit.id].text = _format_unit(unit)


func _clear_ui() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for child in enemy_list.get_children():
		child.queue_free()
	for child in action_panel.get_children():
		child.queue_free()
	for child in target_panel.get_children():
		child.queue_free()
	_unit_labels.clear()
	log_label.clear()
	_pending_action = null


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	status_label.text = "阶段: %s" % TurnManager.Phase.keys()[phase]


func _on_round_started(round_number: int) -> void:
	status_label.text = "第 %d 回合" % round_number


func _on_turn_started(participant: TurnParticipant) -> void:
	status_label.text = "当前行动: %s" % participant.display_name
	_refresh_unit_display()


func _on_action_requested(participant: TurnParticipant, actions: Array) -> void:
	_pending_action = null
	_clear_action_buttons()
	_clear_target_buttons()
	action_panel.visible = true
	target_panel.visible = false

	for action in actions:
		var btn := Button.new()
		btn.text = action.display_name
		btn.pressed.connect(_on_action_button_pressed.bind(action, participant))
		action_panel.add_child(btn)


func _on_action_button_pressed(action: TurnAction, participant: TurnParticipant) -> void:
	_pending_action = action
	_clear_action_buttons()

	if action.target_type == TurnAction.TargetType.NONE or action.target_type == TurnAction.TargetType.SELF:
		action_panel.visible = false
		turn_manager.submit_action(action, participant)
		return

	var targets := participant.get_valid_targets(action, _units)
	if targets.is_empty():
		_append_log("[color=red]没有可用目标[/color]")
		action_panel.visible = true
		_on_action_requested(participant, participant.get_actions())
		return

	target_panel.visible = true
	for target in targets:
		var btn := Button.new()
		btn.text = target.display_name
		btn.pressed.connect(_on_target_button_pressed.bind(action, target))
		target_panel.add_child(btn)


func _on_target_button_pressed(action: TurnAction, target: TurnParticipant) -> void:
	action_panel.visible = false
	target_panel.visible = false
	_clear_target_buttons()
	turn_manager.submit_action(action, target)


func _on_action_completed(_action: TurnAction, _actor: TurnParticipant, _result: Dictionary) -> void:
	_refresh_unit_display()


func _on_battle_finished(_winning_team: int) -> void:
	action_panel.visible = false
	target_panel.visible = false
	restart_button.disabled = false
	_refresh_unit_display()


func _clear_action_buttons() -> void:
	for child in action_panel.get_children():
		child.queue_free()


func _clear_target_buttons() -> void:
	for child in target_panel.get_children():
		child.queue_free()


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
