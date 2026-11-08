class_name SkillScreen
extends CanvasLayer
## 仮の装備画面。一覧の供給元は後で所持品へ差し替えられる。

const VISIBLE_SLOTS: int = 2
const FONT_SIZE: int = UiStyle.FONT_STANDARD
const PANEL_COLOR: Color = UiStyle.PANEL
const TEXT_COLOR: Color = UiStyle.TEXT
const ACCENT_COLOR: Color = UiStyle.ACCENT
const TAG_NAMES: Dictionary = {
	"physical": "物理", "fire": "火", "cold": "冷気", "lightning": "雷",
	"melee": "近接", "projectile": "飛び道具", "area": "範囲",
	"movement": "移動", "totem": "設置",
}
const MOD_NAMES: Dictionary = {
	"damage_mult": "ダメージ倍率", "area_mult": "範囲倍率",
	"cooldown_mult": "再使用時間倍率", "projectile_count": "追加弾数",
	"hop_count": "伝播回数", "explode_on_kill": "撃破時爆発の確率",
	"explode_damage_ratio": "爆発 / 敵最大ライフ",
	"chain_damage_mult": "チェイン威力倍率", "chain_area_mult": "チェイン範囲倍率",
}

var stash: Stash
var _caster: SkillCaster
var _opened: bool = false
var _was_paused: bool = false
var _selected_slot: int = 1
var _select_support: bool = false
var _root: Control
var _slots: VBoxContainer
var _choices: VBoxContainer
var _choice_title: Label
var _details: Label
var _chains: VBoxContainer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90


func setup(caster: SkillCaster, inventory: Stash = null) -> void:
	if stash != null and stash.changed.is_connected(_refresh):
		stash.changed.disconnect(_refresh)
	stash = inventory
	if stash != null:
		stash.changed.connect(_refresh)
	if is_instance_valid(_caster) and _caster.loadout.changed.is_connected(_on_loadout_changed):
		_caster.loadout.changed.disconnect(_on_loadout_changed)
	_caster = caster
	if is_instance_valid(_caster):
		_caster.loadout.changed.connect(_on_loadout_changed)
	_refresh()


func _ready() -> void:
	_build_ui()
	_root.visible = _opened
	_refresh()


func open() -> void:
	if _opened or not is_inside_tree():
		return
	_was_paused = get_tree().paused
	_opened = true
	get_tree().paused = true
	if _root != null:
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
	if event.is_action_pressed("toggle_skill_screen") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _available_skills() -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for skill: SkillDef in DataDB.skills.values():
		if not skill.chain_only and (stash == null or stash.has_gem(GemInstance.Kind.SKILL, skill.id)):
			out.append(skill)
	return out


func _available_supports(slot: int) -> Array[SupportDef]:
	var out: Array[SupportDef] = []
	if not is_instance_valid(_caster):
		return out
	var skill: SkillDef = _caster.loadout.skill(slot)
	if skill == null:
		return out
	for support: SupportDef in DataDB.supports.values():
		if support.can_support(skill) and (stash == null or stash.has_gem(GemInstance.Kind.SUPPORT, support.id)):
			out.append(support)
	return out


func _equip(id: String) -> bool:
	if not is_instance_valid(_caster):
		return false
	if _select_support:
		for support: SupportDef in _available_supports(_selected_slot):
			if support.id == id:
				return _caster.loadout.set_support(_selected_slot, id)
	else:
		for skill: SkillDef in _available_skills():
			if skill.id == id:
				return _caster.loadout.set_skill(_selected_slot, id)
	return false


func _chain_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for rule: ChainRule in DataDB.chains:
		var known: bool = is_instance_valid(_caster) and _caster.chain.discovered.has(rule.id)
		entries.append({"known": known, "name": rule.name if known else "？",
			"description": rule.description if known else ""})
	return entries


func _discovered_count() -> int:
	var count: int = 0
	for entry: Dictionary in _chain_entries():
		if entry["known"]:
			count += 1
	return count


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	_root.theme = theme
	_root.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(_root)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var title: Label = _label("スキル装備  /  ゲーム停止中")
	UiStyle.label(title, UiStyle.FONT_HEADING, UiStyle.ACCENT)
	title.position = Vector2(12, 8)
	_root.add_child(title)
	var close_button: Button = _button("閉じる [K]")
	close_button.position = Vector2(394, 6)
	close_button.size = Vector2(74, 18)
	close_button.pressed.connect(close)
	_root.add_child(close_button)
	_slots = _panel(Vector2(12, 32), Vector2(158, 138))
	var right: VBoxContainer = _panel(Vector2(180, 32), Vector2(288, 138))
	_choice_title = _label("")
	right.add_child(_choice_title)
	_choices = _scroll_box(right, 84)
	_details = _label("")
	UiStyle.label(_details, UiStyle.FONT_SMALL, UiStyle.MUTED)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_details)
	var bottom: VBoxContainer = _panel(Vector2(12, 180), Vector2(456, 64))
	_chains = _scroll_box(bottom, 54)
	var help: Label = _label("左: 枠を選択 → 右: 候補をクリックで装備   /   枠を右クリックで外す")
	UiStyle.label(help, UiStyle.FONT_SMALL, UiStyle.MUTED)
	help.position = Vector2(12, 251)
	_root.add_child(help)


func _panel(at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = at
	panel.size = dimensions
	var style: StyleBoxFlat = UiStyle.panel()
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	return box


func _scroll_box(parent: Control, height: float) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	return box


func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	UiStyle.label(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	UiStyle.button(button)
	return button


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _refresh() -> void:
	if _root == null:
		return
	_clear_children(_slots)
	_slots.add_child(_label("装備枠  /  補助は各1個"))
	for slot: int in range(1, VISIBLE_SLOTS + 1):
		var skill: SkillDef = _caster.loadout.skill(slot) if is_instance_valid(_caster) else null
		var support: SupportDef = _caster.loadout.support(slot) if is_instance_valid(_caster) else null
		_slots.add_child(_label("枠 %d  /  %s" % [slot, _skill_tags(skill) if skill != null else "—"]))
		_slot_button(slot, false, skill.name if skill != null else "—")
		_slot_button(slot, true, "補助: " + (support.name if support != null else "—"))
		_slots.add_child(_label("対応: " + _kinds(support.kinds) if support != null else "対応: —"))
	_refresh_choices()
	_clear_children(_chains)
	_chains.add_child(_label("チェイン図鑑   発見 %d / 未発見 %d" % [_discovered_count(), DataDB.chains.size() - _discovered_count()]))
	for entry: Dictionary in _chain_entries():
		var label: Label = _label(entry["name"] + ("  /  " + entry["description"] if entry["known"] else ""))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_chains.add_child(label)


func _slot_button(slot: int, support: bool, text: String) -> void:
	var button: Button = _button(text)
	if slot == _selected_slot and support == _select_support:
		button.add_theme_color_override("font_color", ACCENT_COLOR)
	button.pressed.connect(_select.bind(slot, support))
	button.gui_input.connect(_slot_input.bind(slot, support))
	_slots.add_child(button)


func _select(slot: int, support: bool) -> void:
	_selected_slot = slot
	_select_support = support
	_refresh()


func _slot_input(event: InputEvent, slot: int, support: bool) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	if is_instance_valid(_caster):
		if support:
			_caster.loadout.clear_support(slot)
		else:
			_caster.loadout.clear_skill(slot)
	get_viewport().set_input_as_handled()


func _refresh_choices() -> void:
	_clear_children(_choices)
	_choice_title.text = "枠 %d  /  %sを選ぶ" % [_selected_slot, "補助ジェム" if _select_support else "スキル"]
	_details.text = "候補にマウスを重ねると性能を表示"
	if _select_support:
		for support: SupportDef in _available_supports(_selected_slot):
			_add_choice(support.id, support.name, support.description, _support_values(support))
	else:
		for skill: SkillDef in _available_skills():
			_add_choice(skill.id, skill.name + "  [" + _skill_tags(skill) + "]", skill.description,
				"ダメージ %s–%s / 再使用 %s秒 / 射程 %s / 半径 %s / 速度 %s" % [skill.damage_min, skill.damage_max, skill.cooldown, skill.range, skill.radius, skill.speed])
	if _choices.get_child_count() == 0:
		_choices.add_child(_label("付けられる補助なし / 先にスキルを装備"))


func _add_choice(id: String, title: String, description: String, values: String) -> void:
	var button: Button = _button(title)
	button.pressed.connect(_choose.bind(id, values))
	button.mouse_entered.connect(_show_details.bind(values))
	_choices.add_child(button)
	var label: Label = _label(description)
	UiStyle.label(label, UiStyle.FONT_SMALL, UiStyle.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choices.add_child(label)


func _choose(id: String, values: String) -> void:
	if _equip(id):
		_show_details(values)


func _show_details(values: String) -> void:
	_details.text = values


func _skill_tags(skill: SkillDef) -> String:
	return str(TAG_NAMES.get(skill.element, skill.element)) + " / " + str(TAG_NAMES.get(skill.kind, skill.kind))


func _kinds(kinds: PackedStringArray) -> String:
	var names: PackedStringArray = []
	for kind: String in kinds:
		names.append(str(TAG_NAMES.get(kind, kind)))
	return "全種類" if names.is_empty() else "・".join(names)


func _support_values(support: SupportDef) -> String:
	var values: PackedStringArray = []
	for key: String in support.modifiers:
		values.append("%s %s" % [MOD_NAMES.get(key, key), float(support.modifiers[key])])
	return " / ".join(values)


func _on_loadout_changed(_slot: int) -> void:
	_refresh()
