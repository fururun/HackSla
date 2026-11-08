class_name ScreenFlash
extends CanvasLayer
## 画面全体の、短い閃光（チェイン技の一瞬の白い光）。使い捨て。

const LIFE: float = 0.22

var _rect: ColorRect
var _t: float = 0.0
var _peak: float = 0.0


static func spawn(parent: Node, color: Color, peak_alpha: float = 0.35) -> ScreenFlash:
	var flash := ScreenFlash.new()
	flash.layer = 90
	flash._peak = peak_alpha
	flash._rect = ColorRect.new()
	flash._rect.color = Color(color.r, color.g, color.b, peak_alpha)
	flash._rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash._rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.add_child(flash._rect)
	parent.add_child(flash)
	return flash


func _process(delta: float) -> void:
	_t += delta
	_rect.color.a = _peak * clampf(1.0 - _t / LIFE, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
