class_name LootHud
extends CanvasLayer

const MESSAGE_LIFETIME: float = 4.0
const MAX_MESSAGES: int = 3
var _duplicate_pending: GemInstance
var _stash: Stash
var _currency: Label
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
	theme.default_font_size = 8
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box: VBoxContainer = VBoxContainer.new()
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -174
	box.offset_right = -6
	box.offset_top = 30
	box.offset_bottom = 90
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_currency = Label.new()
	box.add_child(_currency)
	_messages = VBoxContainer.new()
	box.add_child(_messages)
	_refresh()

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
	var color: Color = Color.WHITE
	if value is ItemInstance:
		return
	elif value is GemInstance:
		if _duplicate_pending == value:
			_duplicate_pending = null
			return
		text = _gem_name(value)
	else:
		text = "通貨 +%d" % int(value)
		color = Color("ffd36a")
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
	_add_message("装備した：" + item.display_name(), item.rarity.color, StatLabels.changes(item, previous))

func _on_skipped(item: ItemInstance) -> void:
	_add_message("見送り：" + item.display_name(), Color("8c929b"))

func _on_duplicate_gem(gem: GemInstance) -> void:
	_duplicate_pending = gem
	_add_message("所持済み：%s / 通貨 +%d" % [_gem_name(gem), Stash.GEM_DUPLICATE_CURRENCY], Color("ffd36a"))

func _refresh() -> void:
	if _currency == null:
		return
	_currency.text = "通貨: %d" % (_stash.currency if _stash != null else 0)
	for child: Node in _messages.get_children():
		_messages.remove_child(child)
		child.queue_free()
	for entry: Dictionary in _recent:
		var label: Label = Label.new()
		label.text = entry["text"]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", entry["color"])
		_messages.add_child(label)
		for line: Dictionary in entry["lines"]:
			var detail: Label = Label.new()
			detail.text = "  " + line["text"]
			detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			detail.add_theme_color_override("font_color", line["color"])
			_messages.add_child(detail)
