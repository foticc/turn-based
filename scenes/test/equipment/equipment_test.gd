extends Control
## 角色面板测试：通过 PlayerState + ItemDatabase 驱动。

@onready var character_sheet: CharacterSheetPanel = $Margin/HBox/CharacterSheetPanel
@onready var log_label: RichTextLabel = $Margin/HBox/Side/LogLabel
@onready var add_buttons: VBoxContainer = $Margin/HBox/Side/AddButtonList

var _player: PlayerState


func _ready() -> void:
	_player = PlayerState.create_default(3, 3, 24)
	_player.grant_starting_kit()
	character_sheet.bind_player(_player)
	character_sheet.action_logged.connect(_append_log)
	_connect_buttons()
	_append_log("[color=yellow]数据层：PlayerState + ItemDatabase | 表现层：CharacterSheetPanel[/color]")


func _connect_buttons() -> void:
	$Margin/HBox/Side/UseButton.pressed.connect(character_sheet.use_selected_inventory_item)
	$Margin/HBox/Side/UnequipButton.pressed.connect(character_sheet.unequip_selected_slot)

	for child in add_buttons.get_children():
		child.queue_free()

	for item_id in _player.items.get_all_ids():
		var item := _player.get_item(item_id)
		if item == null:
			continue
		var btn := Button.new()
		btn.text = "+ %s" % item.display_name
		btn.pressed.connect(_add_item.bind(item_id))
		add_buttons.add_child(btn)


func _add_item(item_id: String) -> void:
	_player.grant_item(item_id, 1)


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
