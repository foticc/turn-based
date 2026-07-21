class_name SkillTreePanel
extends PanelContainer
## 技能树面板：显示节点、连线，支持点击解锁。

signal node_clicked(node_id: String)
## 表现层只发意图，由 PlayerState / 场景协调层执行解锁。
signal unlock_requested(node_id: String)

const NODE_SIZE := Vector2(140, 64)

@onready var title_label: Label = $Margin/VBox/Header/TitleLabel
@onready var points_label: Label = $Margin/VBox/Header/PointsLabel
@onready var canvas: Control = $Margin/VBox/Scroll/Canvas
@onready var lines: Node2D = $Margin/VBox/Scroll/Canvas/Lines
@onready var nodes_root: Control = $Margin/VBox/Scroll/Canvas/Nodes
@onready var detail_label: RichTextLabel = $Margin/VBox/DetailLabel

var skill_tree: SkillTree
var _node_buttons: Dictionary = {} # id -> Button


func bind(tree: SkillTree) -> void:
	if skill_tree != null and skill_tree.changed.is_connected(_refresh):
		skill_tree.changed.disconnect(_refresh)

	skill_tree = tree
	if skill_tree == null:
		return

	if not skill_tree.changed.is_connected(_refresh):
		skill_tree.changed.connect(_refresh)

	if skill_tree.definition:
		title_label.text = skill_tree.definition.display_name

	_rebuild_nodes()
	_refresh()


func _rebuild_nodes() -> void:
	for child in nodes_root.get_children():
		child.queue_free()
	_node_buttons.clear()

	if skill_tree == null or skill_tree.definition == null:
		return

	var max_pos := Vector2(400, 300)
	for node_def in skill_tree.definition.nodes:
		if node_def == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = NODE_SIZE
		btn.position = node_def.ui_position
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = _build_node_tooltip(node_def)
		btn.pressed.connect(_on_node_pressed.bind(node_def.id))
		nodes_root.add_child(btn)
		_node_buttons[node_def.id] = btn
		max_pos.x = maxf(max_pos.x, node_def.ui_position.x + NODE_SIZE.x + 40.0)
		max_pos.y = maxf(max_pos.y, node_def.ui_position.y + NODE_SIZE.y + 40.0)

	canvas.custom_minimum_size = max_pos


func _refresh() -> void:
	if skill_tree == null or skill_tree.definition == null:
		return

	points_label.text = "技能点: %d" % skill_tree.available_points
	_draw_connection_lines()

	for node_def in skill_tree.definition.nodes:
		if node_def == null:
			continue
		var btn: Button = _node_buttons.get(node_def.id)
		if btn == null:
			continue

		var unlocked := skill_tree.is_unlocked(node_def.id)
		var can := skill_tree.can_unlock(node_def.id)
		var cost_text := "已解锁" if unlocked else "消耗 %d 点" % node_def.point_cost
		btn.text = "%s\n%s" % [node_def.display_name, cost_text]
		# 不用 disabled，否则悬停 tip 不会显示
		btn.disabled = false
		btn.tooltip_text = _build_node_tooltip(node_def)

		if unlocked:
			btn.modulate = Color(0.55, 1.0, 0.65)
		elif can:
			btn.modulate = Color(1.0, 0.95, 0.55)
		else:
			btn.modulate = Color(0.7, 0.7, 0.75)


func _draw_connection_lines() -> void:
	for child in lines.get_children():
		child.queue_free()

	if skill_tree == null or skill_tree.definition == null:
		return

	for node_def in skill_tree.definition.nodes:
		if node_def == null:
			continue
		var to_btn: Button = _node_buttons.get(node_def.id)
		if to_btn == null:
			continue
		var to_center := to_btn.position + NODE_SIZE * 0.5
		for prereq_id in node_def.prerequisite_ids:
			var from_btn: Button = _node_buttons.get(prereq_id)
			if from_btn == null:
				continue
			var from_center := from_btn.position + NODE_SIZE * 0.5
			var unlocked_link := skill_tree.is_unlocked(prereq_id) and skill_tree.is_unlocked(node_def.id)
			var line := Line2D.new()
			line.width = 3.0
			line.default_color = Color(0.45, 0.9, 0.5, 0.9) if unlocked_link else Color(0.55, 0.55, 0.65, 0.7)
			line.add_point(from_center)
			line.add_point(to_center)
			lines.add_child(line)


func _on_node_pressed(node_id: String) -> void:
	node_clicked.emit(node_id)
	_show_detail(node_id)

	if skill_tree == null:
		return
	if skill_tree.is_unlocked(node_id):
		return

	unlock_requested.emit(node_id)


func _show_detail(node_id: String) -> void:
	if skill_tree == null or skill_tree.definition == null:
		return
	var node_def := skill_tree.definition.get_node(node_id)
	if node_def == null:
		return

	var state := "已解锁" if skill_tree.is_unlocked(node_id) else (
		"可解锁" if skill_tree.can_unlock(node_id) else "未满足条件"
	)
	var tip := _build_node_tooltip(node_def)
	# tip 首行已是技能名，详情区再标状态即可
	detail_label.text = "[b]%s[/b]  (%s)\n%s" % [
		node_def.display_name,
		state,
		tip,
	]


func _build_node_tooltip(node_def: SkillTreeNodeDefinition) -> String:
	var tip_lines: PackedStringArray = []
	if node_def.skill:
		tip_lines.append(node_def.skill.get_tooltip_text())
	else:
		tip_lines.append(node_def.display_name)
		if node_def.description.strip_edges() != "":
			tip_lines.append(node_def.description)

	if node_def.description.strip_edges() != "" and node_def.skill:
		# 节点额外说明（与技能描述不同时补充）
		if node_def.description != node_def.skill.description:
			tip_lines.append("")
			tip_lines.append(node_def.description)

	if skill_tree:
		if skill_tree.is_unlocked(node_def.id):
			tip_lines.append("")
			tip_lines.append("状态: 已解锁")
		elif skill_tree.can_unlock(node_def.id):
			tip_lines.append("")
			tip_lines.append("状态: 可解锁（消耗 %d 点）" % node_def.point_cost)
		else:
			tip_lines.append("")
			tip_lines.append("状态: %s" % _unlock_fail_reason(node_def.id))

	return "\n".join(tip_lines)


func _unlock_fail_reason(node_id: String) -> String:
	var node_def := skill_tree.definition.get_node(node_id)
	if node_def == null:
		return "节点不存在"
	if skill_tree.available_points < node_def.point_cost:
		return "技能点不足"
	for prereq in node_def.prerequisite_ids:
		if not skill_tree.is_unlocked(prereq):
			var prereq_node := skill_tree.definition.get_node(prereq)
			var prereq_name := prereq_node.display_name if prereq_node else prereq
			return "需要先解锁：%s" % prereq_name
	return "无法解锁"
