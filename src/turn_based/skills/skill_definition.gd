class_name SkillDefinition
extends Resource
## 可在编辑器中配置的技能数据。

@export var id: String = "skill"
@export var display_name: String = "技能"
@export var mp_cost: int = 10
@export var power_multiplier: float = 1.5
@export var cooldown_turns: int = 0
## AnimatedSprite2D 动画名，例如 attack2
@export var animation_name: StringName = &"attack2"
@export var animation_duration: float = 0.5


func create_action() -> SkillAction:
	return SkillAction.from_definition(self)
