class_name WorldEnemy
extends Area2D
## 大地图敌人：玩家进入范围后触发战斗。

signal encounter_requested(enemy: WorldEnemy)

@export var enemy_name: String = "敌人"
@export var max_hp: int = 70
@export var max_mp: int = 20
@export var attack_power: int = 12
@export var speed: int = 10
@export var skills: Array[SkillDefinition] = []

var _can_trigger: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = false
	_disable_visual_physics()
	var name_label := get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.text = enemy_name


func _disable_visual_physics() -> void:
	var visual := get_node_or_null("Visual")
	if visual is CollisionObject2D:
		(visual as CollisionObject2D).collision_layer = 0
		(visual as CollisionObject2D).collision_mask = 0


func set_trigger_enabled(enabled: bool) -> void:
	_can_trigger = enabled
	# body_entered 信号回调链里不能直接改 monitoring，需延迟设置。
	set_deferred("monitoring", enabled)


func _on_body_entered(body: Node2D) -> void:
	if not _can_trigger:
		return
	if body.is_in_group("player"):
		encounter_requested.emit(self)
