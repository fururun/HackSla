class_name BossBar
extends CanvasLayer
## ボスを倒したとき、「ボス撃破！」を数秒出す。
## ボスと中ボスの体力の棒は、敵の頭の上に出す（Enemy._draw_life_bar）。

const VICTORY_SECONDS: float = 4.0

var _victory_left: float = 0.0
var _victory: Label


func setup(manager: EnemyManager) -> void:
	layer = 12
	_victory = Label.new()
	UiStyle.label(_victory, 16, UiStyle.ACCENT)
	_victory.text = "ボス撃破！"
	_victory.position = Vector2(0, 70)
	_victory.size = Vector2(480, 30)
	_victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory.hide()
	add_child(_victory)
	manager.enemy_hit.connect(_on_enemy_hit)


func _on_enemy_hit(enemy: Enemy, _amount: float, killed: bool) -> void:
	if killed and enemy.definition != null and enemy.definition.is_boss:
		_victory_left = VICTORY_SECONDS
		_victory.show()


func tick(delta: float) -> void:
	if _victory_left > 0.0:
		_victory_left -= delta
		if _victory_left <= 0.0:
			_victory.hide()


func is_victory_showing() -> bool:
	return _victory != null and _victory.visible


func _process(delta: float) -> void:
	tick(delta)
