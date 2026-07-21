extends Control
## 技能树功能测试：面板只发 unlock_requested，由场景协调层改 SkillTree。

const TREE_DEF_PATH := "res://src/skill_tree/trees/warrior_skill_tree.tres"

@onready var skill_tree_panel: SkillTreePanel = $Margin/VBox/HBox/SkillTreePanel
@onready var log_label: RichTextLabel = $Margin/VBox/HBox/Side/LogLabel
@onready var unlocked_label: RichTextLabel = $Margin/VBox/HBox/Side/UnlockedLabel
@onready var add_point_button: Button = $Margin/VBox/HBox/Side/AddPointButton
@onready var reset_button: Button = $Margin/VBox/HBox/Side/ResetButton
@onready var tip_label: Label = $Margin/VBox/TipLabel

var _tree: SkillTree


func _ready() -> void:
	tip_label.text = "表现层 SkillTreePanel → unlock_requested → 本场景改 SkillTree 数据"
	add_point_button.pressed.connect(_on_add_point_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	_setup_tree(3)
	skill_tree_panel.unlock_requested.connect(_on_unlock_requested)
	skill_tree_panel.node_clicked.connect(_on_node_clicked)


func _setup_tree(starting_points: int) -> void:
	var def := load(TREE_DEF_PATH) as SkillTreeDefinition
	_tree = SkillTree.new(def, starting_points)
	_tree.changed.connect(_refresh_unlocked_list)
	skill_tree_panel.bind(_tree)
	_refresh_unlocked_list()
	_append_log("[color=yellow]技能树测试开始，初始技能点：%d[/color]" % starting_points)


func _on_add_point_pressed() -> void:
	_tree.add_points(1)
	_append_log("获得 1 技能点，当前：%d" % _tree.available_points)


func _on_reset_pressed() -> void:
	log_label.clear()
	_setup_tree(3)
	_append_log("[color=cyan]已重置技能树[/color]")


func _on_node_clicked(node_id: String) -> void:
	_append_log("选中节点：%s" % node_id)


func _on_unlock_requested(node_id: String) -> void:
	if _tree.unlock(node_id):
		var node := _tree.definition.get_node(node_id)
		var node_name := node.display_name if node else node_id
		_append_log("[color=lime]解锁成功：%s[/color]" % node_name)
	else:
		_append_log("[color=orange]解锁失败（%s）[/color]" % node_id)
	_refresh_unlocked_list()


func _refresh_unlocked_list() -> void:
	var lines: PackedStringArray = ["[b]已解锁技能[/b]"]
	var skills := _tree.get_unlocked_skills()
	if skills.is_empty():
		lines.append("（无）")
	else:
		for skill in skills:
			var power_text := ""
			for effect in skill.effects:
				if effect and effect.effect_type == SkillEffect.EffectType.DAMAGE:
					power_text = ", %.1fx" % effect.power_multiplier
					break
			lines.append("- %s（MP%d%s）" % [
				skill.display_name, skill.mp_cost, power_text
			])
	unlocked_label.text = "\n".join(lines)


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
