class_name SkillDefinition
extends Resource
## 可在编辑器中配置的技能数据。

enum SkillKind {
	DAMAGE,
	BUFF,
}

enum VfxAnchor {
	CASTER, ## 施法者身上
	TARGET, ## 目标身上
	BATTLE_CENTER, ## 战场中央
	FULLSCREEN, ## 全屏层
}

@export var id: String = "skill"
@export var display_name: String = "技能"
@export_multiline var description: String = ""
@export var skill_kind: SkillKind = SkillKind.DAMAGE
@export var target_type: TurnAction.TargetType = TurnAction.TargetType.SINGLE_ENEMY
## 多目标技能实际命中上限（含主目标）。单体技能保持 1。
@export_range(1, 8) var max_targets: int = 1
@export var mp_cost: int = 10
@export var cooldown_turns: int = 0
@export var effects: Array[SkillEffect] = []

@export_group("表现")
## AnimatedSprite2D 动画名，例如 attack2
@export var animation_name: StringName = &"attack2"
@export var animation_duration: float = 0.5
@export var vfx_anchor: VfxAnchor = VfxAnchor.TARGET
@export var vfx_color: Color = Color(1.0, 0.55, 0.2, 0.85)
@export var vfx_duration: float = 0.45
@export var vfx_radius: float = 48.0


func create_action() -> SkillAction:
	return SkillAction.from_definition(self)


func get_tooltip_text() -> String:
	var lines: PackedStringArray = [display_name]
	if description.strip_edges() != "":
		lines.append(description)
	lines.append("类型: %s" % ("伤害" if skill_kind == SkillKind.DAMAGE else "增益"))
	if max_targets > 1:
		lines.append("目标: 主目标 + 随机，最多 %d 人" % max_targets)
	lines.append("MP消耗: %d" % mp_cost)
	for effect in effects:
		if effect == null:
			continue
		match effect.effect_type:
			SkillEffect.EffectType.DAMAGE:
				lines.append("伤害倍率: %.1fx" % effect.power_multiplier)
			SkillEffect.EffectType.APPLY_BUFF:
				if effect.buff:
					lines.append("施加: %s（%d 回合）" % [
						effect.buff.display_name, effect.buff.duration_turns
					])
	if cooldown_turns > 0:
		lines.append("冷却: %d 回合" % cooldown_turns)
	else:
		lines.append("冷却: 无")
	return "\n".join(lines)
