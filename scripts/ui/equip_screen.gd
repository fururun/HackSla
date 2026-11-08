class_name EquipScreen
extends CanvasLayer

const SLOT_NAMES: Dictionary = {
	"weapon": "武器", "armor": "胴防具", "helmet": "兜",
	"boots": "靴", "ring": "指輪", "amulet": "首飾り",
}
var _stash: Stash
var _vitals: PlayerVitals
var _opened: bool = false
var _was_paused: bool = false
var _selected: String = "weapon"
var _root: Control
var _slots: VBoxContainer
var _totals: VBoxContainer
var _details: VBoxContainer

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90

func setup(stash: Stash, vitals: PlayerVitals) -> void:
	if _stash != null and _stash.changed.is_connected(_refresh):
		_stash.changed.disconnect(_refresh)
	if _vitals != null and _vitals.changed.is_connected(_refresh):
		_vitals.changed.disconnect(_refresh)
	_stash = stash
	_vitals = vitals
	if _stash != null:
		_stash.changed.connect(_refresh)
	if _vitals != null:
		_vitals.changed.connect(_refresh)
	_refresh()

func _ready() -> void:
	_build_ui()
	_root.visible = _opened

func open() -> void:
	if _opened or not is_inside_tree():
		return
	_was_paused = get_tree().paused
	_opened = true
	get_tree().paused = true
	_root.show()
	_refresh()

func close() -> void:
	if not _opened:
		return
	_opened = false
	if is_inside_tree():
		get_tree().paused = _was_paused
	if _root != null:
		_root.hide()

func toggle() -> void:
	if _opened:
		close()
	else:
		open()

func is_open() -> bool:
	return _opened

func _exit_tree() -> void:
	close()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_equip_screen") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

## 描画なしでも6部位と性能を調べられる。
func slot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for slot: String in SLOT_NAMES:
		var item: ItemInstance = _stash.equipment.get(slot) if _stash != null else null
		entries.append({"slot": slot, "name": item.display_name() if item != null else "—",
			"color": item.rarity.color if item != null else SkillScreen.TEXT_COLOR,
			"stats": item.total_stats() if item != null else {}})
	return entries

func _build_ui() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme: Theme = Theme.new()
	theme.default_font_size = SkillScreen.FONT_SIZE
	_root.theme = theme
	_root.add_theme_color_override("font_color", SkillScreen.TEXT_COLOR)
	var backdrop: ColorRect = ColorRect.new()
	_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("0d111bef")
	var title: Label = _label("装備  /  ゲーム停止中")
	title.position = Vector2(12, 8)
	title.size = Vector2(350, 18)
	_root.add_child(title)
	var button: Button = Button.new()
	button.text = "閉じる [I]"
	button.position = Vector2(394, 6)
	button.size = Vector2(74, 18)
	button.pressed.connect(close)
	_root.add_child(button)
	_slots = _panel(Vector2(12, 32), Vector2(252, 208))
	_totals = _panel(Vector2(274, 32), Vector2(194, 122))
	_details = _panel(Vector2(274, 164), Vector2(194, 76))
	var help: Label = _label("部位をクリックすると、付与効果をすべて表示")
	help.position = Vector2(12, 251)
	help.size = Vector2(456, 18)
	_root.add_child(help)

func _panel(at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = at
	panel.size = dimensions
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SkillScreen.PANEL_COLOR
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)
	return box

func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _select(slot: String) -> void:
	_selected = slot
	_refresh()

func _refresh() -> void:
	if not _opened or _slots == null:
		return
	_clear(_slots)
	_clear(_totals)
	_clear(_details)
	for entry: Dictionary in slot_entries():
		var button: Button = Button.new()
		button.text = SLOT_NAMES[entry["slot"]] + "  " + entry["name"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", entry["color"])
		button.pressed.connect(_select.bind(entry["slot"]))
		_slots.add_child(button)
		var values: PackedStringArray = []
		for key: String in entry["stats"]:
			values.append(StatLabels.stat_line(key, float(entry["stats"][key])))
		if not values.is_empty():
			_slots.add_child(_label(" / ".join(values)))
	_totals.add_child(_label("いまの合計 / 装備全体"))
	if _vitals != null:
		_totals.add_child(_label("最大ライフ（現在） %s" % String.num(_vitals.max_life(), 2)))
	# 実際にあるキーを集計し、将来データに未知のキーが増えても表示する。
	var sums: Dictionary = {}
	if _stash != null:
		for item: ItemInstance in _stash.equipment.values():
			var values: Dictionary = item.total_stats()
			for key: String in values:
				sums[key] = float(sums.get(key, 0.0)) + float(values[key])
	for key: String in sums:
		_totals.add_child(_label(StatLabels.stat_line(key, float(sums[key]))))
	if sums.is_empty():
		_totals.add_child(_label("装備なし"))
	_details.add_child(_label(SLOT_NAMES[_selected] + " / 付与効果"))
	var selected: ItemInstance = _stash.equipment.get(_selected) if _stash != null else null
	if selected == null or selected.affixes.is_empty():
		_details.add_child(_label("—" if selected == null else "付与効果なし"))
	else:
		for rolled: Dictionary in selected.affixes:
			var affix: AffixDef = DataDB.affixes[rolled["id"]]
			_details.add_child(_label(affix.name + "  " + StatLabels.stat_line(affix.stat, float(rolled["value"]))))
