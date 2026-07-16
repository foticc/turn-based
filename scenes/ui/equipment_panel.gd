class_name EquipmentPanel
extends PanelContainer
## 装备栏面板：武器、头冠、衣服、鞋子、腰带、玉佩、项链、双手镯。

signal slot_clicked(slot: ItemDefinition.EquipSlot)

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var slots_grid: GridContainer = $Margin/VBox/SlotsGrid

var equipment: Equipment
var _selected_slot: ItemDefinition.EquipSlot = ItemDefinition.EquipSlot.NONE
var _slot_buttons: Dictionary = {}


func _ready() -> void:
	_build_slot_buttons()
	_refresh()


func _build_slot_buttons() -> void:
	for child in slots_grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	for slot in [
		ItemDefinition.EquipSlot.WEAPON,
		ItemDefinition.EquipSlot.HELMET,
		ItemDefinition.EquipSlot.CLOTHES,
		ItemDefinition.EquipSlot.SHOES,
		ItemDefinition.EquipSlot.BELT,
		ItemDefinition.EquipSlot.JADE_PENDANT,
		ItemDefinition.EquipSlot.NECKLACE,
		ItemDefinition.EquipSlot.BRACELET_LEFT,
		ItemDefinition.EquipSlot.BRACELET_RIGHT,
	]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 72)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		slots_grid.add_child(btn)
		_slot_buttons[slot] = btn


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


func _on_slot_pressed(slot: ItemDefinition.EquipSlot) -> void:
	_selected_slot = slot
	slot_clicked.emit(slot)
	_refresh()


func _refresh() -> void:
	for slot in _slot_buttons.keys():
		var btn: Button = _slot_buttons[slot]
		var item: ItemDefinition = null
		if equipment:
			item = equipment.get_equipped(slot)

		var slot_name := ItemDefinition.get_slot_display_name(slot)
		if item:
			btn.text = "%s\n%s" % [slot_name, item.display_name]
			btn.tooltip_text = item.get_tooltip_text()
			btn.modulate = Color(1.0, 0.95, 0.7) if slot == _selected_slot else Color.WHITE
		else:
			btn.text = "%s\n（空）" % slot_name
			btn.tooltip_text = "%s 槽位" % slot_name
			btn.modulate = Color(0.75, 0.75, 0.8) if slot == _selected_slot else Color(0.9, 0.9, 0.9)
