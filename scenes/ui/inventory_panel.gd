class_name InventoryPanel
extends PanelContainer
## 物品栏面板，显示格子网格并与 Inventory 数据绑定。

signal slot_selected(index: int)

const SLOT_SCENE := preload("res://scenes/ui/inventory_slot_ui.tscn")

@export var columns: int = 8

@onready var grid: GridContainer = $MarginContainer/VBox/GridContainer
@onready var title_label: Label = $MarginContainer/VBox/TitleLabel

var inventory: Inventory
var _slot_uis: Array[PanelContainer] = []
var _selected_index: int = -1


func bind(target_inventory: Inventory) -> void:
	if inventory != null and inventory.changed.is_connected(_refresh):
		inventory.changed.disconnect(_refresh)

	inventory = target_inventory
	if inventory == null:
		return

	if not inventory.changed.is_connected(_refresh):
		inventory.changed.connect(_refresh)

	_build_slots()
	_refresh()


func set_title(text: String) -> void:
	title_label.text = text


func get_selected_index() -> int:
	return _selected_index


func _build_slots() -> void:
	while grid.get_child_count() > 0:
		grid.get_child(0).free()
	_slot_uis.clear()
	_selected_index = -1

	if inventory == null:
		return

	grid.columns = columns
	for i in range(inventory.capacity):
		var slot_ui: PanelContainer = SLOT_SCENE.instantiate()
		slot_ui.slot_index = i
		slot_ui.slot_clicked.connect(_on_slot_clicked)
		grid.add_child(slot_ui)
		_slot_uis.append(slot_ui)


func _refresh() -> void:
	if inventory == null:
		return

	for i in range(_slot_uis.size()):
		var slot_data := inventory.get_slot(i)
		var slot_ui: PanelContainer = _slot_uis[i]
		if slot_data.is_empty():
			slot_ui.clear_slot(i == _selected_index)
		else:
			slot_ui.update_slot(slot_data, i == _selected_index)


func _on_slot_clicked(index: int) -> void:
	_selected_index = index
	slot_selected.emit(index)
	_refresh()
