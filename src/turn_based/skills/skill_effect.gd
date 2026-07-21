class_name SkillEffect
extends Resource
## 技能单条效果：伤害或施加 Buff（可在 SkillDefinition.effects 中组合）。

enum EffectType {
	DAMAGE,
	APPLY_BUFF,
}

@export var effect_type: EffectType = EffectType.DAMAGE
@export var power_multiplier: float = 1.5
@export var buff: BuffDefinition
