class_name InventoryPanel
extends PanelContainer
## 物品栏面板，显示格子网格并与 Inventory 数据绑定。

signal slot_selected(index: int)
## 右键菜单「使用」或双击物品时发出
signal use_requested(index: int)

const SLOT_SCENE := preload("res://scenes/ui/inventory_slot_ui.tscn")

@export var columns: int = 8

@onready var grid: GridContainer = $MarginContainer/VBox/GridContainer
@onready var title_label: Label = $MarginContainer/VBox/TitleLabel

var inventory: Inventory
var _slot_uis: Array[PanelContainer] = []
var _selected_index: int = -1
var _context_menu: PopupMenu
var _context_slot_index: int = -1


func _ready() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "ContextMenu"
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)


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
		slot_ui.slot_right_clicked.connect(_on_slot_right_clicked)
		slot_ui.slot_double_clicked.connect(_on_slot_double_clicked)
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


func _on_slot_double_clicked(index: int) -> void:
	_selected_index = index
	slot_selected.emit(index)
	_refresh()
	if inventory == null:
		return
	if inventory.get_slot(index).is_empty():
		return
	use_requested.emit(index)


func _on_slot_right_clicked(index: int) -> void:
	_selected_index = index
	slot_selected.emit(index)
	_refresh()

	if inventory == null:
		return
	var slot_data := inventory.get_slot(index)
	if slot_data.is_empty():
		return

	_context_slot_index = index
	var item: ItemDefinition = slot_data.item
	_context_menu.clear()
	_context_menu.add_item(_get_use_action_text(item), 0)
	_context_menu.position = Vector2i(get_global_mouse_position())
	_context_menu.popup()


func _get_use_action_text(item: ItemDefinition) -> String:
	if item.is_equipment():
		return "使用（装备）"
	if item.item_type == ItemDefinition.ItemType.CONSUMABLE:
		return "使用"
	return "使用"


func _on_context_menu_id_pressed(id: int) -> void:
	if id != 0 or _context_slot_index < 0:
		return
	use_requested.emit(_context_slot_index)
