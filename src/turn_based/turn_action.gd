class_name TurnAction
extends RefCounted
## 回合行动基类。

enum TargetType {
	NONE,
	SELF,
	SINGLE_ENEMY,
	SINGLE_ALLY,
	ANY_SINGLE,
}


var id: String = ""
var display_name: String = "Action"
var target_type: TargetType = TargetType.NONE


func can_execute(_actor: TurnParticipant, _target: TurnParticipant) -> bool:
	return true


func execute(_actor: TurnParticipant, _target: TurnParticipant) -> Dictionary:
	return {"success": true, "message": ""}
