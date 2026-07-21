extends Control
## 分层架构测试：数据层 PlayerState vs 表现层 UI。
## 验证：UI 只发意图；装备/技能进战斗快照；物品一律走 ItemDatabase。

@onready var layer_label: RichTextLabel = $Margin/HBox/Left/LayerLabel
@onready var snapshot_label: RichTextLabel = $Margin/HBox/Left/SnapshotLabel
@onready var log_label: RichTextLabel = $Margin/HBox/Left/LogLabel
@onready var character_sheet: CharacterSheetPanel = $Margin/HBox/Center/CharacterSheetPanel
@onready var skill_tree_panel: SkillTreePanel = $Margin/HBox/Right/SkillTreePanel
@onready var item_list: ItemList = $Margin/HBox/Left/ItemList

var _player: PlayerState


func _ready() -> void:
	_player = PlayerState.create_default(3, 5, 24)
	_player.grant_starting_kit()
	_player.action_logged.connect(_append_log)
	_player.changed.connect(_refresh_snapshot)

	character_sheet.bind_player(_player)
	skill_tree_panel.bind(_player.skill_tree)
	skill_tree_panel.unlock_requested.connect(_on_unlock_requested)

	$Margin/HBox/Left/Buttons/DamageButton.pressed.connect(_on_damage_pressed)
	$Margin/HBox/Left/Buttons/HealButton.pressed.connect(_on_heal_pressed)
	$Margin/HBox/Left/Buttons/SnapshotButton.pressed.connect(_refresh_snapshot)
	$Margin/HBox/Left/GrantSelectedButton.pressed.connect(_on_grant_selected)
	$Margin/HBox/Left/Buttons/AddPointButton.pressed.connect(_on_add_point)

	_fill_item_list()
	_refresh_layer_doc()
	_refresh_snapshot()
	_append_log("[color=yellow]架构测试就绪：左侧数据操作，中间/右侧为表现层[/color]")


func _fill_item_list() -> void:
	item_list.clear()
	for item_id in _player.items.get_all_ids():
		var item := _player.get_item(item_id)
		if item:
			item_list.add_item("%s  (%s)" % [item.display_name, item.id])
			item_list.set_item_metadata(item_list.item_count - 1, item.id)


func _refresh_layer_doc() -> void:
	layer_label.text = "\n".join([
		"[b]数据层 (src/)[/b]",
		"• PlayerState",
		"• ItemDatabase / ItemDefinition",
		"• CharacterStats / Equipment / Inventory",
		"• SkillTree / BattleUnit",
		"",
		"[b]表现层 (scenes/)[/b]",
		"• CharacterSheetPanel / SkillTreePanel",
		"• 只 bind + 发意图，不写业务",
		"",
		"[b]协调[/b]",
		"• 本测试场景 / world_battle_test",
		"• 调用 PlayerState 用例",
	])


func _refresh_snapshot() -> void:
	var unit := _player.create_battle_unit("preview")
	var skill_names: PackedStringArray = []
	for skill in unit.get_skills():
		skill_names.append(skill.display_name)

	snapshot_label.text = "\n".join([
		"[b]战斗快照 create_battle_unit()[/b]",
		"名称: %s" % unit.display_name,
		"HP: %d / %d" % [unit.hp, unit.max_hp],
		"MP: %d / %d" % [unit.mp, unit.max_mp],
		"攻击: %d  防御: %d  速度: %d" % [unit.attack_power, unit.defense, unit.speed],
		"技能: %s" % (", ".join(skill_names) if not skill_names.is_empty() else "（无，去技能树解锁）"),
		"",
		"[color=gray]装备加成会进入攻击/防御/生命；解锁技能会出现在列表。[/color]",
	])


func _on_damage_pressed() -> void:
	var dealt := _player.stats.take_damage(25)
	_append_log("数据层直接扣血：实际伤害 %d，当前 HP %d" % [dealt, _player.stats.hp])
	_refresh_snapshot()


func _on_heal_pressed() -> void:
	var healed := _player.stats.heal(40)
	_append_log("数据层直接治疗：+%d，当前 HP %d" % [healed, _player.stats.hp])
	_refresh_snapshot()


func _on_grant_selected() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		_append_log("[color=gray]请先在物品库列表中选一项[/color]")
		return
	var item_id: String = item_list.get_item_metadata(selected[0])
	_player.grant_item(item_id, 1)


func _on_add_point() -> void:
	_player.skill_tree.add_points(1)
	_append_log("获得 1 技能点，当前：%d" % _player.skill_tree.available_points)


func _on_unlock_requested(node_id: String) -> void:
	_player.unlock_skill_node(node_id)
	_refresh_snapshot()


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
