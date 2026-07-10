class_name DefendAction
extends TurnAction


func _init() -> void:
	id = "defend"
	display_name = "防御"
	target_type = TargetType.SELF


func can_execute(actor: TurnParticipant, _target: TurnParticipant) -> bool:
	return actor != null and actor.is_alive


func execute(actor: TurnParticipant, _target: TurnParticipant) -> Dictionary:
	if not can_execute(actor, null):
		return {"success": false, "message": "防御失败。"}

	if actor is BattleUnit:
		var unit := actor as BattleUnit
		unit.is_defending = true
		return {"success": true, "message": "%s 进入防御姿态" % unit.display_name}

	return {"success": false, "message": "防御失败。"}
