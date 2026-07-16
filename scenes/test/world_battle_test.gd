extends Node2D
## 大地图探索 + 遇敌战斗测试场景。

## 死区比例：角色可在镜头内自由移动，靠近边缘时相机才跟过去。
@export_range(0.05, 0.45, 0.01) var camera_deadzone_ratio: float = 0.28

@onready var map_root: Node2D = $NoviceVillage
@onready var player: CharacterBody2D = $Entities/Player
@onready var enemies_root: Node2D = $Entities/Enemies
@onready var camera: Camera2D = $Camera2D
@onready var encounter_battle = $EncounterBattle
@onready var tip_label: Label = $UI/TipLabel

var _in_battle: bool = false
var _current_enemy: WorldEnemy = null


func _ready() -> void:
	player.add_to_group("player")
	_apply_camera_limits(camera)
	camera.global_position = player.global_position
	camera.make_current()

	for child in enemies_root.get_children():
		if child is WorldEnemy:
			var enemy := child as WorldEnemy
			enemy.encounter_requested.connect(_on_enemy_encounter_requested)
			var name_label := enemy.get_node_or_null("NameLabel") as Label
			if name_label:
				name_label.text = enemy.enemy_name

	encounter_battle.encounter_ended.connect(_on_encounter_ended)
	tip_label.text = "点击地面移动，碰到敌人进入战斗"


func _physics_process(_delta: float) -> void:
	if _in_battle:
		return
	_update_camera_follow()


func _update_camera_follow() -> void:
	var half_view := get_viewport().get_visible_rect().size * 0.5 / camera.zoom
	var dead := half_view * camera_deadzone_ratio
	var cam_pos := camera.global_position
	var player_pos := player.global_position
	var offset := player_pos - cam_pos
	var next := cam_pos

	if offset.x > dead.x:
		next.x = player_pos.x - dead.x
	elif offset.x < -dead.x:
		next.x = player_pos.x + dead.x

	if offset.y > dead.y:
		next.y = player_pos.y - dead.y
	elif offset.y < -dead.y:
		next.y = player_pos.y + dead.y

	camera.global_position = next


func _apply_camera_limits(cam: Camera2D) -> void:
	var bounds := _get_map_bounds()
	if bounds.size == Vector2.ZERO:
		return
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	cam.limit_smoothed = true


func _get_map_bounds() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for child in map_root.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			if layer.tile_set == null:
				continue
			var used := layer.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var tile_size := Vector2(layer.tile_set.tile_size)
			var top_left := layer.to_global(Vector2(used.position) * tile_size)
			var bottom_right := layer.to_global(Vector2(used.position + used.size) * tile_size)
			var layer_rect := Rect2(top_left, bottom_right - top_left)
			if not has_bounds:
				bounds = layer_rect
				has_bounds = true
			else:
				bounds = bounds.merge(layer_rect)
	return bounds if has_bounds else Rect2()


func _on_enemy_encounter_requested(enemy: WorldEnemy) -> void:
	if _in_battle:
		return
	_in_battle = true
	_current_enemy = enemy

	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)

	for child in enemies_root.get_children():
		if child is WorldEnemy:
			(child as WorldEnemy).set_trigger_enabled(false)

	encounter_battle.start_encounter(enemy)


func _on_encounter_ended(player_won: bool) -> void:
	var fought := _current_enemy
	_current_enemy = null

	if player_won and is_instance_valid(fought):
		tip_label.text = "击败了 %s！" % fought.enemy_name
		fought.queue_free()
	elif not player_won:
		tip_label.text = "战败了…敌人仍在，稍后再试"
	else:
		tip_label.text = "点击地面移动，碰到敌人进入战斗"

	# 短暂无敌，避免战败后立刻再次触发
	await get_tree().create_timer(0.8).timeout

	_in_battle = false
	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(true)

	for child in enemies_root.get_children():
		if child is WorldEnemy:
			(child as WorldEnemy).set_trigger_enabled(true)

	if enemies_root.get_child_count() == 0:
		tip_label.text = "全部敌人已清除！"
