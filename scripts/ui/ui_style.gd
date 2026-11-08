class_name UiStyle
extends RefCounted
## 論理480×270で使う共通スタイル。角は丸めず1ドットの枠を使う。
const PANEL: Color = Color("#18222f")
const BORDER: Color = Color("#526174")
const TEXT: Color = Color("#e6e0ce")
const MUTED: Color = Color("#a7b3c2")
const ACCENT: Color = Color("#e5bd78")
const WARNING: Color = Color("#ff7770")
const OUTLINE: Color = Color("#0a101a")
const BACKDROP: Color = Color("#0d111bf5")
const BAR_BG: Color = Color("#0e1620")
const LIFE: Color = Color("#ac484b")
const XP: Color = Color("#4b8fd6")
const FONT_STANDARD: int = 10
const FONT_HEADING: int = 12
const FONT_SMALL: int = 8
const PADDING: int = 6
const BORDER_WIDTH: int = 1

static func panel() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(BORDER_WIDTH)
	style.set_content_margin_all(PADDING)
	return style

static func bar_background() -> StyleBoxFlat:
	var style: StyleBoxFlat = panel()
	style.bg_color = BAR_BG
	style.set_content_margin_all(1)
	return style

static func label(label_node: Label, font_size: int = FONT_STANDARD, color: Color = TEXT) -> void:
	label_node.add_theme_font_size_override("font_size", font_size)
	label_node.add_theme_color_override("font_color", color)
	label_node.add_theme_color_override("font_outline_color", OUTLINE)
	label_node.add_theme_constant_override("outline_size", 2)

static func button(button_node: Button) -> void:
	button_node.add_theme_font_size_override("font_size", FONT_STANDARD)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = panel()
		style.bg_color = PANEL.lightened(0.12) if state != "normal" else PANEL
		style.border_color = ACCENT if state != "normal" else BORDER
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		button_node.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button_node.add_theme_color_override(state, TEXT)
