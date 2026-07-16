class_name SkillTreeNodeDefinition
extends Resource
## 技能树单个节点配置。

@export var id: String = "node"
@export var display_name: String = "节点"
@export_multiline var description: String = ""
@export var skill: SkillDefinition
## 解锁消耗的技能点
@export var point_cost: int = 1
## 前置节点 id 列表，全部解锁后才可点本节点
@export var prerequisite_ids: PackedStringArray = []
## UI 中的位置（面板本地坐标）
@export var ui_position: Vector2 = Vector2.ZERO
## 开局是否已解锁
@export var unlocked_by_default: bool = false
