class_name ItemDefinition
extends Resource
## 物品定义资源。

enum ItemType {
	CONSUMABLE,
	EQUIPMENT,
	MATERIAL,
}


@export var id: String = ""
@export var display_name: String = "未命名物品"
@export var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var max_stack: int = 99
@export var heal_amount: int = 0
