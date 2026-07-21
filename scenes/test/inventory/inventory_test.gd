extends Control
## 物品栏测试：物品全部来自 ItemDatabase.tres，不再代码造物。

@onready var inventory_panel: InventoryPanel = $MarginContainer/VBox/InventoryPanelHost/InventoryPanel
@onready var hp_label: Label = $MarginContainer/VBox/StatsPanel/HPLabel
@onready var selected_label: Label = $MarginContainer/VBox/StatsPanel/SelectedLabel
@onready var log_label: RichTextLabel = $MarginContainer/VBox/LogLabel

var _items: ItemDatabase
var _inventory: Inventory
var _stats: CharacterStats


func _ready() -> void:
	_items = ItemDatabase.load_default()
	_inventory = Inventory.new(16)
	_stats = CharacterStats.new(load("res://src/character/definitions/warrior.tres") as CharacterDefinition, 1)
	_stats.hp = 80

	inventory_panel.bind(_inventory)
	inventory_panel.set_title("背包 (%d 格)" % _inventory.capacity)
	inventory_panel.slot_selected.connect(_on_slot_selected)
	inventory_panel.use_requested.connect(_on_use_requested)

	_inventory.add_item(_items.get_item("health_potion"), 3)
	_inventory.add_item(_items.get_item("iron_sword"), 1)
	_inventory.add_item(_items.get_item("herb"), 5)

	_connect_buttons()
	_refresh_stats()
	_append_log("[color=yellow]物品来自 ItemDatabase，双击或右键「使用」[/color]")


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
	var item := _items.get_item(item_id)
	if item == null:
		_append_log("[color=red]物品库无此 id：%s[/color]" % item_id)
		return
	var overflow: int = _inventory.add_item(item, amount)
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
	var slot_data := _inventory.get_slot(index)
	if slot_data.is_empty():
		_append_log("[color=gray]该格子为空[/color]")
		return

	var item: ItemDefinition = slot_data.item
	if item.is_equipment():
		_append_log("[color=orange]%s 是装备，请在装备测试/世界场景中穿戴[/color]" % item.display_name)
		return

	var result: Dictionary = _inventory.use_item_at(index)
	if result.success:
		var healed := 0
		if result.heal > 0:
			healed = _stats.heal(result.heal)
		_refresh_stats()
		_append_log("[color=green]%s，恢复 %d HP[/color]" % [result.message, healed])
	else:
		_append_log("[color=red]%s[/color]" % result.message)
	_update_selected_label()


func _remove_selected() -> void:
	var index: int = inventory_panel.get_selected_index()
	if index < 0:
		_append_log("[color=gray]请先选择一个格子[/color]")
		return

	var slot_data: Dictionary = _inventory.get_slot(index)
	if slot_data.is_empty():
		_append_log("[color=gray]该格子为空[/color]")
		return

	var item: ItemDefinition = slot_data.item
	if _inventory.remove_from_slot(index, 1):
		_append_log("丢弃 %s x1" % item.display_name)
	_update_selected_label()


func _clear_inventory() -> void:
	_inventory.clear()
	_append_log("背包已清空")
	_update_selected_label()


func _on_slot_selected(index: int) -> void:
	_update_selected_label(index)


func _update_selected_label(index: int = -1) -> void:
	if index < 0:
		index = inventory_panel.get_selected_index()
	if index < 0:
		selected_label.text = "选中：无"
		return

	var slot_data: Dictionary = _inventory.get_slot(index)
	if slot_data.is_empty():
		selected_label.text = "选中：第 %d 格（空）" % (index + 1)
		return

	var item: ItemDefinition = slot_data.item
	selected_label.text = "选中：%s x%d" % [item.display_name, slot_data.quantity]


func _refresh_stats() -> void:
	hp_label.text = "生命值：%d / %d" % [_stats.hp, _stats.get_total_max_hp()]


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
