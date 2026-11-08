class_name DpsMeter
extends CanvasLayer
## 与えたダメージのDPS（秒あたりのダメージ）を、画面の右上に出す。直近5秒の合計を、経過した秒数で割る
## （戦い始めてすぐでも、実際に近い値が出る）。最大値も出す。

const WINDOW: float = 5.0
const MIN_SPAN: float = 1.0  ## 最初の1秒は、この秒数で割る（1発だけで跳ね上がらない）

var _hits: Array[Vector2] = []  ## (時刻, ダメージ)
var _now: float = 0.0
var _peak: float = 0.0
var _label: Label


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	root.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -200
	_label.offset_right = -6
	_label.offset_top = 44
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.label(_label, UiStyle.FONT_SMALL, Color("#ffd34d"))
	_refresh()


## 与えたダメージを記録する
func record(amount: float) -> void:
	if amount > 0.0:
		_hits.append(Vector2(_now, amount))


func current_dps() -> float:
	var cutoff: float = _now - WINDOW
	var total: float = 0.0
	var first: float = _now
	for h: Vector2 in _hits:
		if h.x >= cutoff:
			total += h.y
			first = minf(first, h.x)
	if total <= 0.0:
		return 0.0
	return total / clampf(_now - first, MIN_SPAN, WINDOW)


func peak_dps() -> float:
	return _peak


func tick(delta: float) -> void:
	_now += delta
	while not _hits.is_empty() and _hits[0].x < _now - WINDOW:
		_hits.pop_front()
	_peak = maxf(_peak, current_dps())
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = "DPS %d　最大 %d" % [roundi(current_dps()), roundi(_peak)]


func _process(delta: float) -> void:
	tick(delta)
