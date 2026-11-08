class_name BossBar
extends CanvasLayer
## ボスの体力の棒（画面の上の中央）。ボスが動き出したら出て、倒したら「撃破！」を数秒出して消える。

const BAR_SIZE: Vector2 = Vector2(260, 12)
const TOP_MARGIN: float = 26.0
const VICTORY_SECONDS: float = 4.0
const SCAN_INTERVAL: float = 0.25

var _manager: EnemyManager
var _boss: Enemy
var _boss_name: String = ""
var _max_life: float = 1.0
var _victory_left: float = 0.0
var _scan_left: float = 0.0

var _panel: PanelContainer
var _name_label: Label
var _back: Panel
var _fill: ColorRect
var _victory: Label


func setup(manager: EnemyManager) -> void:
	_manager = manager
	layer = 12
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.position = Vector2((480.0 - BAR_SIZE.x) * 0.5 - UiStyle.PADDING, TOP_MARGIN)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_name_label = Label.new()
	UiStyle.label(_name_label, UiStyle.FONT_HEADING, UiStyle.ACCENT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)
	var bar := Control.new()
	bar.custom_minimum_size = BAR_SIZE
	box.add_child(bar)
	_back = Panel.new()
	_back.add_theme_stylebox_override("panel", UiStyle.bar_background())
	_back.size = BAR_SIZE
	bar.add_child(_back)
	_fill = ColorRect.new()
	_fill.color = UiStyle.LIFE
	_fill.position = Vector2(1, 1)
	_fill.size = BAR_SIZE - Vector2(2, 2)
	bar.add_child(_fill)
	add_child(_panel)
	_victory = Label.new()
	UiStyle.label(_victory, 20, UiStyle.ACCENT)
	_victory.text = "ボス撃破！"
	_victory.position = Vector2(0, 70)
	_victory.size = Vector2(480, 30)
	_victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory.hide()
	add_child(_victory)
	_panel.hide()
	manager.enemy_hit.connect(_on_enemy_hit)


## ボスを探す（敵の定義に boss がある、生きている敵）
func _find_boss() -> Enemy:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and e.active and e.definition != null and e.definition.is_boss:
			return e
	return null


func _on_enemy_hit(enemy: Enemy, _amount: float, killed: bool) -> void:
	if enemy.definition == null or not enemy.definition.is_boss:
		return
	_boss = enemy
	_boss_name = enemy.definition.name
	_max_life = maxf(enemy.definition.life, 1.0)
	if killed:
		_boss = null
		_panel.hide()
		_victory_left = VICTORY_SECONDS
		_victory.show()
	else:
		_refresh()


## ボスが動き出している（待機ではない）ときだけ、棒を出す
func tick(delta: float) -> void:
	if _victory_left > 0.0:
		_victory_left -= delta
		if _victory_left <= 0.0:
			_victory.hide()
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		if _boss == null or not is_instance_valid(_boss) or not _boss.active:
			_boss = _find_boss()
			if _boss != null:
				_boss_name = _boss.definition.name
				_max_life = maxf(_boss.definition.life, 1.0)
	var awake: bool = _boss != null and is_instance_valid(_boss) and _boss.active and _boss.state != Enemy.State.IDLE
	_panel.visible = awake
	if awake:
		_refresh()


func is_showing() -> bool:
	return _panel != null and _panel.visible


func fill_ratio() -> float:
	return _fill.size.x / (BAR_SIZE.x - 2.0) if _fill != null else 0.0


func _refresh() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	_name_label.text = _boss_name
	_fill.size.x = (BAR_SIZE.x - 2.0) * clampf(_boss.life / _max_life, 0.0, 1.0)


func _process(delta: float) -> void:
	tick(delta)
