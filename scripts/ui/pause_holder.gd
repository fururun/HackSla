class_name PauseHolder
extends RefCounted
## ゲームを止める画面（スキル装備・装備）の、停止を1か所で管理する。
## 「開いたときの状態を覚えて、閉じたときに戻す」やり方だと、画面を2つ重ねて開き、先に開いたほうから閉じたとき、
## 止まったまま戻らなくなる。そこで、開いている画面を数えて、1つでも開いていれば止める・全部閉じたら動かす。

static var _holders: Dictionary = {}  ## 開いている画面（インスタンスID -> true）
static var _base_paused: bool = false  ## 画面が1つも開いていないときの、元の停止の状態


## 画面が開いた。ゲームを止める
static func acquire(owner: Object, tree: SceneTree) -> void:
	_prune()
	if _holders.is_empty():
		_base_paused = tree.paused  # 最初の画面が開くときの、元の状態（画面とは別の理由で止まっていたか）
	_holders[owner.get_instance_id()] = true
	tree.paused = true


## 画面が閉じた。ほかに開いている画面があれば止めたまま。全部閉じたら、元の状態へ戻す
static func release(owner: Object, tree: SceneTree) -> void:
	_holders.erase(owner.get_instance_id())
	_prune()
	if tree != null:
		tree.paused = true if not _holders.is_empty() else _base_paused


static func count() -> int:
	_prune()
	return _holders.size()


## 消えた画面（シーンの作り直しなど）の分を取り除く
static func _prune() -> void:
	for id: int in _holders.keys():
		if not is_instance_id_valid(id):
			_holders.erase(id)


static func reset() -> void:
	_holders.clear()
	_base_paused = false
