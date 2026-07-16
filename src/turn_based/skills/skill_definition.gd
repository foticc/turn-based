class_name SkillDefinition
extends Resource
## 可在编辑器中配置的技能数据。

@export var id: String = "skill"
@export var display_name: String = "技能"
@export_multiline var description: String = ""
@export var mp_cost: int = 10
@export var power_multiplier: float = 1.5
@export var cooldown_turns: int = 0
## AnimatedSprite2D 动画名，例如 attack2
@export var animation_name: StringName = &"attack2"
@export var animation_duration: float = 0.5


func create_action() -> SkillAction:
	return SkillAction.from_definition(self)


func get_tooltip_text() -> String:
	var lines: PackedStringArray = [display_name]
	if description.strip_edges() != "":
		lines.append(description)
	lines.append("MP消耗: %d" % mp_cost)
	lines.append("伤害倍率: %.1fx" % power_multiplier)
	if cooldown_turns > 0:
		lines.append("冷却: %d 回合" % cooldown_turns)
	else:
		lines.append("冷却: 无")
	return "\n".join(lines)
