class_name SkillAction
extends TurnAction
## 技能行动：按 SkillDefinition 的效果结算（伤害 / Buff），支持主目标 + 其余随机。

var mp_cost: int = 0
var cooldown_turns: int = 0
var current_cooldown: int = 0
var description: String = ""
var skill_kind: SkillDefinition.SkillKind = SkillDefinition.SkillKind.DAMAGE
var effects: Array[SkillEffect] = []
var max_targets: int = 1

var animation_name: StringName = &"attack2"
var animation_duration: float = 0.5
var vfx_anchor: SkillDefinition.VfxAnchor = SkillDefinition.VfxAnchor.TARGET
var vfx_color: Color = Color(1.0, 0.55, 0.2, 0.85)
var vfx_duration: float = 0.45
var vfx_radius: float = 48.0

## 由 TurnManager 在 execute 前填好：主目标在前，其余为随机补足。
var _resolved_targets: Array = []


func _init(
	skill_id: String = "skill",
	skill_name: String = "技能",
	cost: int = 10,
	cooldown: int = 0,
	anim_name: StringName = &"attack2",
	anim_duration: float = 0.5,
	skill_description: String = ""
) -> void:
	id = skill_id
	display_name = skill_name
	target_type = TargetType.SINGLE_ENEMY
	mp_cost = cost
	cooldown_turns = cooldown
	animation_name = anim_name
	animation_duration = anim_duration
	description = skill_description


static func from_definition(def: SkillDefinition) -> SkillAction:
	var action := SkillAction.new(
		def.id,
		def.display_name,
		def.mp_cost,
		def.cooldown_turns,
		def.animation_name,
		def.animation_duration,
		def.description
	)
	action.target_type = def.target_type
	action.skill_kind = def.skill_kind
	action.max_targets = maxi(def.max_targets, 1)
	action.effects = def.effects.duplicate()
	action.vfx_anchor = def.vfx_anchor
	action.vfx_color = def.vfx_color
	action.vfx_duration = def.vfx_duration
	action.vfx_radius = def.vfx_radius
	return action


func get_button_text() -> String:
	var parts: PackedStringArray = [display_name]
	if max_targets > 1:
		parts.append("×%d" % max_targets)
	if mp_cost > 0:
		parts.append("MP%d" % mp_cost)
	if current_cooldown > 0:
		parts.append("CD%d" % current_cooldown)
	return " ".join(parts)


func get_tooltip_text() -> String:
	var lines: PackedStringArray = [display_name]
	if description.strip_edges() != "":
		lines.append(description)
	lines.append("类型: %s" % ("伤害" if skill_kind == SkillDefinition.SkillKind.DAMAGE else "增益"))
	if max_targets > 1:
		lines.append("目标: 点选主目标，其余随机（最多 %d）" % max_targets)
	lines.append("MP消耗: %d" % mp_cost)
	var resolved := _active_effects()
	for effect in resolved:
		match effect.effect_type:
			SkillEffect.EffectType.DAMAGE:
				lines.append("伤害倍率: %.1fx" % effect.power_multiplier)
			SkillEffect.EffectType.APPLY_BUFF:
				if effect.buff:
					lines.append("施加: %s" % effect.buff.display_name)
	if cooldown_turns > 0:
		lines.append("冷却: %d 回合" % cooldown_turns)
	if current_cooldown > 0:
		lines.append("剩余冷却: %d" % current_cooldown)
	return "\n".join(lines)


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


func get_resolved_targets() -> Array:
	return _resolved_targets


func clear_resolved_targets() -> void:
	_resolved_targets.clear()


func prepare_targets(
	actor: TurnParticipant,
	primary: TurnParticipant,
	all_participants: Array
) -> void:
	_resolved_targets = resolve_targets(actor, primary, all_participants)


func resolve_targets(
	actor: TurnParticipant,
	primary: TurnParticipant,
	all_participants: Array
) -> Array:
	if primary == null or not primary.is_alive:
		return []

	match target_type:
		TargetType.NONE, TargetType.SELF:
			return [actor] if actor != null and actor.is_alive else []
		TargetType.SINGLE_ENEMY, TargetType.SINGLE_ALLY, TargetType.ANY_SINGLE:
			return [primary]
		TargetType.MULTI_ENEMY, TargetType.MULTI_ALLY:
			pass
		_:
			return [primary]

	var pool: Array = []
	if actor is BattleUnit:
		pool = (actor as BattleUnit).get_valid_targets(self, all_participants)
	else:
		for p in all_participants:
			if p != null and p.is_alive:
				pool.append(p)

	var result: Array = []
	if primary in pool:
		result.append(primary)
	else:
		# 主目标若不在池中（异常），仍尝试纳入
		result.append(primary)

	var others: Array = []
	for p in pool:
		if p != primary:
			others.append(p)
	others.shuffle()

	var limit := maxi(max_targets, 1)
	for p in others:
		if result.size() >= limit:
			break
		result.append(p)
	return result


func can_execute(actor: TurnParticipant, target: TurnParticipant) -> bool:
	if not is_ready(actor):
		return false
	if target == null or not target.is_alive:
		return false
	match target_type:
		TargetType.SELF:
			return target == actor
		TargetType.SINGLE_ENEMY, TargetType.MULTI_ENEMY:
			return target.team != actor.team
		TargetType.SINGLE_ALLY, TargetType.MULTI_ALLY:
			return target.team == actor.team
		TargetType.ANY_SINGLE:
			return true
		TargetType.NONE:
			return true
		_:
			return target.team != actor.team


func execute(actor: TurnParticipant, target: TurnParticipant) -> Dictionary:
	if not can_execute(actor, target):
		return {"success": false, "message": "无法使用技能。"}
	if actor is not BattleUnit:
		return {"success": false, "message": "无法使用技能。"}

	var caster := actor as BattleUnit
	if not caster.spend_mp(mp_cost):
		return {"success": false, "message": "MP 不足。"}

	var targets: Array = _resolved_targets.duplicate()
	if targets.is_empty():
		targets = [target]

	_resolved_targets.clear()

	var total_damage := 0
	var any_defended := false
	var applied_buffs: PackedStringArray = []
	var messages: PackedStringArray = []
	var target_ids: PackedStringArray = []
	var damaged_ids: PackedStringArray = []

	for receiver_raw in targets:
		if receiver_raw == null or not (receiver_raw is BattleUnit):
			continue
		var receiver := receiver_raw as BattleUnit
		if not receiver.is_alive:
			continue
		target_ids.append(receiver.id)

		for effect in _active_effects():
			if effect == null:
				continue
			match effect.effect_type:
				SkillEffect.EffectType.DAMAGE:
					var raw := int(round(caster.get_effective_attack() * effect.power_multiplier))
					var defended := receiver.is_defending
					any_defended = any_defended or defended
					var dmg := receiver.take_damage(raw)
					total_damage += dmg
					damaged_ids.append(receiver.id)
					var dmg_msg := "%s 使用【%s】攻击 %s，造成 %d 点伤害" % [
						caster.display_name, display_name, receiver.display_name, dmg
					]
					if defended:
						dmg_msg += "（被防御）"
					messages.append(dmg_msg)
					if not receiver.is_alive:
						messages.append("%s 被击败" % receiver.display_name)
				SkillEffect.EffectType.APPLY_BUFF:
					if effect.buff == null:
						continue
					receiver.apply_buff(effect.buff)
					applied_buffs.append(effect.buff.display_name)
					messages.append("%s 使用【%s】，为 %s 施加「%s」" % [
						caster.display_name, display_name, receiver.display_name, effect.buff.display_name
					])

	if cooldown_turns > 0:
		current_cooldown = cooldown_turns

	var msg := "；".join(messages) if not messages.is_empty() else "%s 使用了【%s】" % [
		caster.display_name, display_name
	]

	return {
		"success": true,
		"message": msg,
		"damage": total_damage,
		"defended": any_defended,
		"is_skill": true,
		"skill_kind": skill_kind,
		"applied_buffs": applied_buffs,
		"target_ids": target_ids,
		"damaged_ids": damaged_ids,
		"animation_name": String(animation_name),
		"animation_duration": animation_duration,
		"vfx_anchor": vfx_anchor,
		"vfx_color": vfx_color,
		"vfx_duration": vfx_duration,
		"vfx_radius": vfx_radius,
	}


func _active_effects() -> Array[SkillEffect]:
	var result: Array[SkillEffect] = []
	for effect in effects:
		if effect:
			result.append(effect)
	return result
