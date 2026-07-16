class_name SkillTreeDefinition
extends Resource
## 一整棵技能树的配置。

@export var id: String = "tree"
@export var display_name: String = "技能树"
@export var nodes: Array[SkillTreeNodeDefinition] = []


func get_node(node_id: String) -> SkillTreeNodeDefinition:
	for node in nodes:
		if node and node.id == node_id:
			return node
	return null


func get_node_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for node in nodes:
		if node:
			ids.append(node.id)
	return ids
