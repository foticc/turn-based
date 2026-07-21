class_name TurnAction
extends RefCounted
## 回合行动基类。

enum TargetType {
	NONE,
	SELF,
	SINGLE_ENEMY,
	SINGLE_ALLY,
	ANY_SINGLE,
	## 玩家点主目标，其余从候选中随机补足（见 SkillAction.max_targets）
	MULTI_ENEMY,
	MULTI_ALLY,
}


var id: String = ""
var display_name: String = "Action"
var target_type: TargetType = TargetType.NONE


func get_button_text() -> String:
	return display_name


func can_execute(_actor: TurnParticipant, _target: TurnParticipant) -> bool:
	return true


func execute(_actor: TurnParticipant, _target: TurnParticipant) -> Dictionary:
	return {"success": true, "message": ""}
