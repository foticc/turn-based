class_name CharacterSheetPanel
extends PanelContainer
## 角色综合面板：属性 + 装备 + 背包（分区不拆逻辑）。

signal action_logged(message: String)
signal inventory_slot_selected(index: int)
signal equipment_slot_selected(slot: ItemDefinition.EquipSlot)

@onready var stats_panel: CharacterStatsPanel = $Margin/VBox/TopRow/CharacterStatsPanel
@onready var equipment_panel: EquipmentPanel = $Margin/VBox/TopRow/EquipmentPanel
@onready var inventory_panel: InventoryPanel = $Margin/VBox/InventoryPanel
@onready var tip_label: Label = $Margin/VBox/TipLabel

var stats: CharacterStats
var equipment: Equipment
var inventory: Inventory


func _ready() -> void:
	tip_label.text = "悬停查看详情 | 背包：双击/右键使用 | 装备槽：双击/右键卸下"
	inventory_panel.use_requested.connect(_on_inventory_use_requested)
	inventory_panel.slot_selected.connect(_on_inventory_slot_selected)
	equipment_panel.slot_clicked.connect(_on_equipment_slot_clicked)
	equipment_panel.unequip_requested.connect(_on_equipment_unequip_requested)


func bind(
	target_stats: CharacterStats,
	target_equipment: Equipment,
	target_inventory: Inventory
) -> void:
	stats = target_stats
	equipment = target_equipment
	inventory = target_inventory

	if equipment and stats:
		equipment.bind(stats)

	stats_panel.bind(stats)
	equipment_panel.bind(equipment)
	inventory_panel.bind(inventory)
	inventory_panel.set_title("背包")


func get_selected_inventory_index() -> int:
	return inventory_panel.get_selected_index()


func get_selected_equipment_slot() -> ItemDefinition.EquipSlot:
	return equipment_panel.get_selected_slot()


func use_selected_inventory_item() -> void:
	var index := inventory_panel.get_selected_index()
	if index < 0:
		_log("[color=gray]请先选中背包中的物品[/color]")
		return
	_use_inventory_item(index)


func unequip_selected_slot() -> void:
	var slot := equipment_panel.get_selected_slot()
	if slot == ItemDefinition.EquipSlot.NONE:
		_log("[color=gray]请先选中一个装备槽[/color]")
		return
	_unequip_slot(slot)


func _unequip_slot(slot: ItemDefinition.EquipSlot) -> void:
	if equipment == null or inventory == null:
		return
	if slot == ItemDefinition.EquipSlot.NONE:
		return

	var item := equipment.unequip(slot)
	if item == null:
		_log("[color=gray]该槽位没有装备[/color]")
		return

	var overflow := inventory.add_item(item, 1)
	if overflow > 0:
		equipment.equip(item)
		_log("[color=red]背包已满，无法卸下 %s[/color]" % item.display_name)
	else:
		_log("卸下了 %s（%s）" % [item.display_name, ItemDefinition.get_slot_display_name(slot)])


func _on_inventory_use_requested(index: int) -> void:
	_use_inventory_item(index)


func _on_inventory_slot_selected(index: int) -> void:
	inventory_slot_selected.emit(index)


func _on_equipment_slot_clicked(slot: ItemDefinition.EquipSlot) -> void:
	equipment_slot_selected.emit(slot)
	var item := equipment.get_equipped(slot) if equipment else null
	var slot_name := ItemDefinition.get_slot_display_name(slot)
	if item:
		_log("选中装备槽：%s（%s）" % [slot_name, item.display_name])
	else:
		_log("选中装备槽：%s（空）" % slot_name)


func _on_equipment_unequip_requested(slot: ItemDefinition.EquipSlot) -> void:
	_unequip_slot(slot)


func _use_inventory_item(index: int) -> void:
	if inventory == null:
		return

	var slot_data := inventory.get_slot(index)
	if slot_data.is_empty():
		_log("[color=gray]该格子为空[/color]")
		return

	var item: ItemDefinition = slot_data.item
	if item.is_equipment():
		_equip_item_at(index, item)
		return

	if item.item_type == ItemDefinition.ItemType.CONSUMABLE:
		var result := inventory.use_item_at(index)
		if result.success:
			var healed := 0
			if result.heal > 0 and stats:
				healed = stats.heal(result.heal)
			_log("[color=green]%s，恢复 %d HP[/color]" % [result.message, healed])
		else:
			_log("[color=red]%s[/color]" % result.message)
		return

	_log("[color=orange]%s 无法使用[/color]" % item.display_name)


func _equip_item_at(index: int, item: ItemDefinition) -> void:
	if equipment == null or inventory == null:
		return

	var result := equipment.equip(item)
	if not result.success:
		_log("[color=red]%s[/color]" % result.message)
		return

	inventory.remove_from_slot(index, 1)
	var replaced: ItemDefinition = result.get("replaced")
	var slot: ItemDefinition.EquipSlot = result.get("slot")
	var slot_name := ItemDefinition.get_slot_display_name(slot)
	if replaced:
		inventory.add_item(replaced, 1)
		_log("[color=lime]%s 装备 %s，换下 %s[/color]" % [slot_name, item.display_name, replaced.display_name])
	else:
		_log("[color=lime]%s 装备了 %s[/color]" % [slot_name, item.display_name])


func _log(message: String) -> void:
	action_logged.emit(message)
