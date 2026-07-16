class_name SkillTree
extends RefCounted
## 技能树运行时状态：技能点、解锁进度。

signal changed
signal node_unlocked(node_id: String)

var definition: SkillTreeDefinition
var available_points: int = 0
var _unlocked: Dictionary = {} # node_id -> true


func _init(tree_def: SkillTreeDefinition = null, starting_points: int = 0) -> void:
	definition = tree_def
	available_points = starting_points
	if definition:
		for node in definition.nodes:
			if node and node.unlocked_by_default:
				_unlocked[node.id] = true


func is_unlocked(node_id: String) -> bool:
	return _unlocked.get(node_id, false)


func can_unlock(node_id: String) -> bool:
	if definition == null or is_unlocked(node_id):
		return false
	var node := definition.get_node(node_id)
	if node == null:
		return false
	if available_points < node.point_cost:
		return false
	for prereq in node.prerequisite_ids:
		if not is_unlocked(prereq):
			return false
	return true


func unlock(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	var node := definition.get_node(node_id)
	available_points -= node.point_cost
	_unlocked[node_id] = true
	node_unlocked.emit(node_id)
	changed.emit()
	return true


func add_points(amount: int) -> void:
	if amount == 0:
		return
	available_points = maxi(available_points + amount, 0)
	changed.emit()


func get_unlocked_skills() -> Array[SkillDefinition]:
	var skills: Array[SkillDefinition] = []
	if definition == null:
		return skills
	for node in definition.nodes:
		if node == null or node.skill == null:
			continue
		if is_unlocked(node.id):
			skills.append(node.skill)
	return skills


func get_unlocked_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for node_id in _unlocked.keys():
		if _unlocked[node_id]:
			ids.append(node_id)
	return ids
