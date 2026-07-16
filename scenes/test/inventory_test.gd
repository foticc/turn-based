extends Control
## 物品栏功能测试场景。


@onready var inventory: Inventory = $Inventory
@onready var inventory_panel: InventoryPanel = $MarginContainer/VBox/InventoryPanelHost/InventoryPanel
@onready var hp_label: Label = $MarginContainer/VBox/StatsPanel/HPLabel
@onready var selected_label: Label = $MarginContainer/VBox/StatsPanel/SelectedLabel
@onready var log_label: RichTextLabel = $MarginContainer/VBox/LogLabel

var _items: Dictionary[String, ItemDefinition] = {}
var _player_hp: int = 80
var _player_max_hp: int = 100


func _ready() -> void:
	_setup_items()
	_setup_inventory_panel()
	_connect_buttons()
	_refresh_stats()
	_append_log("[color=yellow]物品栏测试已就绪：双击或右键可「使用」[/color]")


func _setup_items() -> void:
	_items = {
		"health_potion": _create_item(
			"health_potion", "生命药水", "恢复 30 点生命值。",
			ItemDefinition.ItemType.CONSUMABLE, 20, 30
		),
		"greater_health_potion": _create_item(
			"greater_health_potion", "大生命药水", "恢复 60 点生命值。",
			ItemDefinition.ItemType.CONSUMABLE, 10, 60
		),
		"iron_sword": _create_item(
			"iron_sword", "铁剑", "基础武器，无法直接使用。",
			ItemDefinition.ItemType.EQUIPMENT, 1, 0
		),
		"herb": _create_item(
			"herb", "草药", "炼金材料。",
			ItemDefinition.ItemType.MATERIAL, 99, 0
		),
	}


func _create_item(
	item_id: String,
	item_name: String,
	description: String,
	item_type: ItemDefinition.ItemType,
	max_stack: int,
	heal_amount: int
) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = item_id
	item.display_name = item_name
	item.description = description
	item.item_type = item_type
	item.max_stack = max_stack
	item.heal_amount = heal_amount
	return item


func _setup_inventory_panel() -> void:
	inventory_panel.bind(inventory)
	inventory_panel.set_title("背包 (%d 格)" % inventory.capacity)
	inventory_panel.slot_selected.connect(_on_slot_selected)
	inventory_panel.use_requested.connect(_on_use_requested)
	inventory.item_used.connect(_on_item_used)

	inventory.add_item(_items["health_potion"], 3)
	inventory.add_item(_items["iron_sword"], 1)
	inventory.add_item(_items["herb"], 5)


func _connect_buttons() -> void:
	$MarginContainer/VBox/ButtonRow/AddPotionButton.pressed.connect(
		func() -> void: _add_item("health_potion", 2)
	)
	$MarginContainer/VBox/ButtonRow/AddGreaterPotionButton.pressed.connect(
		func() -> void: _add_item("greater_health_potion", 1)
	)
	$MarginContainer/VBox/ButtonRow/AddSwordButton.pressed.connect(
		func() -> void: _add_item("iron_sword", 1)
	)
	$MarginContainer/VBox/ButtonRow/AddHerbButton.pressed.connect(
		func() -> void: _add_item("herb", 3)
	)
	$MarginContainer/VBox/ButtonRow/UseButton.pressed.connect(_use_selected)
	$MarginContainer/VBox/ButtonRow/RemoveButton.pressed.connect(_remove_selected)
	$MarginContainer/VBox/ButtonRow/ClearButton.pressed.connect(_clear_inventory)


func _add_item(item_id: String, amount: int) -> void:
	var item: ItemDefinition = _items[item_id]
	var overflow: int = inventory.add_item(item, amount)
	if overflow > 0:
		_append_log("[color=red]背包已满，%s 有 %d 个未能放入[/color]" % [item.display_name, overflow])
	else:
		_append_log("获得 %s x%d" % [item.display_name, amount])
	_update_selected_label()


func _use_selected() -> void:
	var index: int = inventory_panel.get_selected_index()
	if index < 0:
		_append_log("[color=gray]请先选择一个格子[/color]")
		return
	_use_item_at(index)


func _on_use_requested(index: int) -> void:
	_use_item_at(index)


func _use_item_at(index: int) -> void:
	var result: Dictionary = inventory.use_item_at(index)
	if result.success:
		if result.heal > 0:
			_player_hp = mini(_player_hp + result.heal, _player_max_hp)
			_refresh_stats()
		_append_log("[color=green]%s，恢复 %d HP[/color]" % [result.message, result.heal])
	else:
		_append_log("[color=red]%s[/color]" % result.message)
	_update_selected_label()


func _remove_selected() -> void:
	var index: int = inventory_panel.get_selected_index()
	if index < 0:
		_append_log("[color=gray]请先选择一个格子[/color]")
		return

	var slot_data: Dictionary = inventory.get_slot(index)
	if slot_data.is_empty():
		_append_log("[color=gray]该格子为空[/color]")
		return

	var item: ItemDefinition = slot_data.item
	if inventory.remove_from_slot(index, 1):
		_append_log("丢弃 %s x1" % item.display_name)
	_update_selected_label()


func _clear_inventory() -> void:
	inventory.clear()
	_append_log("背包已清空")
	_update_selected_label()


func _on_slot_selected(index: int) -> void:
	_update_selected_label(index)


func _on_item_used(_index: int, item: ItemDefinition, result: Dictionary) -> void:
	if result.success and item.item_type == ItemDefinition.ItemType.CONSUMABLE:
		_update_selected_label()


func _update_selected_label(index: int = -1) -> void:
	if index < 0:
		index = inventory_panel.get_selected_index()
	if index < 0:
		selected_label.text = "选中：无"
		return

	var slot_data: Dictionary = inventory.get_slot(index)
	if slot_data.is_empty():
		selected_label.text = "选中：第 %d 格（空）" % (index + 1)
		return

	var item: ItemDefinition = slot_data.item
	selected_label.text = "选中：%s x%d" % [item.display_name, slot_data.quantity]


func _refresh_stats() -> void:
	hp_label.text = "生命值：%d / %d" % [_player_hp, _player_max_hp]


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
