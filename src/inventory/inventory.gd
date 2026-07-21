class_name Inventory
extends RefCounted
## 物品栏数据：固定格子与堆叠逻辑（纯数据，不依赖场景树）。

signal changed
signal item_used(slot_index: int, item: ItemDefinition, result: Dictionary)

var capacity: int = 16
var _slots: Array = []


func _init(p_capacity: int = 16) -> void:
	capacity = maxi(p_capacity, 1)
	_reset_slots()


func _reset_slots() -> void:
	_slots.clear()
	_slots.resize(capacity)
	for i in range(capacity):
		_slots[i] = null


func get_slot(index: int) -> Dictionary:
	if not _is_valid_index(index):
		return {}
	var slot: Variant = _slots[index]
	if slot == null:
		return {}
	return slot


func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if slot != null and slot.item.id == item_id:
			total += slot.quantity
	return total


func add_item(item: ItemDefinition, amount: int = 1) -> int:
	if item == null or amount <= 0:
		return amount

	var remaining := amount

	for i in range(capacity):
		var slot: Variant = _slots[i]
		if slot == null:
			continue
		if slot.item.id != item.id:
			continue
		if slot.quantity >= item.max_stack:
			continue

		var can_add := mini(item.max_stack - slot.quantity, remaining)
		slot.quantity += can_add
		remaining -= can_add
		if remaining <= 0:
			changed.emit()
			return 0

	for i in range(capacity):
		if _slots[i] != null:
			continue

		var add_count := mini(item.max_stack, remaining)
		_slots[i] = {"item": item, "quantity": add_count}
		remaining -= add_count
		if remaining <= 0:
			changed.emit()
			return 0

	changed.emit()
	return remaining


func remove_from_slot(index: int, amount: int = 1) -> bool:
	if not _is_valid_index(index) or _slots[index] == null or amount <= 0:
		return false

	var slot: Dictionary = _slots[index]
	if slot.quantity < amount:
		return false

	slot.quantity -= amount
	if slot.quantity <= 0:
		_slots[index] = null

	changed.emit()
	return true


func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var remaining := amount
	for i in range(capacity):
		var slot: Variant = _slots[i]
		if slot == null or slot.item.id != item_id:
			continue

		var remove_count := mini(slot.quantity, remaining)
		slot.quantity -= remove_count
		remaining -= remove_count
		if slot.quantity <= 0:
			_slots[i] = null
		if remaining <= 0:
			changed.emit()
			return true

	return remaining <= 0


func use_item_at(index: int) -> Dictionary:
	if not _is_valid_index(index) or _slots[index] == null:
		return {"success": false, "message": "该格子没有物品。"}

	var slot: Dictionary = _slots[index]
	var item: ItemDefinition = slot.item
	var result := {"success": false, "message": "无法使用该物品。", "heal": 0}

	match item.item_type:
		ItemDefinition.ItemType.CONSUMABLE:
			result.success = true
			result.heal = item.heal_amount
			result.message = "使用了 %s" % item.display_name
			slot.quantity -= 1
			if slot.quantity <= 0:
				_slots[index] = null
		_:
			result.message = "%s 无法直接使用。" % item.display_name
			return result

	item_used.emit(index, item, result)
	changed.emit()
	return result


func clear() -> void:
	_reset_slots()
	changed.emit()


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < capacity
