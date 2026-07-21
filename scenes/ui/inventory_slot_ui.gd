extends PanelContainer
## 单个物品栏格子：图标 + 名称 + 数量 + 类型，不只是一张 icon。

signal slot_clicked(index: int)
signal slot_right_clicked(index: int)
signal slot_double_clicked(index: int)

@export var slot_index: int = 0

@onready var icon_rect: TextureRect = $Margin/Root/Icon
@onready var placeholder_label: Label = $Margin/Root/Placeholder
@onready var type_label: Label = $Margin/Root/TypeLabel
@onready var name_label: Label = $Margin/Root/NameLabel
@onready var count_label: Label = $Margin/Root/CountLabel

var _item: ItemDefinition = null


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clear_slot()


func update_slot(slot_data: Dictionary, selected: bool = false) -> void:
	if slot_data.is_empty():
		clear_slot(selected)
		return

	_item = slot_data.item as ItemDefinition
	var quantity: int = int(slot_data.quantity)

	name_label.text = _item.display_name
	name_label.visible = true
	type_label.text = _type_text(_item)
	type_label.visible = true
	count_label.text = "x%d" % quantity
	count_label.visible = quantity > 1

	var has_icon := _item.icon != null
	icon_rect.texture = _item.icon
	icon_rect.visible = has_icon
	placeholder_label.visible = not has_icon
	if not has_icon:
		placeholder_label.text = _placeholder_glyph(_item)
		placeholder_label.modulate = _type_color(_item)
	else:
		placeholder_label.modulate = Color.WHITE

	tooltip_text = ""
	modulate = Color(1.0, 1.0, 0.85) if selected else Color.WHITE


func clear_slot(selected: bool = false) -> void:
	_item = null
	icon_rect.texture = null
	icon_rect.visible = false
	placeholder_label.visible = false
	placeholder_label.text = ""
	type_label.text = ""
	type_label.visible = false
	name_label.text = ""
	name_label.visible = false
	count_label.text = ""
	count_label.visible = false
	tooltip_text = ""
	modulate = Color(0.75, 0.75, 0.8) if selected else Color(0.9, 0.9, 0.92)


func _type_text(item: ItemDefinition) -> String:
	match item.item_type:
		ItemDefinition.ItemType.CONSUMABLE:
			return "消耗"
		ItemDefinition.ItemType.EQUIPMENT:
			return "装备"
		ItemDefinition.ItemType.MATERIAL:
			return "材料"
		_:
			return "物品"


func _placeholder_glyph(item: ItemDefinition) -> String:
	match item.item_type:
		ItemDefinition.ItemType.CONSUMABLE:
			return "药"
		ItemDefinition.ItemType.EQUIPMENT:
			return "装"
		ItemDefinition.ItemType.MATERIAL:
			return "材"
		_:
			return "物"


func _type_color(item: ItemDefinition) -> Color:
	match item.item_type:
		ItemDefinition.ItemType.CONSUMABLE:
			return Color(0.55, 0.9, 0.65)
		ItemDefinition.ItemType.EQUIPMENT:
			return Color(0.95, 0.8, 0.45)
		ItemDefinition.ItemType.MATERIAL:
			return Color(0.7, 0.8, 0.95)
		_:
			return Color(0.85, 0.85, 0.85)


func _on_mouse_entered() -> void:
	if _item == null:
		return
	var hint := "双击或右键可使用"
	if _item.is_equipment():
		hint = "双击或右键可装备"
	elif _item.item_type == ItemDefinition.ItemType.MATERIAL:
		hint = "材料，无法直接使用"
	ItemTooltip.request_show(_item, hint)


func _on_mouse_exited() -> void:
	ItemTooltip.hide_tooltip()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			ItemTooltip.hide_tooltip()
			if mouse_event.double_click:
				slot_double_clicked.emit(slot_index)
			else:
				slot_clicked.emit(slot_index)
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			ItemTooltip.hide_tooltip()
			slot_right_clicked.emit(slot_index)
			accept_event()
