class_name BattleActor
extends CharacterBody2D
## 战斗场景中的角色：绑定 BattleUnit，驱动动画、HP/MP 与 Buff 图标。

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
var _buff_row: HBoxContainer
var _turn_marker: Label
var _base_modulate: Color = Color.WHITE
var _turn_pulse: Tween


func _ready() -> void:
	_base_modulate = animated_sprite.modulate
	animated_sprite.flip_h = not face_right
	_setup_overhead_ui()
	play_idle()
	if battle_unit:
		_connect_buff_signal()
		sync_from_unit()


func create_battle_unit() -> BattleUnit:
	battle_unit = BattleUnit.new(
		unit_id, display_name, team, max_hp, attack_power, speed, player_controlled, max_mp
	)
	for def in skills:
		if def:
			battle_unit.add_skill(def.create_action())
	_connect_buff_signal()
	sync_from_unit()
	return battle_unit


func bind_unit(unit: BattleUnit, face_to_right: bool = true) -> void:
	if battle_unit != null and battle_unit.buffs_changed.is_connected(_on_buffs_changed):
		battle_unit.buffs_changed.disconnect(_on_buffs_changed)

	battle_unit = unit
	if unit:
		unit_id = unit.id
		display_name = unit.display_name
		team = unit.team
		max_hp = unit.max_hp
		max_mp = unit.max_mp
		attack_power = unit.attack_power
		speed = unit.speed
		player_controlled = unit.player_controlled
	face_right = face_to_right
	if animated_sprite:
		animated_sprite.flip_h = not face_right
	_connect_buff_signal()
	if is_inside_tree():
		sync_from_unit()


func _connect_buff_signal() -> void:
	if battle_unit == null:
		return
	if not battle_unit.buffs_changed.is_connected(_on_buffs_changed):
		battle_unit.buffs_changed.connect(_on_buffs_changed)


func sync_from_unit() -> void:
	if battle_unit == null or _name_label == null:
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
	_refresh_buff_icons()
	if not battle_unit.is_alive:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
		play_idle()


func set_turn_active(active: bool) -> void:
	if battle_unit == null:
		return
	if _turn_pulse:
		_turn_pulse.kill()
		_turn_pulse = null

	if not battle_unit.is_alive:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
		if _turn_marker:
			_turn_marker.visible = false
		return

	if active:
		modulate = Color(1.35, 1.25, 0.75)
		if _turn_marker:
			_turn_marker.visible = true
			_turn_marker.modulate = Color(1, 0.9, 0.3)
			_turn_pulse = create_tween().set_loops()
			_turn_pulse.tween_property(_turn_marker, "position:y", -138.0, 0.35)
			_turn_pulse.tween_property(_turn_marker, "position:y", -128.0, 0.35)
	else:
		modulate = Color.WHITE
		if _turn_marker:
			_turn_marker.visible = false
			_turn_marker.position.y = -128.0


func play_idle() -> void:
	_play_named(idle_animation)


func play_attack() -> void:
	await play_animation(attack_animation, attack_duration)


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


func _on_buffs_changed() -> void:
	_refresh_buff_icons()


func _refresh_buff_icons() -> void:
	if _buff_row == null or battle_unit == null:
		return
	for child in _buff_row.get_children():
		child.queue_free()

	for buff in battle_unit.get_buffs():
		var icon := _make_buff_icon(buff)
		_buff_row.add_child(icon)


func _make_buff_icon(buff: BuffInstance) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(22, 22)
	panel.tooltip_text = "%s\n剩余 %d 回合" % [buff.get_display_name(), buff.remaining_turns]

	var style := StyleBoxFlat.new()
	style.bg_color = buff.definition.tint_color if buff.definition else Color(0.4, 0.7, 1.0)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	if buff.definition and buff.definition.icon:
		var tex := TextureRect.new()
		tex.texture = buff.definition.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(18, 18)
		panel.add_child(tex)
	else:
		var label := Label.new()
		label.text = buff.get_display_name().left(1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		panel.add_child(label)

	if buff.remaining_turns > 0:
		var turns := Label.new()
		turns.text = str(buff.remaining_turns)
		turns.add_theme_font_size_override("font_size", 9)
		turns.position = Vector2(12, 10)
		panel.add_child(turns)

	return panel


func _play_named(anim_name: StringName) -> void:
	if _has_animation(anim_name):
		animated_sprite.play(anim_name)


func _setup_overhead_ui() -> void:
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-70, -118)
	_name_label.custom_minimum_size = Vector2(140, 20)
	add_child(_name_label)

	_turn_marker = Label.new()
	_turn_marker.text = "▼"
	_turn_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_marker.position = Vector2(-20, -128)
	_turn_marker.custom_minimum_size = Vector2(40, 20)
	_turn_marker.add_theme_font_size_override("font_size", 22)
	_turn_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_turn_marker.visible = false
	_turn_marker.z_index = 5
	add_child(_turn_marker)

	_buff_row = HBoxContainer.new()
	_buff_row.position = Vector2(-40, -100)
	_buff_row.custom_minimum_size = Vector2(80, 22)
	_buff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_buff_row)

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
