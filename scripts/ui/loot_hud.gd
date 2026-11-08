class_name LootHud
extends CanvasLayer

const MESSAGE_LIFETIME: float = 3.0
const MAX_MESSAGES: int = 3
var _panel: PanelContainer
var _duplicate_pending: GemInstance
var _stash: Stash
var _currency: Label
var _power: Label  ## 装備で強くなった分（ダメージ・ライフ・防御）
var _messages: VBoxContainer
var _recent: Array[Dictionary] = []

func setup(stash: Stash) -> void:
	if _stash != null:
		_stash.changed.disconnect(_refresh)
		_stash.picked_up.disconnect(_on_picked_up)
		_stash.equipped.disconnect(_on_equipped)
		_stash.skipped.disconnect(_on_skipped)
		_stash.duplicate_gem.disconnect(_on_duplicate_gem)
	_stash = stash
	if _stash != null:
		_stash.changed.connect(_refresh)
		_stash.picked_up.connect(_on_picked_up)
		_stash.equipped.connect(_on_equipped)
		_stash.skipped.connect(_on_skipped)
		_stash.duplicate_gem.connect(_on_duplicate_gem)
	_duplicate_pending = null
	_recent.clear()
	_refresh()

func _ready() -> void:
	layer = 20
	var root: Control = Control.new()
	var theme: Theme = Theme.new()
	theme.default_font_size = UiStyle.FONT_STANDARD
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 通貨は、枠なしの小さな文字（撃破数の下）。拾ったものの通知は、通知があるあいだだけ、枠つきで出す
	_currency = Label.new()
	root.add_child(_currency)
	_currency.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_currency.offset_left = -120
	_currency.offset_right = -6
	_currency.offset_top = 24
	_currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.label(_currency, UiStyle.FONT_SMALL, UiStyle.ACCENT)
	_power = Label.new()
	root.add_child(_power)
	_power.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_power.offset_left = -200
	_power.offset_right = -6
	_power.offset_top = 34
	_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.label(_power, UiStyle.FONT_SMALL, StatLabels.INCREASE_COLOR)
	_panel = PanelContainer.new()
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -150
	_panel.offset_right = -6
	_panel.offset_top = 46
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # 枠なし（文字のふちどりだけ）
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_messages = VBoxContainer.new()
	_panel.add_child(_messages)
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()

## 装備で強くなった分の一行（装備がなければ空）。例：ダメージ +45%　ライフ +60　防御 +23
func power_summary() -> String:
	if _stash == null:
		return ""
	var stats: StatBlock = _stash.equipment_stats()
	var parts: Array[String] = []
	var damage: float = stats.get_value("damage_pct")
	if damage > 0.0:
		parts.append("ダメージ +%d%%" % roundi(damage))
	var life: float = stats.get_value("life")
	if life > 0.0:
		parts.append("ライフ +%d" % roundi(life))
	var armor: float = stats.get_value("armor")
	if armor > 0.0:
		parts.append("防御 +%d" % roundi(armor))
	return "　".join(parts)


func _process(delta: float) -> void:
	var expired: bool = false
	for entry: Dictionary in _recent:
		entry["time"] -= delta
	while not _recent.is_empty() and _recent[0]["time"] <= 0.0:
		_recent.pop_front()
		expired = true
	if expired:
		_refresh()

func _on_picked_up(value: Variant) -> void:
	var text: String
	var color: Color = UiStyle.TEXT
	if value is ItemInstance:
		return
	elif value is GemInstance:
		if _duplicate_pending == value:
			_duplicate_pending = null
			return
		text = _gem_name(value)
	else:
		text = "通貨 +%d" % int(value)
		color = UiStyle.ACCENT
	_add_message(text, color)

func _add_message(text: String, color: Color, lines: Array[Dictionary] = []) -> void:
	_recent.append({"text": text, "color": color, "lines": lines, "time": MESSAGE_LIFETIME})
	if _recent.size() > MAX_MESSAGES:
		_recent.pop_front()
	_refresh()

func _gem_name(gem: GemInstance) -> String:
	var definition: RefCounted = DataDB.skill(gem.id) if gem.kind == GemInstance.Kind.SKILL else DataDB.support(gem.id)
	return definition.name if definition != null else gem.id

func _on_equipped(_slot: String, item: ItemInstance, previous: ItemInstance) -> void:
	_add_message("強くなった！ " + item.display_name(), item.rarity.color, StatLabels.changes(item, previous))

func _on_skipped(item: ItemInstance) -> void:
	_add_message("見送り：" + item.display_name(), UiStyle.MUTED)

func _on_duplicate_gem(gem: GemInstance) -> void:
	_duplicate_pending = gem
	_add_message("所持済み：%s / 通貨 +%d" % [_gem_name(gem), Stash.GEM_DUPLICATE_CURRENCY], UiStyle.ACCENT)

func _refresh() -> void:
	if _currency == null:
		return
	_currency.text = "通貨 %d" % (_stash.currency if _stash != null else 0)
	if _power != null:
		_power.text = power_summary()
	if _panel != null:
		_panel.visible = not _recent.is_empty()  # 通知がないときは、枠ごと消す
	for child: Node in _messages.get_children():
		_messages.remove_child(child)
		child.queue_free()
	for entry: Dictionary in _recent:
		var label: Label = Label.new()
		label.text = entry["text"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiStyle.label(label, UiStyle.FONT_STANDARD, entry["color"])
		_messages.add_child(label)
		for line: Dictionary in entry["lines"]:
			var detail: Label = Label.new()
			detail.text = line["text"]
			detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UiStyle.label(detail, UiStyle.FONT_SMALL, line["color"])
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_messages.add_child(detail)
