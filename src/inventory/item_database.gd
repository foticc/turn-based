class_name ItemDatabase
extends Resource
## 物品总表：按 id 查询，场景不再各自维护 ITEM_PATHS。

const DEFAULT_PATH := "res://src/inventory/item_database.tres"

@export var items: Array[ItemDefinition] = []

var _by_id: Dictionary = {}


static func load_default() -> ItemDatabase:
	var db := load(DEFAULT_PATH) as ItemDatabase
	if db == null:
		push_error("无法加载物品库: %s" % DEFAULT_PATH)
		return ItemDatabase.new()
	db.rebuild_index()
	return db


func rebuild_index() -> void:
	_by_id.clear()
	for item in items:
		if item == null or item.id.strip_edges() == "":
			continue
		if _by_id.has(item.id):
			push_warning("物品库重复 id: %s" % item.id)
		_by_id[item.id] = item


func ensure_index() -> void:
	if _by_id.is_empty() and not items.is_empty():
		rebuild_index()


func get_item(item_id: String) -> ItemDefinition:
	ensure_index()
	return _by_id.get(item_id) as ItemDefinition


func has_item(item_id: String) -> bool:
	ensure_index()
	return _by_id.has(item_id)


func get_all() -> Array[ItemDefinition]:
	ensure_index()
	var result: Array[ItemDefinition] = []
	for key in _by_id.keys():
		result.append(_by_id[key])
	return result


func get_all_ids() -> PackedStringArray:
	ensure_index()
	var ids := PackedStringArray(_by_id.keys())
	ids.sort()
	return ids


## 若 .tres 数组未填上，可按目录扫描补齐（编辑器调试兜底）。
func merge_from_paths(paths: PackedStringArray) -> void:
	for path in paths:
		var item := load(path) as ItemDefinition
		if item == null or item.id.strip_edges() == "":
			continue
		var found := false
		for existing in items:
			if existing and existing.id == item.id:
				found = true
				break
		if not found:
			items.append(item)
	rebuild_index()
