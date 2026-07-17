extends PanelContainer
## 单个物品栏格子 UI。

signal slot_clicked(index: int)
signal slot_right_clicked(index: int)
signal slot_double_clicked(index: int)

@export var slot_index: int = 0

@onready var icon_rect: TextureRect = $MarginContainer/VBox/Icon
@onready var name_label: Label = $MarginContainer/VBox/NameLabel
@onready var count_label: Label = $MarginContainer/VBox/CountLabel

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

	_item = slot_data.item
	var quantity: int = slot_data.quantity
	icon_rect.texture = _item.icon
	icon_rect.visible = _item.icon != null
	name_label.text = _item.display_name
	count_label.text = "x%d" % quantity if quantity > 1 else ""
	tooltip_text = ""
	modulate = Color(1.0, 1.0, 0.85) if selected else Color.WHITE


func clear_slot(selected: bool = false) -> void:
	_item = null
	icon_rect.texture = null
	icon_rect.visible = false
	name_label.text = ""
	count_label.text = ""
	tooltip_text = ""
	modulate = Color(0.7, 0.7, 0.7) if selected else Color.WHITE


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
