class_name SkillBar
extends CanvasLayer
## ゲーム状態は変更せずに読む。初期3枠と、後方に装備された枠までを表示。
const SLOT_SIZE: Vector2 = Vector2(32, 42)
const GAP: float = 4.0
const BAR_SCALE: float = 0.7  ## 画面にかぶらないよう、全体を小さく描く
const IDLE_ALPHA: float = 0.6  ## どれも再使用待ちでないときは、うすくする
const FLASH_TIME: float = 0.22
const INPUT_SETUP: Script = preload("res://scripts/core/input_setup.gd")
var _caster: SkillCaster
var _vitals: PlayerVitals  ## マナが足りないスキルを、うす青く示すため（空でもよい）
var _root: Control
var _slots: Array[Dictionary] = []

func setup(caster: SkillCaster, vitals: PlayerVitals = null) -> void:
	_vitals = vitals
	if is_instance_valid(_caster):
		if _caster.loadout.changed.is_connected(_loadout_changed):
			_caster.loadout.changed.disconnect(_loadout_changed)
		if _caster.cast_done.is_connected(_cast_done):
			_caster.cast_done.disconnect(_cast_done)
	_caster = caster
	if is_instance_valid(_caster):
		_caster.loadout.changed.connect(_loadout_changed)
		_caster.cast_done.connect(_cast_done)
	_rebuild()

func _ready() -> void:
	layer = 11
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebuild()

func displayed_slot_count() -> int:
	if not is_instance_valid(_caster):
		return 0
	var count: int = SkillLoadout.DEFAULT_SKILL_IDS.size()
	for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		if not _caster.loadout.skill_id(slot).is_empty():
			count = maxi(count, slot)
	return count

static func key_label(slot: int) -> String:
	var action: String = "skill_%d" % slot
	if INPUT_SETUP.MOUSE.has(action):
		return "左" if INPUT_SETUP.MOUSE[action] == MOUSE_BUTTON_LEFT else "右"
	if INPUT_SETUP.KEYS.has(action):
		return OS.get_keycode_string(INPUT_SETUP.KEYS[action][0])
	return ""

## 描画なしで空枠・再使用中・発見済みチェインの状態を検証できる。
func slot_state(slot: int) -> Dictionary:
	var skill: SkillDef = _caster.loadout.skill(slot) if is_instance_valid(_caster) else null
	var left: float = _caster.cooldown_left(slot) if skill != null else 0.0
	return {"empty": skill == null, "ready": skill != null and left <= 0.0,
		"left": left, "chain": skill != null and _caster.chain.preview(skill, DataDB.chains) != null}

func _loadout_changed(_slot: int) -> void:
	_rebuild()

func _cast_done(slot: int, _skill: SkillDef, _hits: int, _chained: bool) -> void:
	if slot <= _slots.size():
		# 発動結果の実際のCD（チェイン・補助の倍率込み）を膜の全高にする。
		_slots[slot - 1]["duration"] = _caster.cooldown_left(slot)
		_slots[slot - 1]["waiting"] = _caster.cooldown_left(slot) > 0.0

func _rebuild() -> void:
	if _root == null:
		return
	for child: Node in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_slots.clear()
	var count: int = displayed_slot_count()
	for index: int in count:
		var slot: int = index + 1
		var panel: Panel = Panel.new()
		panel.size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(panel)
		var icon: ColorRect = ColorRect.new()
		icon.position = Vector2(4, 13)
		icon.size = Vector2(24, 24)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var name_label: Label = _label(panel, Vector2(4, 15), Vector2(24, 18), UiStyle.FONT_STANDARD)
		var key: Label = _label(panel, Vector2(0, 0), Vector2(32, 12), UiStyle.FONT_SMALL)
		key.text = key_label(slot)
		var veil: ColorRect = ColorRect.new()
		veil.color = Color(0.02, 0.04, 0.08, 0.8)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(veil)
		var timer: Label = _label(panel, Vector2(1, 18), Vector2(30, 16), UiStyle.FONT_SMALL)
		var dot: ColorRect = ColorRect.new()
		dot.color = UiStyle.ACCENT
		dot.position = Vector2(26, 34)
		dot.size = Vector2(3, 3)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(dot)
		var left: float = _caster.cooldown_left(slot)
		_slots.append({"panel": panel, "style": UiStyle.panel(), "icon": icon, "name": name_label,
			"veil": veil, "timer": timer, "dot": dot, "duration": left,
			"waiting": left > 0.0, "flash": 0.0})
	_process(0.0)

func _label(parent: Control, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label_node: Label = Label.new()
	label_node.position = at
	label_node.size = dimensions
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.label(label_node, font_size)
	parent.add_child(label_node)
	return label_node

func _process(delta: float) -> void:
	if not is_instance_valid(_caster) or _root == null:
		return
	var width: float = _slots.size() * (SLOT_SIZE.x + GAP) - GAP
	_root.pivot_offset = Vector2(_root.size.x * 0.5, _root.size.y)  # 画面の下の中央を軸に、縮める
	_root.scale = Vector2.ONE * BAR_SCALE
	var busy: bool = false
	for index: int in _slots.size():
		var entry: Dictionary = _slots[index]
		var slot: int = index + 1
		var state: Dictionary = slot_state(slot)
		var skill: SkillDef = _caster.loadout.skill(slot)
		var panel: Panel = entry["panel"]
		panel.position = Vector2((_root.size.x - width) / 2 + index * (SLOT_SIZE.x + GAP), _root.size.y - SLOT_SIZE.y - UiStyle.PADDING)
		if entry["waiting"] and state["ready"]:
			entry["flash"] = FLASH_TIME
		entry["flash"] = maxf(0.0, entry["flash"] - delta)
		entry["waiting"] = not state["empty"] and not state["ready"]
		entry["duration"] = maxf(entry["duration"], state["left"])
		var style: StyleBoxFlat = entry["style"]
		style.border_color = UiStyle.ACCENT if state["chain"] else UiStyle.BORDER
		style.bg_color = UiStyle.PANEL.lerp(UiStyle.ACCENT, 0.65 * entry["flash"] / FLASH_TIME)
		panel.add_theme_stylebox_override("panel", style)
		var icon: ColorRect = entry["icon"]
		icon.color = CombatConsts.ELEMENT_COLORS.get(skill.element, UiStyle.MUTED).darkened(0.3) if skill != null else UiStyle.BAR_BG
		(entry["name"] as Label).text = skill.name.substr(0, 2) if skill != null else "—"
		(entry["dot"] as ColorRect).visible = skill != null and not _caster.loadout.supports(slot).is_empty()
		var ratio: float = clampf(state["left"] / maxf(entry["duration"], 0.001), 0.0, 1.0)
		var veil: ColorRect = entry["veil"]
		veil.position = Vector2(4, 37 - 24 * ratio)
		veil.size = Vector2(24, 24 * ratio)
		veil.visible = not state["ready"] and not state["empty"]
		(entry["timer"] as Label).text = "%.1f" % state["left"] if veil.visible else ""
		# マナが足りないときは、絵を青くくすませて、コストを数字で出す
		var short: bool = _vitals != null and skill != null and not _vitals.can_afford(_caster.mana_cost(slot))
		if short and not veil.visible:
			(entry["timer"] as Label).text = "%d" % ceili(_caster.mana_cost(slot))
			icon.color = icon.color.lerp(Color("#2a3a6a"), 0.7)
		busy = busy or veil.visible or entry["flash"] > 0.0 or state["chain"]
	_root.modulate.a = lerpf(_root.modulate.a, 1.0 if busy else IDLE_ALPHA, minf(1.0, delta * 8.0))
