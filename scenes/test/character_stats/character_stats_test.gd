extends Control
## 角色属性功能测试场景。

const WARRIOR_PATH := "res://src/character/definitions/warrior.tres"
const MAGE_PATH := "res://src/character/definitions/mage.tres"

@onready var stats_panel: CharacterStatsPanel = $Margin/HBox/CharacterStatsPanel
@onready var log_label: RichTextLabel = $Margin/HBox/Side/LogLabel
@onready var switch_button: Button = $Margin/HBox/Side/SwitchButton
@onready var exp_button: Button = $Margin/HBox/Side/ExpButton
@onready var damage_button: Button = $Margin/HBox/Side/DamageButton
@onready var heal_button: Button = $Margin/HBox/Side/HealButton
@onready var mp_button: Button = $Margin/HBox/Side/MpButton
@onready var bonus_button: Button = $Margin/HBox/Side/BonusButton
@onready var reset_button: Button = $Margin/HBox/Side/ResetButton

var _stats: CharacterStats
var _using_warrior := true


func _ready() -> void:
	switch_button.pressed.connect(_on_switch_pressed)
	exp_button.pressed.connect(_on_exp_pressed)
	damage_button.pressed.connect(_on_damage_pressed)
	heal_button.pressed.connect(_on_heal_pressed)
	mp_button.pressed.connect(_on_mp_pressed)
	bonus_button.pressed.connect(_on_bonus_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	_setup_character(true)


func _setup_character(use_warrior: bool) -> void:
	_using_warrior = use_warrior
	var path := WARRIOR_PATH if use_warrior else MAGE_PATH
	var def := load(path) as CharacterDefinition
	_stats = CharacterStats.new(def, 1)
	_stats.level_up.connect(_on_level_up)
	_stats.died.connect(_on_died)
	_stats.changed.connect(_on_stats_changed)
	stats_panel.bind(_stats)
	_append_log("[color=yellow]切换角色：%s[/color]" % def.display_name)


func _on_switch_pressed() -> void:
	log_label.clear()
	_setup_character(not _using_warrior)


func _on_exp_pressed() -> void:
	_stats.add_exp(40)
	_append_log("获得 40 经验")


func _on_damage_pressed() -> void:
	var damage := _stats.take_damage(18)
	_append_log("受到 %d 点伤害" % damage)


func _on_heal_pressed() -> void:
	var healed := _stats.heal(25)
	_append_log("恢复 %d 点生命" % healed)


func _on_mp_pressed() -> void:
	if _stats.spend_mp(8):
		_append_log("消耗 8 MP")
	else:
		var restored := _stats.restore_mp(15)
		_append_log("MP 不足，改为恢复 %d MP" % restored)


func _on_bonus_pressed() -> void:
	_stats.add_bonus(3, 2, 1)
	_append_log("获得临时加成：攻击+3 防御+2 速度+1")


func _on_reset_pressed() -> void:
	log_label.clear()
	_setup_character(_using_warrior)
	_append_log("[color=cyan]角色已重置[/color]")


func _on_level_up(new_level: int) -> void:
	_append_log("[color=lime]升级！当前等级 %d[/color]" % new_level)


func _on_died() -> void:
	_append_log("[color=red]角色倒下[/color]")


func _on_stats_changed() -> void:
	pass


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
