class_name CharacterStatsPanel
extends PanelContainer
## 角色属性面板。

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var exp_bar: ProgressBar = $Margin/VBox/ExpBar
@onready var exp_label: Label = $Margin/VBox/ExpLabel
@onready var stats_label: RichTextLabel = $Margin/VBox/StatsLabel

var stats: CharacterStats


func bind(target_stats: CharacterStats) -> void:
	if stats != null and stats.changed.is_connected(_refresh):
		stats.changed.disconnect(_refresh)

	stats = target_stats
	if stats == null:
		return

	if not stats.changed.is_connected(_refresh):
		stats.changed.connect(_refresh)

	_refresh()


func set_title(text: String) -> void:
	title_label.text = text


func _refresh() -> void:
	if stats == null:
		return

	title_label.text = "%s  Lv.%d" % [stats.get_display_name(), stats.level]
	exp_bar.max_value = maxf(stats.get_exp_to_next_level(), 1)
	exp_bar.value = stats.experience
	exp_label.text = "经验 %d / %d" % [stats.experience, stats.get_exp_to_next_level()]

	var lines: PackedStringArray = []
	lines.append("[b]生命[/b]  %d / %d" % [stats.hp, stats.get_total_max_hp()])
	lines.append("[b]魔力[/b]  %d / %d" % [stats.mp, stats.get_total_max_mp()])
	lines.append("[b]攻击[/b]  %d  (基础 %d + 加成 %d)" % [
		stats.get_total_attack(), stats.attack, stats.bonus_attack
	])
	lines.append("[b]防御[/b]  %d  (基础 %d + 加成 %d)" % [
		stats.get_total_defense(), stats.defense, stats.bonus_defense
	])
	lines.append("[b]速度[/b]  %d  (基础 %d + 加成 %d)" % [
		stats.get_total_speed(), stats.speed, stats.bonus_speed
	])
	lines.append("[b]状态[/b]  %s" % ("存活" if stats.is_alive else "倒下"))

	if stats.definition and stats.definition.description.strip_edges() != "":
		lines.append("")
		lines.append(stats.definition.description)

	stats_label.text = "\n".join(lines)
