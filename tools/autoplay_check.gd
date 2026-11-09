extends SceneTree
## 自動戦闘で、マップを最後まで回れるかを調べる（開発用）。  godot --headless --script res://tools/autoplay_check.gd
var main
var frames := 0
func _initialize() -> void:
	root.add_child(load("res://scenes/main/main.tscn").instantiate())
func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		main = root.get_child(root.get_child_count() - 1)
		main.autopilot.toggle()
		main.set_autopilot(true)
	if frames > 5 and frames % 1800 == 0:
		var p = main.player
		var alive := 0
		for n in get_nodes_in_group("enemies"):
			if n.visible: alive += 1
		var opened := 0
		for c in get_nodes_in_group("chests"):
			if c.is_open: opened += 1
		print("t=", (frames - 5) / 60, "s pos=", p.global_position.round(), " life=", int(p.vitals.life), " lv=", p.vitals.level, " enemies_alive=", alive, " chests_open=", opened, "/", get_nodes_in_group("chests").size())
	if frames > 5 + 60 * 900:
		return true
	return false
