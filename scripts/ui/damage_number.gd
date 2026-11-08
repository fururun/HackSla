class_name DamageNumber
extends Label
## プールは表示先の所有物。親の破棄と一緒に解放し、静的なノード参照を残さない。

const LARGE_DAMAGE: float = 100.0
const DAMAGE_SIZE_BONUS: int = 6
const DAMAGE_OUTLINE: int = 3

const POOL_META: StringName = &"damage_number_pool"

var _t: float = 0.0
var _start: Vector2
var active: bool = false


static func spawn(parent: Node, pos: Vector2, amount: float, tint: Color = Color(0, 0, 0, 0)) -> DamageNumber:
	var pool: Array = parent.get_meta(POOL_META, [])
	var n: DamageNumber
	for candidate: DamageNumber in pool:
		if not candidate.active:
			n = candidate
			break
	if n == null:
		if pool.size() < FeedbackConfig.NUMBER_LIMIT:
			n = DamageNumber.new()
			parent.add_child(n, false, Node.INTERNAL_MODE_BACK)
		else:
			n = pool[0]
	# 配列を使用順に保ち、上限時は最古の表示から再利用する。
	pool.erase(n)
	pool.append(n)
	parent.set_meta(POOL_META, pool)
	n._activate(pos, amount, tint)
	return n


func _init() -> void:
	add_theme_font_size_override("font_size", FeedbackConfig.FONT_SIZE)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_constant_override("outline_size", DAMAGE_OUTLINE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	size = FeedbackConfig.NUMBER_SIZE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = FeedbackConfig.NUMBER_Z


func _activate(pos: Vector2, amount: float, tint: Color = Color(0, 0, 0, 0)) -> void:
	text = str(roundi(amount))
	var emphasis: float = clampf(amount / LARGE_DAMAGE, 0.0, 1.0)
	add_theme_font_size_override("font_size", FeedbackConfig.FONT_SIZE + roundi(DAMAGE_SIZE_BONUS * emphasis))
	add_theme_color_override("font_color", tint if tint.a > 0.0 else Color.WHITE.lerp(UiStyle.ACCENT, emphasis))  # tint があれば、その色（受けたダメージは赤）
	_t = 0.0
	active = true
	modulate = Color.WHITE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # 画面の文字。描画のたびに動かすので、補間しない
	global_position = pos + Vector2(randf_range(-FeedbackConfig.NUMBER_JITTER, FeedbackConfig.NUMBER_JITTER) - FeedbackConfig.NUMBER_SIZE.x * 0.5, 0)
	_start = position
	show()
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	position = _start + Vector2(0, -FeedbackConfig.NUMBER_RISE * (_t / FeedbackConfig.NUMBER_LIFE))
	modulate.a = clampf(FeedbackConfig.FADE_FACTOR * (1.0 - _t / FeedbackConfig.NUMBER_LIFE), 0.0, 1.0)
	if _t >= FeedbackConfig.NUMBER_LIFE:
		active = false
		hide()
		set_process(false)
