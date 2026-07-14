class_name SkillAction
extends TurnAction
## 技能行动：消耗 MP，可按倍率造成伤害，并支持冷却。

var mp_cost: int = 0
var power_multiplier: float = 1.5
var cooldown_turns: int = 0
var current_cooldown: int = 0
## 对应 AnimatedSprite2D 的动画名，默认 attack2
var animation_name: StringName = &"attack2"
var animation_duration: float = 0.5


func _init(
	skill_id: String = "skill",
	skill_name: String = "技能",
	cost: int = 10,
	multiplier: float = 1.5,
	cooldown: int = 0,
	anim_name: StringName = &"attack2",
	anim_duration: float = 0.5
) -> void:
	id = skill_id
	display_name = skill_name
	target_type = TargetType.SINGLE_ENEMY
	mp_cost = cost
	power_multiplier = multiplier
	cooldown_turns = cooldown
	animation_name = anim_name
	animation_duration = anim_duration


static func from_definition(def: SkillDefinition) -> SkillAction:
	return SkillAction.new(
		def.id,
		def.display_name,
		def.mp_cost,
		def.power_multiplier,
		def.cooldown_turns,
		def.animation_name,
		def.animation_duration
	)


func get_button_text() -> String:
	var parts: PackedStringArray = [display_name]
	if mp_cost > 0:
		parts.append("MP%d" % mp_cost)
	if current_cooldown > 0:
		parts.append("CD%d" % current_cooldown)
	return " ".join(parts)


func is_ready(actor: TurnParticipant) -> bool:
	if actor == null or not actor.is_alive:
		return false
	if current_cooldown > 0:
		return false
	if actor is BattleUnit:
		return (actor as BattleUnit).mp >= mp_cost
	return true


func tick_cooldown() -> void:
	if current_cooldown > 0:
		current_cooldown -= 1


func can_execute(actor: TurnParticipant, target: TurnParticipant) -> bool:
	if not is_ready(actor):
		return false
	if target == null or not target.is_alive:
		return false
	if actor.team == target.team:
		return false
	return true


func execute(actor: TurnParticipant, target: TurnParticipant) -> Dictionary:
	if not can_execute(actor, target):
		return {"success": false, "message": "无法使用技能。"}

	if actor is BattleUnit and target is BattleUnit:
		var caster := actor as BattleUnit
		var defender := target as BattleUnit
		if not caster.spend_mp(mp_cost):
			return {"success": false, "message": "MP 不足。"}

		var raw_damage := int(round(caster.attack_power * power_multiplier))
		var defended := defender.is_defending
		var damage := defender.take_damage(raw_damage)

		if cooldown_turns > 0:
			current_cooldown = cooldown_turns

		var msg := "%s 使用【%s】攻击 %s，造成 %d 点伤害" % [
			caster.display_name, display_name, defender.display_name, damage
		]
		if defended:
			msg += "（被防御）"
		if not defender.is_alive:
			msg += "（%s 被击败）" % defender.display_name

		return {
			"success": true,
			"message": msg,
			"damage": damage,
			"defended": defended,
			"is_skill": true,
			"animation_name": String(animation_name),
			"animation_duration": animation_duration,
		}

	return {"success": false, "message": "无法使用技能。"}
