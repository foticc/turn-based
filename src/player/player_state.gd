class_name PlayerState
extends RefCounted
## 玩家进度数据层：属性 / 装备 / 背包 / 技能树 + 用例（装备、使用、解锁）。
## UI 与场景只应调用这里的方法，不要直接散落改各个子系统。

signal action_logged(message: String)
signal changed

const DEFAULT_CHARACTER := "res://src/character/definitions/warrior.tres"
const DEFAULT_SKILL_TREE := "res://src/skill_tree/trees/warrior_skill_tree.tres"

var items: ItemDatabase
var stats: CharacterStats
var equipment: Equipment
var inventory: Inventory
var skill_tree: SkillTree


static func create_default(
	level: int = 3,
	skill_points: int = 3,
	inventory_capacity: int = 24
) -> PlayerState:
	var state := PlayerState.new()
	state.setup(
		ItemDatabase.load_default(),
		load(DEFAULT_CHARACTER) as CharacterDefinition,
		load(DEFAULT_SKILL_TREE) as SkillTreeDefinition,
		level,
		skill_points,
		inventory_capacity
	)
	return state


func setup(
	item_db: ItemDatabase,
	character_def: CharacterDefinition,
	tree_def: SkillTreeDefinition,
	level: int = 3,
	skill_points: int = 3,
	inventory_capacity: int = 24
) -> void:
	items = item_db if item_db else ItemDatabase.load_default()
	items.rebuild_index()

	stats = CharacterStats.new(character_def, level)
	equipment = Equipment.new()
	inventory = Inventory.new(inventory_capacity)
	skill_tree = SkillTree.new(tree_def, skill_points)
	_sync_equipment_bonuses()

	if not equipment.changed.is_connected(_on_equipment_changed):
		equipment.changed.connect(_on_equipment_changed)
	if not inventory.changed.is_connected(_on_subsystem_changed):
		inventory.changed.connect(_on_subsystem_changed)
	if not stats.changed.is_connected(_on_subsystem_changed):
		stats.changed.connect(_on_subsystem_changed)
	if not skill_tree.changed.is_connected(_on_subsystem_changed):
		skill_tree.changed.connect(_on_subsystem_changed)


func get_item(item_id: String) -> ItemDefinition:
	return items.get_item(item_id) if items else null


func grant_item(item_id: String, amount: int = 1, silent: bool = false) -> Dictionary:
	var item := get_item(item_id)
	if item == null:
		var msg := "[color=red]物品库中不存在：%s[/color]" % item_id
		if not silent:
			_log(msg)
		return {"success": false, "message": msg, "overflow": amount}

	var overflow := inventory.add_item(item, amount)
	if overflow > 0:
		var msg := "[color=red]背包已满，%s 有 %d 个未能放入[/color]" % [item.display_name, overflow]
		if not silent:
			_log(msg)
		return {"success": false, "message": msg, "overflow": overflow}

	var msg_ok := "获得 %s x%d" % [item.display_name, amount]
	if not silent:
		_log(msg_ok)
	return {"success": true, "message": msg_ok, "overflow": 0}


func grant_starting_kit() -> void:
	for item_id in [
		"iron_sword",
		"bronze_crown",
		"leather_armor",
		"traveler_boots",
		"warrior_belt",
		"jade_pendant",
		"silver_necklace",
		"swift_bracelet",
	]:
		grant_item(item_id, 1, true)
	grant_item("swift_bracelet", 1, true)
	grant_item("health_potion", 3, true)


func use_inventory_slot(index: int) -> Dictionary:
	var slot_data := inventory.get_slot(index)
	if slot_data.is_empty():
		var empty_msg := "[color=gray]该格子为空[/color]"
		_log(empty_msg)
		return {"success": false, "message": empty_msg}

	var item: ItemDefinition = slot_data.item
	if item.is_equipment():
		return _equip_from_inventory(index, item)

	if item.item_type == ItemDefinition.ItemType.CONSUMABLE:
		var result := inventory.use_item_at(index)
		if result.success:
			var healed := 0
			if result.heal > 0:
				healed = stats.heal(result.heal)
			var msg := "[color=green]%s，恢复 %d HP[/color]" % [result.message, healed]
			_log(msg)
			result.message = msg
			result.healed = healed
		else:
			_log("[color=red]%s[/color]" % result.message)
		return result

	var fail := "[color=orange]%s 无法使用[/color]" % item.display_name
	_log(fail)
	return {"success": false, "message": fail}


func unequip_slot(slot: ItemDefinition.EquipSlot) -> Dictionary:
	if slot == ItemDefinition.EquipSlot.NONE:
		var msg := "[color=gray]请先选中一个装备槽[/color]"
		_log(msg)
		return {"success": false, "message": msg}

	var item := equipment.unequip(slot)
	if item == null:
		var msg := "[color=gray]该槽位没有装备[/color]"
		_log(msg)
		return {"success": false, "message": msg}

	var overflow := inventory.add_item(item, 1)
	if overflow > 0:
		equipment.equip(item) # changed → _sync_equipment_bonuses
		var msg := "[color=red]背包已满，无法卸下 %s[/color]" % item.display_name
		_log(msg)
		return {"success": false, "message": msg}

	var ok := "卸下了 %s（%s）" % [item.display_name, ItemDefinition.get_slot_display_name(slot)]
	_log(ok)
	return {"success": true, "message": ok, "item": item}


func unlock_skill_node(node_id: String) -> Dictionary:
	if skill_tree == null:
		return {"success": false, "message": "未绑定技能树"}
	if skill_tree.is_unlocked(node_id):
		return {"success": false, "message": "已解锁", "already": true}
	if skill_tree.unlock(node_id):
		var node := skill_tree.definition.get_node(node_id) if skill_tree.definition else null
		var node_name := node.display_name if node else node_id
		var msg := "[color=lime]解锁成功：%s[/color]" % node_name
		_log(msg)
		return {"success": true, "message": msg, "node_id": node_id}

	var reason := _skill_unlock_fail_reason(node_id)
	var fail := "[color=orange]解锁失败：%s[/color]" % reason
	_log(fail)
	return {"success": false, "message": fail, "reason": reason}


## 从当前 RPG 进度生成战斗快照（含已解锁技能）。
func create_battle_unit(unit_id: String = "player") -> BattleUnit:
	var unit := stats.to_battle_unit(true)
	unit.id = unit_id
	if skill_tree:
		for skill_def in skill_tree.get_unlocked_skills():
			if skill_def:
				unit.add_skill(skill_def.create_action())
	return unit


## 战斗结束后把 HP/MP 写回数据层。
func apply_battle_result(unit: BattleUnit) -> void:
	if unit == null or stats == null:
		return
	stats.hp = clampi(unit.hp, 0, stats.get_total_max_hp())
	stats.mp = clampi(unit.mp, 0, stats.get_total_max_mp())
	stats.is_alive = stats.hp > 0
	if not stats.is_alive:
		# 战败后在大地图保留 1 HP，避免永久倒地无法继续测
		stats.hp = 1
		stats.is_alive = true
	stats.changed.emit()


func _equip_from_inventory(index: int, item: ItemDefinition) -> Dictionary:
	var result := equipment.equip(item) # changed → _sync_equipment_bonuses
	if not result.success:
		_log("[color=red]%s[/color]" % result.message)
		return result

	inventory.remove_from_slot(index, 1)
	var replaced: ItemDefinition = result.get("replaced")
	var slot: ItemDefinition.EquipSlot = result.get("slot")
	var slot_name := ItemDefinition.get_slot_display_name(slot)
	if replaced:
		inventory.add_item(replaced, 1)

	var msg: String
	if replaced:
		msg = "[color=lime]%s 装备 %s，换下 %s[/color]" % [slot_name, item.display_name, replaced.display_name]
	else:
		msg = "[color=lime]%s 装备了 %s[/color]" % [slot_name, item.display_name]
	_log(msg)
	result.message = msg
	return result


func _sync_equipment_bonuses() -> void:
	if stats == null or equipment == null:
		return
	var bonus := equipment.get_bonus_summary()
	stats.apply_equipment_bonuses(
		bonus.attack,
		bonus.defense,
		bonus.speed,
		bonus.max_hp,
		bonus.max_mp
	)


func _skill_unlock_fail_reason(node_id: String) -> String:
	if skill_tree == null or skill_tree.definition == null:
		return "技能树无效"
	var node_def := skill_tree.definition.get_node(node_id)
	if node_def == null:
		return "节点不存在"
	if skill_tree.available_points < node_def.point_cost:
		return "技能点不足"
	for prereq in node_def.prerequisite_ids:
		if not skill_tree.is_unlocked(prereq):
			var prereq_node := skill_tree.definition.get_node(prereq)
			var prereq_name := prereq_node.display_name if prereq_node else prereq
			return "需要先解锁：%s" % prereq_name
	return "无法解锁"


func _on_equipment_changed() -> void:
	# 外部若直接改 equipment（测试场景），也保持属性同步。
	_sync_equipment_bonuses()
	changed.emit()


func _on_subsystem_changed() -> void:
	changed.emit()


func _log(message: String) -> void:
	action_logged.emit(message)
