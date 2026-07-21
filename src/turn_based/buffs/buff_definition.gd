class_name BuffDefinition
extends Resource
## Buff 静态定义：持续回合、属性修正、图标。

@export var id: String = "buff"
@export var display_name: String = "Buff"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var duration_turns: int = 3
@export var max_stacks: int = 1
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_speed: int = 0
@export var tint_color: Color = Color(0.45, 0.85, 1.0)


func get_tooltip_text() -> String:
	var lines: PackedStringArray = [display_name]
	if description.strip_edges() != "":
		lines.append(description)
	if bonus_attack != 0:
		lines.append("攻击 %+d" % bonus_attack)
	if bonus_defense != 0:
		lines.append("防御 %+d" % bonus_defense)
	if bonus_speed != 0:
		lines.append("速度 %+d" % bonus_speed)
	lines.append("持续 %d 回合" % duration_turns)
	return "\n".join(lines)
