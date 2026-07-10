class_name BattleActor
extends CharacterBody2D
## 战斗场景中的角色，绑定 BattleUnit 数据并驱动动画与 HP 显示。

@export var unit_id: String = "unit"
@export var display_name: String = "单位"
@export var team: int = 0
@export var max_hp: int = 100
@export var attack_power: int = 10
@export var speed: int = 10
@export var player_controlled: bool = false
@export var face_right: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var battle_unit: BattleUnit

var _hp_bar: ProgressBar
var _name_label: Label
var _base_modulate: Color = Color.WHITE


func _ready() -> void:
	_base_modulate = animated_sprite.modulate
	animated_sprite.flip_h = not face_right
	_setup_overhead_ui()
	play_idle()


func create_battle_unit() -> BattleUnit:
	battle_unit = BattleUnit.new(
		unit_id, display_name, team, max_hp, attack_power, speed, player_controlled
	)
	sync_from_unit()
	return battle_unit


func sync_from_unit() -> void:
	if battle_unit == null:
		return
	_name_label.text = "%s  %d/%d" % [battle_unit.display_name, battle_unit.hp, battle_unit.max_hp]
	_hp_bar.max_value = battle_unit.max_hp
	_hp_bar.value = battle_unit.hp
	if not battle_unit.is_alive:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
		play_idle()


func set_turn_active(active: bool) -> void:
	modulate = Color(1.2, 1.2, 1.0) if active and battle_unit.is_alive else Color.WHITE
	if not battle_unit.is_alive:
		modulate = Color(0.5, 0.5, 0.5, 0.8)


func play_idle() -> void:
	if _has_animation(&"idle"):
		animated_sprite.play(&"idle")


func play_attack() -> void:
	if _has_animation(&"attack1"):
		animated_sprite.play(&"attack1")
		await get_tree().create_timer(0.45).timeout
	elif _has_animation(&"attack"):
		animated_sprite.play(&"attack")
		await get_tree().create_timer(0.45).timeout
	else:
		var direction := -1.0 if animated_sprite.flip_h else 1.0
		var origin := position
		var tween := create_tween()
		tween.tween_property(self, "position", origin + Vector2(40.0 * direction, 0.0), 0.12)
		tween.tween_property(self, "position", origin, 0.12)
		await tween.finished
	play_idle()


func play_defend_on_hit() -> void:
	if _has_animation(&"guard"):
		animated_sprite.play(&"guard")
		await get_tree().create_timer(0.4).timeout
	else:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(0.7, 0.85, 1.0), 0.15)
		tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.15)
		await tween.finished
	play_idle()


func play_hurt() -> void:
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.4, 0.4), 0.1)
	tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.15)


func _setup_overhead_ui() -> void:
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-60, -90)
	_name_label.custom_minimum_size = Vector2(120, 20)
	add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(80, 12)
	_hp_bar.position = Vector2(-40, -70)
	_hp_bar.max_value = max_hp
	_hp_bar.value = max_hp
	add_child(_hp_bar)


func _has_animation(animation_name: StringName) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)
