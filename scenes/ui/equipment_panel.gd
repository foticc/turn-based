class_name EquipmentPanel
extends PanelContainer
## 装备栏面板：槽位在场景中预置，各自可设不同背景；脚本只刷新装备内容。

signal slot_clicked(slot: ItemDefinition.EquipSlot)
signal unequip_requested(slot: ItemDefinition.EquipSlot)

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var slots_grid: GridContainer = $Margin/VBox/SlotsGrid

var equipment: Equipment
var _selected_slot: ItemDefinition.EquipSlot = ItemDefinition.EquipSlot.NONE
var _slot_uis: Dictionary = {} # EquipSlot -> EquipmentSlotUI


func _ready() -> void:
	_collect_slot_uis()
	_refresh()


func _collect_slot_uis() -> void:
	_slot_uis.clear()
	for child in slots_grid.get_children():
		if child is not EquipmentSlotUI:
			continue
		var slot_ui := child as EquipmentSlotUI
		if slot_ui.equip_slot == ItemDefinition.EquipSlot.NONE:
			push_warning("EquipmentSlotUI 未设置 equip_slot: %s" % slot_ui.name)
			continue
		_slot_uis[slot_ui.equip_slot] = slot_ui
		if not slot_ui.slot_clicked.is_connected(_on_slot_clicked):
			slot_ui.slot_clicked.connect(_on_slot_clicked)
		if not slot_ui.unequip_requested.is_connected(_on_unequip_requested):
			slot_ui.unequip_requested.connect(_on_unequip_requested)


func bind(target_equipment: Equipment) -> void:
	if equipment != null and equipment.changed.is_connected(_refresh):
		equipment.changed.disconnect(_refresh)

	equipment = target_equipment
	if equipment == null:
		return

	if not equipment.changed.is_connected(_refresh):
		equipment.changed.connect(_refresh)

	_refresh()


func get_selected_slot() -> ItemDefinition.EquipSlot:
	return _selected_slot


func _on_slot_clicked(slot: ItemDefinition.EquipSlot) -> void:
	ItemTooltip.hide_tooltip()
	_selected_slot = slot
	slot_clicked.emit(slot)
	_refresh()


func _on_unequip_requested(slot: ItemDefinition.EquipSlot) -> void:
	ItemTooltip.hide_tooltip()
	_selected_slot = slot
	_refresh()
	unequip_requested.emit(slot)


func _refresh() -> void:
	for slot in _slot_uis.keys():
		var slot_ui: EquipmentSlotUI = _slot_uis[slot]
		var item: ItemDefinition = null
		if equipment:
			item = equipment.get_equipped(slot)
		var selected :bool = slot == _selected_slot
		if item:
			slot_ui.set_item(item, selected)
		else:
			slot_ui.clear_slot(selected)
