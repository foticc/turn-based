class_name EquipmentSlotUI
extends PanelContainer
## 单个装备槽：可在检查器为每个部位设置不同背景。

signal slot_clicked(slot: ItemDefinition.EquipSlot)
signal unequip_requested(slot: ItemDefinition.EquipSlot)

@export var equip_slot: ItemDefinition.EquipSlot = ItemDefinition.EquipSlot.NONE
@export var background: Texture2D:
	set(value):
		background = value
		_apply_background()

@onready var icon_rect: TextureRect = $Margin/Root/Icon
@onready var placeholder_label: Label = $Margin/Root/Placeholder
@onready var slot_label: Label = $Margin/Root/SlotLabel
@onready var item_label: Label = $Margin/Root/ItemLabel

var _item: ItemDefinition = null
var _selected: bool = false


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_background()
	_refresh_empty()


func set_item(item: ItemDefinition, selected: bool = false) -> void:
	_item = item
	_selected = selected
	if item == null:
		_refresh_empty()
		return

	slot_label.text = ItemDefinition.get_slot_display_name(equip_slot)
	item_label.text = item.display_name
	item_label.visible = true

	var has_icon := item.icon != null
	icon_rect.texture = item.icon
	icon_rect.visible = has_icon
	placeholder_label.visible = not has_icon
	if not has_icon:
		placeholder_label.text = "装"
		placeholder_label.modulate = Color(0.95, 0.8, 0.45)

	modulate = Color(1.0, 1.0, 0.85) if selected else Color.WHITE


func clear_slot(selected: bool = false) -> void:
	_item = null
	_selected = selected
	_refresh_empty()


func get_item() -> ItemDefinition:
	return _item


func _refresh_empty() -> void:
	icon_rect.texture = null
	icon_rect.visible = false
	placeholder_label.visible = true
	placeholder_label.text = "空"
	placeholder_label.modulate = Color(0.7, 0.72, 0.78)
	slot_label.text = ItemDefinition.get_slot_display_name(equip_slot)
	item_label.text = ""
	item_label.visible = false
	modulate = Color(0.82, 0.84, 0.9) if _selected else Color.WHITE


func _apply_background() -> void:
	if background == null:
		return
	var style := StyleBoxTexture.new()
	style.texture = background
	style.texture_margin_left = 0
	style.texture_margin_top = 0
	style.texture_margin_right = 0
	style.texture_margin_bottom = 0
	add_theme_stylebox_override("panel", style)


func _on_mouse_entered() -> void:
	if _item == null:
		return
	ItemTooltip.request_show(_item, "双击或右键卸下")


func _on_mouse_exited() -> void:
	ItemTooltip.hide_tooltip()


func _on_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		ItemTooltip.hide_tooltip()
		if mouse_event.double_click:
			if _item != null:
				unequip_requested.emit(equip_slot)
		else:
			slot_clicked.emit(equip_slot)
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		ItemTooltip.hide_tooltip()
		slot_clicked.emit(equip_slot)
		if _item != null:
			unequip_requested.emit(equip_slot)
		accept_event()
