extends CanvasLayer
## 全局物品提示：悬停显示自定义样式 tip。

@export var show_delay: float = 0.28
@export var cursor_offset: Vector2 = Vector2(18, 14)

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/Margin/VBox/NameLabel
@onready var type_label: Label = $Panel/Margin/VBox/TypeLabel
@onready var desc_label: Label = $Panel/Margin/VBox/DescLabel
@onready var stats_label: RichTextLabel = $Panel/Margin/VBox/StatsLabel
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel

var _delay_timer: Timer
var _pending_item: ItemDefinition = null
var _pending_hint: String = ""
var _visible_for: ItemDefinition = null
var _show_token: int = 0


func _ready() -> void:
	layer = 100
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# CanvasLayer 下的 Control 默认会铺满视口，必须锁成左上角 + 按内容收缩。
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_apply_panel_style()
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	_delay_timer.timeout.connect(_on_delay_timeout)
	add_child(_delay_timer)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.96)
	style.border_color = Color(0.85, 0.72, 0.35, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)


func _process(_delta: float) -> void:
	if panel.visible and panel.modulate.a > 0.0:
		_place_near_cursor()


func request_show(item: ItemDefinition, hint: String = "") -> void:
	if item == null:
		hide_tooltip()
		return
	_pending_item = item
	_pending_hint = hint
	_delay_timer.stop()
	_delay_timer.start(show_delay)


func hide_tooltip() -> void:
	_show_token += 1
	_delay_timer.stop()
	_pending_item = null
	_visible_for = null
	panel.visible = false
	panel.modulate.a = 1.0


func _on_delay_timeout() -> void:
	if _pending_item == null:
		return
	_show_item(_pending_item, _pending_hint)


func _show_item(item: ItemDefinition, hint: String) -> void:
	_visible_for = item
	_show_token += 1
	var token := _show_token

	name_label.text = item.display_name
	type_label.text = _type_line(item)
	desc_label.text = item.description if item.description.strip_edges() != "" else "暂无描述"
	stats_label.text = _stats_bbcode(item)
	stats_label.visible = stats_label.text.strip_edges() != ""
	hint_label.text = hint if hint.strip_edges() != "" else "双击或右键可使用"

	# 先透明显示，等布局算出真实高度后再显现（避免首次悬停高度错误）。
	panel.modulate.a = 0.0
	panel.visible = true
	_fit_panel_to_content()
	_place_near_cursor()
	_finish_show_after_layout(token)


func _finish_show_after_layout(token: int) -> void:
	# 等两帧：Label/RichTextLabel 换行与最小尺寸在首帧后才稳定。
	await get_tree().process_frame
	if token != _show_token or _visible_for == null:
		return
	_fit_panel_to_content()
	_place_near_cursor()

	await get_tree().process_frame
	if token != _show_token or _visible_for == null:
		return
	_fit_panel_to_content()
	_place_near_cursor()
	panel.modulate.a = 1.0


func _fit_panel_to_content() -> void:
	var width := maxf(panel.custom_minimum_size.x, 250.0)
	panel.size = Vector2(width, 0.0)
	if stats_label.visible:
		stats_label.custom_minimum_size = Vector2(width - 40.0, 0.0)
		stats_label.reset_size()
	desc_label.reset_size()
	panel.reset_size()
	var tip_size := panel.get_combined_minimum_size()
	tip_size.x = maxf(tip_size.x, width)
	panel.size = tip_size


func _type_line(item: ItemDefinition) -> String:
	match item.item_type:
		ItemDefinition.ItemType.CONSUMABLE:
			return "消耗品"
		ItemDefinition.ItemType.EQUIPMENT:
			var slot_name := item.get_equip_slot_name()
			return "装备 · %s" % slot_name if slot_name != "" else "装备"
		ItemDefinition.ItemType.MATERIAL:
			return "材料"
		_:
			return "物品"


func _stats_bbcode(item: ItemDefinition) -> String:
	var lines: PackedStringArray = []
	if item.is_equipment():
		if item.bonus_attack != 0:
			lines.append(_bonus_line("攻击", item.bonus_attack))
		if item.bonus_defense != 0:
			lines.append(_bonus_line("防御", item.bonus_defense))
		if item.bonus_speed != 0:
			lines.append(_bonus_line("速度", item.bonus_speed))
		if item.bonus_max_hp != 0:
			lines.append(_bonus_line("生命上限", item.bonus_max_hp))
		if item.bonus_max_mp != 0:
			lines.append(_bonus_line("魔力上限", item.bonus_max_mp))
	elif item.item_type == ItemDefinition.ItemType.CONSUMABLE and item.heal_amount > 0:
		lines.append("[color=#7ddea0]恢复生命 +%d[/color]" % item.heal_amount)
	return "\n".join(lines)


func _bonus_line(stat_name: String, value: int) -> String:
	var sign_text := "+" if value >= 0 else ""
	var color := "#7ddea0" if value >= 0 else "#e88a8a"
	return "[color=%s]%s %s%d[/color]" % [color, stat_name, sign_text, value]


func _place_near_cursor() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var mouse_pos := get_viewport().get_mouse_position()
	var pos := mouse_pos + cursor_offset
	var tip_size := panel.size
	if tip_size.x <= 0.0 or tip_size.y <= 0.0:
		tip_size = panel.get_combined_minimum_size()
	if tip_size.x <= 0.0 or tip_size.y <= 0.0:
		tip_size = Vector2(250, 120)

	if pos.x + tip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tip_size.x - 12.0
	if pos.y + tip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tip_size.y - 12.0

	pos.x = clampf(pos.x, 8.0, maxf(viewport_size.x - tip_size.x - 8.0, 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(viewport_size.y - tip_size.y - 8.0, 8.0))
	panel.position = pos
