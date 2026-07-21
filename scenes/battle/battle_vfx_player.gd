class_name BattleVfxPlayer
extends Node2D
## 战斗特效播放：按锚点挂到施法者、目标（可多个）或战场中央。

@export var battle_center: Vector2 = Vector2(560, 280)


func play_for_skill(
	action: SkillAction,
	caster_actor: Node2D,
	target_actors: Array = []
) -> void:
	if action == null:
		return
	var anchor := action.vfx_anchor

	match anchor:
		SkillDefinition.VfxAnchor.CASTER:
			_spawn_at(action, caster_actor if caster_actor else self, Vector2.ZERO if caster_actor else battle_center)
		SkillDefinition.VfxAnchor.TARGET:
			var hosts: Array = target_actors
			if hosts.is_empty() and caster_actor:
				hosts = [caster_actor]
			if hosts.is_empty():
				_spawn_at(action, self, battle_center)
			else:
				for host in hosts:
					if host is Node2D:
						_spawn_at(action, host as Node2D, Vector2.ZERO)
		SkillDefinition.VfxAnchor.BATTLE_CENTER, SkillDefinition.VfxAnchor.FULLSCREEN:
			_spawn_at(action, self, battle_center, anchor == SkillDefinition.VfxAnchor.FULLSCREEN)

	await get_tree().create_timer(maxf(action.vfx_duration, 0.1)).timeout


func _spawn_at(action: SkillAction, host: Node2D, local_pos: Vector2, fullscreen: bool = false) -> void:
	var vfx := _spawn_placeholder(action.vfx_color, action.vfx_radius, fullscreen)
	host.add_child(vfx)
	vfx.position = local_pos
	get_tree().create_timer(maxf(action.vfx_duration, 0.1)).timeout.connect(
		func() -> void:
			if is_instance_valid(vfx):
				vfx.queue_free()
	)


func _spawn_placeholder(color: Color, radius: float, fullscreen: bool) -> Node2D:
	var root := Node2D.new()
	root.z_index = 20

	if fullscreen:
		var flash := ColorRect.new()
		flash.color = Color(color.r, color.g, color.b, 0.35)
		flash.size = Vector2(1280, 720)
		flash.position = Vector2(-640, -360)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(flash)
		var tw := flash.create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.35)
	else:
		var ring := Polygon2D.new()
		ring.color = color
		ring.polygon = _circle_points(maxi(int(radius), 16), 20)
		root.add_child(ring)
		var tw := ring.create_tween()
		tw.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.35)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)

	return root


func _circle_points(radius: int, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
