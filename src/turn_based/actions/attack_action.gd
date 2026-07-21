class_name AttackAction
extends TurnAction


func _init() -> void:
	id = "attack"
	display_name = "攻击"
	target_type = TargetType.SINGLE_ENEMY


func can_execute(actor: TurnParticipant, target: TurnParticipant) -> bool:
	return actor != null and target != null and target.is_alive and actor.team != target.team


func execute(actor: TurnParticipant, target: TurnParticipant) -> Dictionary:
	if not can_execute(actor, target):
		return {"success": false, "message": "攻击失败。"}

	if actor is BattleUnit and target is BattleUnit:
		var attacker := actor as BattleUnit
		var defender := target as BattleUnit
		var defended := defender.is_defending
		var damage := defender.take_damage(attacker.get_effective_attack())
		var msg := "%s 攻击 %s，造成 %d 点伤害" % [attacker.display_name, defender.display_name, damage]
		if defended:
			msg += "（被防御）"
		if not defender.is_alive:
			msg += "（%s 被击败）" % defender.display_name
		return {"success": true, "message": msg, "damage": damage, "defended": defended}

	return {"success": false, "message": "攻击失败。"}
