class_name BattleActor
extends CharacterBody2D
## 战斗场景中的角色，绑定 BattleUnit 数据并驱动动画与 HP 显示。

@export_group("Unit Stats")
@export var unit_id: String = "unit"
@export var display_name: String = "单位"
@export var team: int = 0
@export var max_hp: int = 100
@export var max_mp: int = 30
@export var attack_power: int = 10
@export var speed: int = 10
@export var player_controlled: bool = false
@export var face_right: bool = true

@export_group("Skills")
## 在检查器中拖入 SkillDefinition 资源（.tres）
@export var skills: Array[SkillDefinition] = []

@export_group("Animations")
@export var idle_animation: StringName = &"idle"
@export var attack_animation: StringName = &"attack1"
@export var skill_animation: StringName = &"attack2"
@export var defend_animation: StringName = &"guard"
@export var attack_duration: float = 0.45
@export var skill_duration: float = 0.5
@export var defend_duration: float = 0.4

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var battle_unit: BattleUnit

var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _name_label: Label
var _base_modulate: Color = Color.WHITE


func _ready() -> void:
	_base_modulate = animated_sprite.modulate
	animated_sprite.flip_h = not face_right
	_setup_overhead_ui()
	play_idle()


func create_battle_unit() -> BattleUnit:
	battle_unit = BattleUnit.new(
		unit_id, display_name, team, max_hp, attack_power, speed, player_controlled, max_mp
	)
	for def in skills:
		if def:
			battle_unit.add_skill(def.create_action())
	sync_from_unit()
	return battle_unit


func sync_from_unit() -> void:
	if battle_unit == null:
		return
	_name_label.text = "%s  HP%d/%d  MP%d/%d" % [
		battle_unit.display_name,
		battle_unit.hp, battle_unit.max_hp,
		battle_unit.mp, battle_unit.max_mp,
	]
	_hp_bar.max_value = battle_unit.max_hp
	_hp_bar.value = battle_unit.hp
	_mp_bar.max_value = battle_unit.max_mp
	_mp_bar.value = battle_unit.mp
	if not battle_unit.is_alive:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
		play_idle()


func set_turn_active(active: bool) -> void:
	modulate = Color(1.2, 1.2, 1.0) if active and battle_unit.is_alive else Color.WHITE
	if not battle_unit.is_alive:
		modulate = Color(0.5, 0.5, 0.5, 0.8)


func play_idle() -> void:
	_play_named(idle_animation)


func play_attack() -> void:
	await play_animation(attack_animation, attack_duration)


## 播放技能动画。优先用技能自身配置，其次用角色默认 skill_animation。
func play_skill(action: SkillAction = null) -> void:
	var anim := skill_animation
	var duration := skill_duration
	if action:
		if action.animation_name != StringName():
			anim = action.animation_name
		if action.animation_duration > 0.0:
			duration = action.animation_duration
	await play_animation(anim, duration)


func play_defend_on_hit() -> void:
	await play_animation(defend_animation, defend_duration)


func play_hurt() -> void:
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.4, 0.4), 0.1)
	tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.15)


## 通用动画播放：有帧则播帧，没有则用冲刺 tween 兜底。
func play_animation(anim_name: StringName, duration: float = 0.45) -> void:
	if _has_animation(anim_name):
		animated_sprite.play(anim_name)
		await get_tree().create_timer(duration).timeout
	elif _has_animation(attack_animation):
		animated_sprite.play(attack_animation)
		await get_tree().create_timer(duration).timeout
	else:
		var direction := -1.0 if animated_sprite.flip_h else 1.0
		var origin := position
		var tween := create_tween()
		tween.tween_property(self, "position", origin + Vector2(40.0 * direction, 0.0), 0.12)
		tween.tween_property(self, "position", origin, 0.12)
		await tween.finished
	play_idle()


func _play_named(anim_name: StringName) -> void:
	if _has_animation(anim_name):
		animated_sprite.play(anim_name)


func _setup_overhead_ui() -> void:
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-70, -100)
	_name_label.custom_minimum_size = Vector2(140, 20)
	add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(80, 10)
	_hp_bar.position = Vector2(-40, -78)
	_hp_bar.max_value = max_hp
	_hp_bar.value = max_hp
	add_child(_hp_bar)

	_mp_bar = ProgressBar.new()
	_mp_bar.show_percentage = false
	_mp_bar.custom_minimum_size = Vector2(80, 8)
	_mp_bar.position = Vector2(-40, -66)
	_mp_bar.max_value = max_mp
	_mp_bar.value = max_mp
	_mp_bar.modulate = Color(0.45, 0.7, 1.0)
	add_child(_mp_bar)


func _has_animation(animation_name: StringName) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)
