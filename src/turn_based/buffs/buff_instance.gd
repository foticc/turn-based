class_name BuffInstance
extends RefCounted
## Buff 运行时实例。

var definition: BuffDefinition
var remaining_turns: int = 1
var stacks: int = 1


func _init(def: BuffDefinition = null, starting_stacks: int = 1) -> void:
	definition = def
	if def:
		remaining_turns = def.duration_turns
		stacks = clampi(starting_stacks, 1, maxi(def.max_stacks, 1))


func get_id() -> String:
	return definition.id if definition else ""


func get_display_name() -> String:
	return definition.display_name if definition else "Buff"


func get_bonus_attack() -> int:
	return (definition.bonus_attack if definition else 0) * stacks


func get_bonus_defense() -> int:
	return (definition.bonus_defense if definition else 0) * stacks


func get_bonus_speed() -> int:
	return (definition.bonus_speed if definition else 0) * stacks


func tick() -> bool:
	remaining_turns -= 1
	return remaining_turns <= 0
