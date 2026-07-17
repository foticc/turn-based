class_name ItemDefinition
extends Resource
## 物品定义资源。

enum ItemType {
	CONSUMABLE,
	EQUIPMENT,
	MATERIAL,
}

enum EquipSlot {
	NONE,
	WEAPON, ## 武器
	HELMET, ## 头冠
	CLOTHES, ## 衣服
	SHOES, ## 鞋子
	BELT, ## 腰带
	JADE_PENDANT, ## 玉佩
	NECKLACE, ## 项链
	BRACELET_LEFT, ## 左手镯
	BRACELET_RIGHT, ## 右手镯
	BRACELET, ## 手镯（穿戴时自动选择空闲手镯槽）
}


@export var id: String = ""
@export var display_name: String = "未命名物品"
@export var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MATERIAL
@export var max_stack: int = 99
@export var heal_amount: int = 0

@export_group("装备")
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_speed: int = 0
@export var bonus_max_hp: int = 0
@export var bonus_max_mp: int = 0


func is_equipment() -> bool:
	return item_type == ItemType.EQUIPMENT and equip_slot != EquipSlot.NONE


static func get_slot_display_name(slot: EquipSlot) -> String:
	match slot:
		EquipSlot.WEAPON:
			return "武器"
		EquipSlot.HELMET:
			return "头冠"
		EquipSlot.CLOTHES:
			return "衣服"
		EquipSlot.SHOES:
			return "鞋子"
		EquipSlot.BELT:
			return "腰带"
		EquipSlot.JADE_PENDANT:
			return "玉佩"
		EquipSlot.NECKLACE:
			return "项链"
		EquipSlot.BRACELET_LEFT:
			return "左手镯"
		EquipSlot.BRACELET_RIGHT:
			return "右手镯"
		EquipSlot.BRACELET:
			return "手镯"
		_:
			return ""


func get_equip_slot_name() -> String:
	return ItemDefinition.get_slot_display_name(equip_slot)


func get_tooltip_text() -> String:
	var lines: PackedStringArray = [display_name]
	if description.strip_edges() != "":
		lines.append(description)
	if is_equipment():
		lines.append("部位: %s" % get_equip_slot_name())
		if bonus_attack != 0:
			lines.append("攻击 +%d" % bonus_attack)
		if bonus_defense != 0:
			lines.append("防御 +%d" % bonus_defense)
		if bonus_speed != 0:
			lines.append("速度 +%d" % bonus_speed)
		if bonus_max_hp != 0:
			lines.append("生命上限 +%d" % bonus_max_hp)
		if bonus_max_mp != 0:
			lines.append("魔力上限 +%d" % bonus_max_mp)
	elif item_type == ItemDefinition.ItemType.CONSUMABLE and heal_amount > 0:
		lines.append("恢复生命 %d" % heal_amount)
	return "\n".join(lines)
