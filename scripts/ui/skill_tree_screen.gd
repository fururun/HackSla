class_name SkillTreeScreen
extends CanvasLayer
## スキルツリーの画面（T で開閉。開いている間はゲームが止まる）。
## 丸いノードを左クリックで取る（ポイントを使う）。取れるのは、取ったノードとつながるノードだけ。

const SPACING: float = 19.0  ## ノードの格子の間隔（論理ピクセル）
const ORIGIN: Vector2 = Vector2(168, 140)  ## 根源（0,0）の画面の位置
const RADIUS: Dictionary = {"small": 5.0, "notable": 7.0, "keystone": 9.0}
const KIND_NAMES: Dictionary = {"small": "小ノード", "notable": "中ノード", "keystone": "大ノード"}

## ノードを描いて、クリックを受ける部品
class Canvas extends Control:
	signal hovered(id: String)
	signal clicked(id: String)
	var screen: SkillTreeScreen

	func _draw() -> void:
		if screen == null or screen.tree == null:
			return
		for node: TreeNodeDef in DataDB.tree_nodes.values():
			for other_id: String in node.links:
				var other: TreeNodeDef = DataDB.tree_node(other_id)
				if other == null:
					continue
				var both: bool = screen.tree.is_taken(node.id) and screen.tree.is_taken(other.id)
				draw_line(SkillTreeScreen.node_position(node), SkillTreeScreen.node_position(other),
					UiStyle.ACCENT if both else UiStyle.BORDER, 2.0 if both else 1.0)
		for node: TreeNodeDef in DataDB.tree_nodes.values():
			var p: Vector2 = SkillTreeScreen.node_position(node)
			var r: float = float(SkillTreeScreen.RADIUS.get(node.kind, 5.0))
			var state: int = screen.node_state(node.id)
			var fill: Color = UiStyle.BAR_BG
			var edge: Color = UiStyle.BORDER
			match state:
				SkillTreeScreen.State.TAKEN:
					fill = UiStyle.ACCENT
					edge = UiStyle.TEXT
				SkillTreeScreen.State.AVAILABLE:
					edge = Color("#7dffb0")
				SkillTreeScreen.State.UNAFFORDABLE:
					edge = UiStyle.WARNING
			draw_circle(p, r, fill)
			draw_arc(p, r, 0.0, TAU, 20, edge, 1.0 if node.kind == "small" else 2.0)
			if node.id == screen.hover_id:
				draw_arc(p, r + 3.0, 0.0, TAU, 20, UiStyle.TEXT, 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			hovered.emit(screen.node_at((event as InputEventMouseMotion).position))
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var id: String = screen.node_at((event as InputEventMouseButton).position)
			if not id.is_empty():
				clicked.emit(id)

enum State { LOCKED, AVAILABLE, UNAFFORDABLE, TAKEN }

var tree: SkillTree
var vitals: PlayerVitals
var hover_id: String = ""
var _opened: bool = false
var _root: Control
var _canvas: Canvas
var _title: Label
var _detail: Label


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 91


func setup(skill_tree: SkillTree, player_vitals: PlayerVitals) -> void:
	tree = skill_tree
	vitals = player_vitals
	if tree != null and not tree.changed.is_connected(_refresh):
		tree.changed.connect(_refresh)
	_refresh()


func _ready() -> void:
	_build_ui()
	_root.visible = _opened
	_refresh()


static func node_position(node: TreeNodeDef) -> Vector2:
	return ORIGIN + Vector2(node.pos) * SPACING


func node_state(id: String) -> int:
	if tree == null:
		return State.LOCKED
	if tree.is_taken(id):
		return State.TAKEN
	if not tree.is_available(id):
		return State.LOCKED
	var node: TreeNodeDef = DataDB.tree_node(id)
	return State.AVAILABLE if vitals != null and vitals.points >= node.cost else State.UNAFFORDABLE


## 画面の位置にあるノードのid（なければ ""）
func node_at(pos: Vector2) -> String:
	var best: String = ""
	var best_dist: float = INF
	for node: TreeNodeDef in DataDB.tree_nodes.values():
		var d: float = node_position(node).distance_to(pos)
		if d <= float(RADIUS.get(node.kind, 5.0)) + 3.0 and d < best_dist:
			best = node.id
			best_dist = d
	return best


func open() -> void:
	if _opened or not is_inside_tree():
		return
	_opened = true
	PauseHolder.acquire(self, get_tree())
	if _root != null:
		_root.show()
	_refresh()


func close() -> void:
	if not _opened:
		return
	_opened = false
	PauseHolder.release(self, get_tree() if is_inside_tree() else null)
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
	if event.is_action_pressed("toggle_skill_tree") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
	elif _opened and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif _opened:
		# コントローラー／キーボード：十字キー・スティックでノードを選び、A（決定）で取る
		for pair: Array in [["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN], ["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT]]:
			if event.is_action_pressed(str(pair[0])):
				move_cursor(pair[1])
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_accept") and not hover_id.is_empty():
			_on_clicked(hover_id)
			get_viewport().set_input_as_handled()


## 選んでいるノードから、指した向きの、いちばん近いノードへ動かす（最初は、根源）。動かせたら true
func move_cursor(direction: Vector2) -> bool:
	var current: TreeNodeDef = DataDB.tree_node(hover_id) if not hover_id.is_empty() else null
	if current == null:
		for node: TreeNodeDef in DataDB.tree_nodes.values():
			if node.pos == Vector2i.ZERO:
				current = node
				break
		if current == null:
			return false
		_on_hovered(current.id)
		return true
	var origin: Vector2 = node_position(current)
	var best: TreeNodeDef = null
	var best_score: float = INF
	for node: TreeNodeDef in DataDB.tree_nodes.values():
		if node.id == current.id:
			continue
		var offset: Vector2 = node_position(node) - origin
		var alignment: float = offset.normalized().dot(direction)
		if alignment < 0.5:
			continue
		var score: float = offset.length() * (2.0 - alignment)
		if score < best_score:
			best = node
			best_score = score
	if best == null:
		return false
	_on_hovered(best.id)
	return true


## ノードを取る（クリックと同じ）。取れたら true
func take(id: String) -> bool:
	if tree == null or vitals == null:
		return false
	return tree.take(id, vitals)


func detail_text(id: String) -> String:
	var node: TreeNodeDef = DataDB.tree_node(id)
	if node == null:
		return "ノードにカーソルを合わせると、効果が出ます。"
	var status: String
	match node_state(id):
		State.TAKEN: status = "取得済み"
		State.AVAILABLE: status = "クリックで取る"
		State.UNAFFORDABLE: status = "ポイントが足りない"
		_: status = "まだ、つながっていない"
	return "%s\n%s　コスト %d\n%s\n\n%s" % [node.name, KIND_NAMES.get(node.kind, node.kind), node.cost, node.description, status]


func _refresh() -> void:
	if _title != null:
		var points: int = vitals.points if vitals != null else 0
		var used: int = tree.taken_count() if tree != null else 0
		_title.text = "スキルツリー  /  ポイント %d　取得 %d / %d" % [points, used, maxi(DataDB.tree_nodes.size() - 1, 0)]
	if _detail != null:
		_detail.text = detail_text(hover_id)
	if _canvas != null:
		_canvas.queue_redraw()


func _on_hovered(id: String) -> void:
	if id != hover_id:
		hover_id = id
		_refresh()


func _on_clicked(id: String) -> void:
	take(id)
	hover_id = id
	_refresh()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	_title = Label.new()
	UiStyle.label(_title, UiStyle.FONT_HEADING, UiStyle.ACCENT)
	_title.position = Vector2(12, 6)
	_root.add_child(_title)
	_canvas = Canvas.new()
	_canvas.screen = self
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.hovered.connect(_on_hovered)
	_canvas.clicked.connect(_on_clicked)
	_root.add_child(_canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(330, 30)
	panel.size = Vector2(142, 120)
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_detail = Label.new()
	UiStyle.label(_detail, UiStyle.FONT_SMALL, UiStyle.TEXT)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_detail)
	var help := Label.new()
	UiStyle.label(help, UiStyle.FONT_SMALL, UiStyle.MUTED)
	help.text = "左クリック: ノードを取る　T / Esc: 閉じる\nレベルが上がるたびに 1 ポイント"
	help.position = Vector2(330, 232)
	_root.add_child(help)
