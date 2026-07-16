extends PanelContainer
## 单个物品栏格子 UI。

signal slot_clicked(index: int)
signal slot_right_clicked(index: int)
signal slot_double_clicked(index: int)

@export var slot_index: int = 0

@onready var name_label: Label = $MarginContainer/VBox/NameLabel
@onready var count_label: Label = $MarginContainer/VBox/CountLabel


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clear_slot()


func update_slot(slot_data: Dictionary, selected: bool = false) -> void:
	if slot_data.is_empty():
		clear_slot(selected)
		return

	var item: ItemDefinition = slot_data.item
	var quantity: int = slot_data.quantity
	name_label.text = item.display_name
	count_label.text = "x%d" % quantity if quantity > 1 else ""
	tooltip_text = item.get_tooltip_text()
	modulate = Color(1.0, 1.0, 0.85) if selected else Color.WHITE


func clear_slot(selected: bool = false) -> void:
	name_label.text = ""
	count_label.text = ""
	tooltip_text = "空"
	modulate = Color(0.7, 0.7, 0.7) if selected else Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.double_click:
				slot_double_clicked.emit(slot_index)
			else:
				slot_clicked.emit(slot_index)
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			slot_right_clicked.emit(slot_index)
			accept_event()
