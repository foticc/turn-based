extends Control
## 角色面板测试：属性 + 装备 + 背包合并界面。

const WARRIOR_PATH := "res://src/character/definitions/warrior.tres"
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

@onready var inventory: Inventory = $Inventory
@onready var character_sheet: CharacterSheetPanel = $Margin/HBox/CharacterSheetPanel
@onready var log_label: RichTextLabel = $Margin/HBox/Side/LogLabel
@onready var add_buttons: VBoxContainer = $Margin/HBox/Side/AddButtonList

var _stats: CharacterStats
var _equipment: Equipment
var _items: Dictionary = {}


func _ready() -> void:
	_setup_items()
	_setup_character_sheet()
	_connect_buttons()
	_fill_starting_items()
	_append_log("[color=yellow]角色面板测试：属性 / 装备 / 背包已合并[/color]")


func _setup_items() -> void:
	_items.clear()
	for item_id in ITEM_PATHS.keys():
		_items[item_id] = load(ITEM_PATHS[item_id]) as ItemDefinition
	_items["health_potion"] = _create_potion()


func _create_potion() -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = "health_potion"
	item.display_name = "生命药水"
	item.description = "恢复 30 点生命值。"
	item.item_type = ItemDefinition.ItemType.CONSUMABLE
	item.max_stack = 20
	item.heal_amount = 30
	return item


func _setup_character_sheet() -> void:
	var def := load(WARRIOR_PATH) as CharacterDefinition
	_stats = CharacterStats.new(def, 3)
	_equipment = Equipment.new()
	character_sheet.bind(_stats, _equipment, inventory)
	character_sheet.action_logged.connect(_append_log)


func _fill_starting_items() -> void:
	for item_id in ITEM_PATHS.keys():
		inventory.add_item(_items[item_id], 1)
	inventory.add_item(_items["swift_bracelet"], 1)
	inventory.add_item(_items["health_potion"], 2)


func _connect_buttons() -> void:
	$Margin/HBox/Side/UseButton.pressed.connect(character_sheet.use_selected_inventory_item)
	$Margin/HBox/Side/UnequipButton.pressed.connect(character_sheet.unequip_selected_slot)

	for child in add_buttons.get_children():
		child.queue_free()

	for item_id in ITEM_PATHS.keys():
		var item: ItemDefinition = _items[item_id]
		var btn := Button.new()
		btn.text = "+ %s" % item.display_name
		btn.pressed.connect(_add_item.bind(item_id))
		add_buttons.add_child(btn)

	var potion_btn := Button.new()
	potion_btn.text = "+ 生命药水"
	potion_btn.pressed.connect(_add_item.bind("health_potion"))
	add_buttons.add_child(potion_btn)


func _add_item(item_id: String) -> void:
	var item: ItemDefinition = _items[item_id]
	var overflow := inventory.add_item(item, 1)
	if overflow > 0:
		_append_log("[color=red]背包已满[/color]")
	else:
		_append_log("获得 %s" % item.display_name)


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
