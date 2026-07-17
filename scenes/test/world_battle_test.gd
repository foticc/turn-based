extends Node2D
## 大地图探索 + 遇敌战斗测试场景。
## 左下角 HUD：角色详情 / 背包（装备+物品）/ 技能。

## 死区比例：角色可在镜头内自由移动，靠近边缘时相机才跟过去。
@export_range(0.05, 0.45, 0.01) var camera_deadzone_ratio: float = 0.28

const WARRIOR_PATH := "res://src/character/definitions/warrior.tres"
const TREE_DEF_PATH := "res://src/skill_tree/trees/warrior_skill_tree.tres"
const ITEM_PATHS := {
	"iron_sword": "res://src/equipment/items/iron_sword.tres",
	"bronze_crown": "res://src/equipment/items/bronze_crown.tres",
	"leather_armor": "res://src/equipment/items/leather_armor.tres",
	"traveler_boots": "res://src/equipment/items/traveler_boots.tres",
	"warrior_belt": "res://src/equipment/items/warrior_belt.tres",
	"jade_pendant": "res://src/equipment/items/jade_pendant.tres",
	"silver_necklace": "res://src/equipment/items/silver_necklace.tres",
	"swift_bracelet": "res://src/equipment/items/swift_bracelet.tres",
}

@onready var map_root: Node2D = $NoviceVillage
@onready var player: CharacterBody2D = $Entities/Player
@onready var enemies_root: Node2D = $Entities/Enemies
@onready var camera: Camera2D = $Camera2D
@onready var encounter_battle = $EncounterBattle
@onready var tip_label: Label = $UI/TipLabel
@onready var inventory: Inventory = $Inventory

@onready var overlay: Control = $UI/Overlay
@onready var dimmer: ColorRect = $UI/Overlay/Dimmer
@onready var stats_window: Control = $UI/Overlay/StatsWindow
@onready var bag_window: Control = $UI/Overlay/BagWindow
@onready var skill_window: Control = $UI/Overlay/SkillWindow
@onready var stats_panel: CharacterStatsPanel = $UI/Overlay/StatsWindow/CharacterStatsPanel
@onready var equipment_panel: EquipmentPanel = $UI/Overlay/BagWindow/Body/EquipmentPanel
@onready var inventory_panel: InventoryPanel = $UI/Overlay/BagWindow/Body/InventoryPanel
@onready var skill_tree_panel: SkillTreePanel = $UI/Overlay/SkillWindow/SkillTreePanel

@onready var btn_stats: Button = $UI/HudBar/StatsButton
@onready var btn_bag: Button = $UI/HudBar/BagButton
@onready var btn_skill: Button = $UI/HudBar/SkillButton

var _in_battle: bool = false
var _current_enemy: WorldEnemy = null
var _stats: CharacterStats
var _equipment: Equipment
var _skill_tree: SkillTree
var _open_menu: String = ""
var _items: Dictionary = {}


func _ready() -> void:
	player.add_to_group("player")
	_apply_camera_limits(camera)
	camera.global_position = player.global_position
	camera.make_current()

	for child in enemies_root.get_children():
		if child is WorldEnemy:
			var enemy := child as WorldEnemy
			enemy.encounter_requested.connect(_on_enemy_encounter_requested)
			var name_label := enemy.get_node_or_null("NameLabel") as Label
			if name_label:
				name_label.text = enemy.enemy_name

	encounter_battle.encounter_ended.connect(_on_encounter_ended)
	tip_label.text = "点击地面移动，碰到敌人进入战斗 | 左下角打开角色/背包/技能"

	_setup_player_data()
	_setup_menu_ui()


func _unhandled_input(event: InputEvent) -> void:
	if _open_menu == "":
		return
	if event.is_action_pressed("ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _in_battle or _open_menu != "":
		return
	_update_camera_follow()


func _setup_player_data() -> void:
	var def := load(WARRIOR_PATH) as CharacterDefinition
	_stats = CharacterStats.new(def, 3)
	_equipment = Equipment.new()
	_equipment.bind(_stats)

	var tree_def := load(TREE_DEF_PATH) as SkillTreeDefinition
	_skill_tree = SkillTree.new(tree_def, 3)

	_items.clear()
	for item_id in ITEM_PATHS.keys():
		_items[item_id] = load(ITEM_PATHS[item_id]) as ItemDefinition
	_items["health_potion"] = _create_potion()

	for item_id in ITEM_PATHS.keys():
		inventory.add_item(_items[item_id], 1)
	inventory.add_item(_items["swift_bracelet"], 1)
	inventory.add_item(_items["health_potion"], 3)

	stats_panel.bind(_stats)
	equipment_panel.bind(_equipment)
	inventory_panel.bind(inventory)
	inventory_panel.set_title("背包")
	skill_tree_panel.bind(_skill_tree)


func _create_potion() -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = "health_potion"
	item.display_name = "生命药水"
	item.description = "恢复 30 点生命值。"
	item.item_type = ItemDefinition.ItemType.CONSUMABLE
	item.max_stack = 20
	item.heal_amount = 30
	return item


func _setup_menu_ui() -> void:
	overlay.visible = false
	_hide_all_windows()

	btn_stats.pressed.connect(_toggle_menu.bind("stats"))
	btn_bag.pressed.connect(_toggle_menu.bind("bag"))
	btn_skill.pressed.connect(_toggle_menu.bind("skill"))

	dimmer.gui_input.connect(_on_dimmer_gui_input)
	$UI/Overlay/StatsWindow/Header/CloseButton.pressed.connect(_close_menu)
	$UI/Overlay/BagWindow/Header/CloseButton.pressed.connect(_close_menu)
	$UI/Overlay/SkillWindow/Header/CloseButton.pressed.connect(_close_menu)

	inventory_panel.use_requested.connect(_on_inventory_use_requested)
	equipment_panel.unequip_requested.connect(_on_equipment_unequip_requested)


func _toggle_menu(menu_id: String) -> void:
	if _in_battle:
		return
	if _open_menu == menu_id:
		_close_menu()
		return
	_open_menu_panel(menu_id)


func _open_menu_panel(menu_id: String) -> void:
	_open_menu = menu_id
	overlay.visible = true
	_hide_all_windows()
	match menu_id:
		"stats":
			stats_window.visible = true
		"bag":
			bag_window.visible = true
		"skill":
			skill_window.visible = true
	_set_world_input_enabled(false)


func _close_menu() -> void:
	if _open_menu == "":
		return
	_open_menu = ""
	overlay.visible = false
	_hide_all_windows()
	ItemTooltip.hide_tooltip()
	if not _in_battle:
		_set_world_input_enabled(true)


func _hide_all_windows() -> void:
	stats_window.visible = false
	bag_window.visible = false
	skill_window.visible = false


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_close_menu()
			get_viewport().set_input_as_handled()


func _set_world_input_enabled(enabled: bool) -> void:
	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(enabled)


func _on_inventory_use_requested(index: int) -> void:
	var slot_data := inventory.get_slot(index)
	if slot_data.is_empty():
		return

	var item: ItemDefinition = slot_data.item
	if item.is_equipment():
		var result := _equipment.equip(item)
		if not result.success:
			tip_label.text = str(result.message)
			return
		inventory.remove_from_slot(index, 1)
		var replaced: ItemDefinition = result.get("replaced")
		if replaced:
			inventory.add_item(replaced, 1)
			tip_label.text = "装备 %s，换下 %s" % [item.display_name, replaced.display_name]
		else:
			tip_label.text = "装备了 %s" % item.display_name
		return

	if item.item_type == ItemDefinition.ItemType.CONSUMABLE:
		var result := inventory.use_item_at(index)
		if result.success:
			var healed := 0
			if result.heal > 0 and _stats:
				healed = _stats.heal(result.heal)
			tip_label.text = "%s，恢复 %d HP" % [result.message, healed]
		else:
			tip_label.text = str(result.message)
		return

	tip_label.text = "%s 无法使用" % item.display_name


func _on_equipment_unequip_requested(slot: ItemDefinition.EquipSlot) -> void:
	var item := _equipment.unequip(slot)
	if item == null:
		return
	var overflow := inventory.add_item(item, 1)
	if overflow > 0:
		_equipment.equip(item)
		tip_label.text = "背包已满，无法卸下 %s" % item.display_name
	else:
		tip_label.text = "卸下了 %s" % item.display_name


func _update_camera_follow() -> void:
	var half_view := get_viewport().get_visible_rect().size * 0.5 / camera.zoom
	var dead := half_view * camera_deadzone_ratio
	var cam_pos := camera.global_position
	var player_pos := player.global_position
	var offset := player_pos - cam_pos
	var next := cam_pos

	if offset.x > dead.x:
		next.x = player_pos.x - dead.x
	elif offset.x < -dead.x:
		next.x = player_pos.x + dead.x

	if offset.y > dead.y:
		next.y = player_pos.y - dead.y
	elif offset.y < -dead.y:
		next.y = player_pos.y + dead.y

	camera.global_position = next


func _apply_camera_limits(cam: Camera2D) -> void:
	var bounds := _get_map_bounds()
	if bounds.size == Vector2.ZERO:
		return
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	cam.limit_smoothed = true


func _get_map_bounds() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for child in map_root.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			if layer.tile_set == null:
				continue
			var used := layer.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var tile_size := Vector2(layer.tile_set.tile_size)
			var top_left := layer.to_global(Vector2(used.position) * tile_size)
			var bottom_right := layer.to_global(Vector2(used.position + used.size) * tile_size)
			var layer_rect := Rect2(top_left, bottom_right - top_left)
			if not has_bounds:
				bounds = layer_rect
				has_bounds = true
			else:
				bounds = bounds.merge(layer_rect)
	return bounds if has_bounds else Rect2()


func _on_enemy_encounter_requested(enemy: WorldEnemy) -> void:
	if _in_battle:
		return
	_close_menu()
	_in_battle = true
	_current_enemy = enemy

	_set_world_input_enabled(false)

	for child in enemies_root.get_children():
		if child is WorldEnemy:
			(child as WorldEnemy).set_trigger_enabled(false)

	encounter_battle.start_encounter(enemy)


func _on_encounter_ended(player_won: bool) -> void:
	var fought := _current_enemy
	_current_enemy = null

	if player_won and is_instance_valid(fought):
		tip_label.text = "击败了 %s！" % fought.enemy_name
		fought.queue_free()
	elif not player_won:
		tip_label.text = "战败了…敌人仍在，稍后再试"
	else:
		tip_label.text = "点击地面移动，碰到敌人进入战斗"

	# 短暂无敌，避免战败后立刻再次触发
	await get_tree().create_timer(0.8).timeout

	_in_battle = false
	if _open_menu == "":
		_set_world_input_enabled(true)

	for child in enemies_root.get_children():
		if child is WorldEnemy:
			(child as WorldEnemy).set_trigger_enabled(true)

	if enemies_root.get_child_count() == 0:
		tip_label.text = "全部敌人已清除！"
