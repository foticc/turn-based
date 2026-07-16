class_name Equipment
extends RefCounted
## 角色装备管理：穿戴、卸下，并把属性加成应用到 CharacterStats。

signal changed
signal equipped(slot: ItemDefinition.EquipSlot, item: ItemDefinition)
signal unequipped(slot: ItemDefinition.EquipSlot, item: ItemDefinition)

var stats: CharacterStats
var _slots: Dictionary = {} # EquipSlot -> ItemDefinition


func bind(target_stats: CharacterStats) -> void:
	stats = target_stats
	_slots.clear()
	_recalc_bonuses()


func get_equipped(slot: ItemDefinition.EquipSlot) -> ItemDefinition:
	return _slots.get(slot)


func get_all_slots() -> Array:
	return [
		ItemDefinition.EquipSlot.WEAPON,
		ItemDefinition.EquipSlot.HELMET,
		ItemDefinition.EquipSlot.CLOTHES,
		ItemDefinition.EquipSlot.SHOES,
		ItemDefinition.EquipSlot.BELT,
		ItemDefinition.EquipSlot.JADE_PENDANT,
		ItemDefinition.EquipSlot.NECKLACE,
		ItemDefinition.EquipSlot.BRACELET_LEFT,
		ItemDefinition.EquipSlot.BRACELET_RIGHT,
	]


func equip(item: ItemDefinition) -> Dictionary:
	if item == null or not item.is_equipment():
		return {"success": false, "message": "该物品无法装备。"}
	if stats == null:
		return {"success": false, "message": "未绑定角色。"}

	var slot := _resolve_equip_slot(item)
	if slot == ItemDefinition.EquipSlot.NONE:
		return {"success": false, "message": "无效的装备部位。"}

	var old_item: ItemDefinition = _slots.get(slot)
	_slots[slot] = item
	_recalc_bonuses()
	equipped.emit(slot, item)
	changed.emit()
	return {
		"success": true,
		"message": "装备了 %s" % item.display_name,
		"slot": slot,
		"replaced": old_item,
	}


func unequip(slot: ItemDefinition.EquipSlot) -> ItemDefinition:
	if not _slots.has(slot):
		return null
	var item: ItemDefinition = _slots[slot]
	_slots.erase(slot)
	_recalc_bonuses()
	unequipped.emit(slot, item)
	changed.emit()
	return item


func get_bonus_summary() -> Dictionary:
	var result := {
		"attack": 0,
		"defense": 0,
		"speed": 0,
		"max_hp": 0,
		"max_mp": 0,
	}
	for item in _slots.values():
		if item == null:
			continue
		result.attack += item.bonus_attack
		result.defense += item.bonus_defense
		result.speed += item.bonus_speed
		result.max_hp += item.bonus_max_hp
		result.max_mp += item.bonus_max_mp
	return result


func _resolve_equip_slot(item: ItemDefinition) -> ItemDefinition.EquipSlot:
	if item.equip_slot != ItemDefinition.EquipSlot.BRACELET:
		return item.equip_slot

	# 手镯：优先空闲槽，都满则替换左手镯
	if not _slots.has(ItemDefinition.EquipSlot.BRACELET_LEFT):
		return ItemDefinition.EquipSlot.BRACELET_LEFT
	if not _slots.has(ItemDefinition.EquipSlot.BRACELET_RIGHT):
		return ItemDefinition.EquipSlot.BRACELET_RIGHT
	return ItemDefinition.EquipSlot.BRACELET_LEFT


func _recalc_bonuses() -> void:
	if stats == null:
		return
	var bonus := get_bonus_summary()
	stats.apply_equipment_bonuses(
		bonus.attack,
		bonus.defense,
		bonus.speed,
		bonus.max_hp,
		bonus.max_mp
	)
