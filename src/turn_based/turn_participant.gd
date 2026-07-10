class_name TurnParticipant
extends RefCounted
## 回合参与者基类，所有可行动单位需继承此类。

var id: String = ""
var display_name: String = "Unknown"
var team: int = 0
var speed: int = 10
var is_alive: bool = true


func can_act() -> bool:
	return is_alive


func on_turn_start() -> void:
	pass


func on_turn_end() -> void:
	pass


func get_actions() -> Array[TurnAction]:
	return []


func is_player_controlled() -> bool:
	return false


func get_valid_targets(_action: TurnAction, all_participants: Array) -> Array:
	return []
