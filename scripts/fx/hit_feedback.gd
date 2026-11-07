class_name HitFeedback
extends Node
## 被弾信号から表示を駆動。ヒットストップは全管理ノードで一つの実時間窓を共有。

static var _stop_owner: HitFeedback
static var _next_stop_usec: int = 0

var kill_count: int = 0
var _counter: Label
var _pulse_left: float = 0.0
var _shake_left: float = 0.0
var _shake_strength: float = 0.0
var _camera: Camera2D
var _camera_offset: Vector2
var _last_usec: int = 0
var _saved_time_scale: float = 1.0
var _stop_timer: SceneTreeTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter = Label.new()
	hud.add_child(_counter)
	_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_counter.offset_left = -FeedbackConfig.COUNTER_SIZE.x - FeedbackConfig.COUNTER_MARGIN.x
	_counter.offset_right = -FeedbackConfig.COUNTER_MARGIN.x
	_counter.offset_top = FeedbackConfig.COUNTER_MARGIN.y
	_counter.offset_bottom = FeedbackConfig.COUNTER_MARGIN.y + FeedbackConfig.COUNTER_SIZE.y
	_counter.size = FeedbackConfig.COUNTER_SIZE
	_counter.pivot_offset = Vector2(FeedbackConfig.COUNTER_SIZE.x, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.add_theme_font_size_override("font_size", FeedbackConfig.COUNTER_FONT_SIZE)
	_counter.add_theme_constant_override("outline_size", FeedbackConfig.OUTLINE_SIZE)
	_counter.add_theme_color_override("font_outline_color", Color.BLACK)
	_counter.text = "撃破 0"


func on_enemy_hit(enemy: Enemy, amount: float, killed: bool) -> void:
	DamageNumber.spawn(self, enemy.global_position + FeedbackConfig.NUMBER_OFFSET, amount)
	if killed:
		kill_count += 1
		_counter.text = "撃破 %d" % kill_count
		_pulse_left = FeedbackConfig.COUNTER_PULSE_SECONDS
		request_hitstop()
	if killed or amount >= FeedbackConfig.LARGE_DAMAGE:
		_start_shake(FeedbackConfig.SHAKE_KILL if killed else FeedbackConfig.SHAKE_HIT)


func request_hitstop() -> void:
	var now: int = Time.get_ticks_usec()
	# 同時撃破でタイマーを大量生成せず、連続撃破でも停止窓を延長しない。
	if is_instance_valid(_stop_owner) or now < _next_stop_usec or not is_inside_tree():
		return
	_stop_owner = self
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = minf(_saved_time_scale, FeedbackConfig.HITSTOP_SCALE)
	var duration: float = minf(FeedbackConfig.HITSTOP_SECONDS, FeedbackConfig.HITSTOP_MAX_SECONDS)
	_next_stop_usec = now + int((duration + FeedbackConfig.HITSTOP_RECOVERY_SECONDS) * 1000000.0)
	_stop_timer = get_tree().create_timer(duration, true, false, true)
	_stop_timer.timeout.connect(_restore_time_scale)


func _restore_time_scale() -> void:
	if _stop_owner == self:
		Engine.time_scale = _saved_time_scale
		_stop_owner = null
	_stop_timer = null


func _start_shake(strength: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	if camera != _camera:
		_restore_camera()
		_camera = camera
		_camera_offset = camera.offset
	_shake_left = FeedbackConfig.SHAKE_SECONDS
	_shake_strength = maxf(_shake_strength, strength)


func _restore_camera() -> void:
	if is_instance_valid(_camera):
		_camera.offset = _camera_offset
	_camera = null
	_shake_left = 0.0
	_shake_strength = 0.0


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var elapsed: float = float(now - _last_usec) / 1000000.0
	_last_usec = now
	_pulse_left = maxf(0.0, _pulse_left - elapsed)
	_counter.scale = Vector2.ONE * lerpf(1.0, FeedbackConfig.COUNTER_PULSE_SCALE, _pulse_left / FeedbackConfig.COUNTER_PULSE_SECONDS)
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - elapsed)
		if not is_instance_valid(_camera) or _shake_left <= 0.0 or get_viewport().get_camera_2d() != _camera:
			_restore_camera()
		else:
			var strength: float = _shake_strength * _shake_left / FeedbackConfig.SHAKE_SECONDS
			_camera.offset = _camera_offset + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))


func _exit_tree() -> void:
	_restore_time_scale()
	_restore_camera()
