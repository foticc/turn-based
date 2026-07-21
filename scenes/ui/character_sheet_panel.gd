class_name CharacterSheetPanel
extends PanelContainer
## 表现层：属性 + 装备 + 背包。业务逻辑交给 PlayerState。

signal action_logged(message: String)
signal inventory_slot_selected(index: int)
signal equipment_slot_selected(slot: ItemDefinition.EquipSlot)

@onready var stats_panel: CharacterStatsPanel = $Margin/VBox/TopRow/CharacterStatsPanel
@onready var equipment_panel: EquipmentPanel = $Margin/VBox/TopRow/EquipmentPanel
@onready var inventory_panel: InventoryPanel = $Margin/VBox/InventoryPanel
@onready var tip_label: Label = $Margin/VBox/TipLabel

var player: PlayerState


func _ready() -> void:
	tip_label.text = "悬停查看详情 | 背包：双击/右键使用 | 装备槽：双击/右键卸下"
	inventory_panel.use_requested.connect(_on_inventory_use_requested)
	inventory_panel.slot_selected.connect(_on_inventory_slot_selected)
	equipment_panel.slot_clicked.connect(_on_equipment_slot_clicked)
	equipment_panel.unequip_requested.connect(_on_equipment_unequip_requested)


func bind_player(state: PlayerState) -> void:
	if player != null and player.action_logged.is_connected(_on_player_logged):
		player.action_logged.disconnect(_on_player_logged)

	player = state
	if player == null:
		return

	if not player.action_logged.is_connected(_on_player_logged):
		player.action_logged.connect(_on_player_logged)

	stats_panel.bind(player.stats)
	equipment_panel.bind(player.equipment)
	inventory_panel.bind(player.inventory)
	inventory_panel.set_title("背包")


## 兼容旧调用：仅组装引用；完整流程请用 bind_player(PlayerState)。
func bind(
	target_stats: CharacterStats,
	target_equipment: Equipment,
	target_inventory: Inventory
) -> void:
	var state := PlayerState.new()
	state.stats = target_stats
	state.equipment = target_equipment
	state.inventory = target_inventory
	if target_stats and target_equipment:
		var bonus := target_equipment.get_bonus_summary()
		target_stats.apply_equipment_bonuses(
			bonus.attack, bonus.defense, bonus.speed, bonus.max_hp, bonus.max_mp
		)
	bind_player(state)


func get_selected_inventory_index() -> int:
	return inventory_panel.get_selected_index()


func get_selected_equipment_slot() -> ItemDefinition.EquipSlot:
	return equipment_panel.get_selected_slot()


func use_selected_inventory_item() -> void:
	if player == null:
		return
	var index := inventory_panel.get_selected_index()
	if index < 0:
		_log("[color=gray]请先选中背包中的物品[/color]")
		return
	player.use_inventory_slot(index)


func unequip_selected_slot() -> void:
	if player == null:
		return
	player.unequip_slot(equipment_panel.get_selected_slot())


func _on_inventory_use_requested(index: int) -> void:
	if player:
		player.use_inventory_slot(index)


func _on_inventory_slot_selected(index: int) -> void:
	inventory_slot_selected.emit(index)


func _on_equipment_slot_clicked(slot: ItemDefinition.EquipSlot) -> void:
	equipment_slot_selected.emit(slot)
	if player == null or player.equipment == null:
		return
	var item := player.equipment.get_equipped(slot)
	var slot_name := ItemDefinition.get_slot_display_name(slot)
	if item:
		_log("选中装备槽：%s（%s）" % [slot_name, item.display_name])
	else:
		_log("选中装备槽：%s（空）" % slot_name)


func _on_equipment_unequip_requested(slot: ItemDefinition.EquipSlot) -> void:
	if player:
		player.unequip_slot(slot)


func _on_player_logged(message: String) -> void:
	action_logged.emit(message)


func _log(message: String) -> void:
	action_logged.emit(message)
