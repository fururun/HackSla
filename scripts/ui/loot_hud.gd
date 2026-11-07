class_name LootHud
extends CanvasLayer

const MESSAGE_LIFETIME: float = 4.0
const MAX_MESSAGES: int = 3
var _stash: Stash
var _currency: Label
var _messages: VBoxContainer
var _recent: Array[Dictionary] = []

func setup(stash: Stash) -> void:
	if _stash != null:
		_stash.changed.disconnect(_refresh)
		_stash.picked_up.disconnect(_on_picked_up)
	_stash = stash
	if _stash != null:
		_stash.changed.connect(_refresh)
		_stash.picked_up.connect(_on_picked_up)
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
		text = value.display_name()
		color = value.rarity.color
	elif value is GemInstance:
		var definition: RefCounted = DataDB.skill(value.id) if value.kind == GemInstance.Kind.SKILL else DataDB.support(value.id)
		text = definition.name if definition != null else value.id
	else:
		text = "通貨 +%d" % int(value)
		color = Color("ffd36a")
	_recent.append({"text": text, "color": color, "time": MESSAGE_LIFETIME})
	if _recent.size() > MAX_MESSAGES:
		_recent.pop_front()
	_refresh()

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
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", entry["color"])
		_messages.add_child(label)
