class_name CharacterDefinition
extends Resource
## 角色基础属性配置，可在编辑器中调整成长曲线。

@export var id: String = "hero"
@export var display_name: String = "勇者"
@export_multiline var description: String = ""

@export_group("基础属性（1级）")
@export var base_max_hp: int = 100
@export var base_max_mp: int = 30
@export var base_attack: int = 10
@export var base_defense: int = 2
@export var base_speed: int = 10

@export_group("每级成长")
@export var hp_growth: int = 12
@export var mp_growth: int = 4
@export var attack_growth: int = 2
@export var defense_growth: int = 1
@export var speed_growth: int = 1

@export_group("经验")
@export var exp_base: int = 100
@export var exp_growth: float = 1.25


func get_stat_at_level(level: int) -> Dictionary:
	var lv := maxi(level, 1)
	var extra := lv - 1
	return {
		"max_hp": base_max_hp + hp_growth * extra,
		"max_mp": base_max_mp + mp_growth * extra,
		"attack": base_attack + attack_growth * extra,
		"defense": base_defense + defense_growth * extra,
		"speed": base_speed + speed_growth * extra,
	}


func get_exp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(round(exp_base * pow(exp_growth, level - 2)))
