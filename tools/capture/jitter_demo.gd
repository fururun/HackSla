extends SceneTree
## カメラのがくつきを測る：プレイヤーを一定の速さで斜めに歩かせ（開けた広場の中）、フレームごとの
## 「プレイヤーとカメラの中心との、ずれの変化」を数字にする。画面のあるPCで実行する。
##   godot --script res://tools/capture/jitter_demo.gd
## カメラが滑らかに追っているなら、ずれはほとんど変わらない。標準偏差・最大が大きいほど、がくがくしている。

const WARMUP_FRAMES: int = 60
const SAMPLE_FRAMES: int = 150


func _initialize() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	_run(main)


func _run(_main: Node) -> void:
	for i in 10:
		await process_frame
	var player := get_first_node_in_group("player") as Node2D
	player.vitals.life = 99999.0
	Input.action_press("move_right")
	Input.action_press("move_down")
	for i in WARMUP_FRAMES:
		await process_frame
	var rel_deltas: Array[float] = []
	var cam := root.get_viewport().get_camera_2d()
	var last_rel := _drawn_pos(player) - cam.get_screen_center_position()
	for i in SAMPLE_FRAMES:
		await process_frame
		var rel := _drawn_pos(player) - cam.get_screen_center_position()
		rel_deltas.append((rel - last_rel).length())
		last_rel = rel
	Input.action_release("move_right")
	Input.action_release("move_down")
	print("プレイヤーとカメラのずれの変化（1フレームあたり・ドット）: ", _stats(rel_deltas))
	print("物理補間: ", ProjectSettings.get_setting("physics/common/physics_interpolation", false),
		" / ピクセルへの吸着: ", ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false),
		" / 更新頻度: ", DisplayServer.screen_get_refresh_rate())
	quit()


## 画面に描かれる位置（補間があるときは、補間した位置）
func _drawn_pos(node: Node2D) -> Vector2:
	if node.has_method("get_global_transform_interpolated"):
		return (node.call("get_global_transform_interpolated") as Transform2D).origin
	return node.global_position


func _stats(values: Array[float]) -> String:
	var n := float(values.size())
	var mean := 0.0
	var lo := INF
	var hi := -INF
	for v: float in values:
		mean += v
		lo = minf(lo, v)
		hi = maxf(hi, v)
	mean /= n
	var variance := 0.0
	for v: float in values:
		variance += (v - mean) * (v - mean)
	return "平均 %.3f / 最小 %.3f / 最大 %.3f / 標準偏差 %.3f（%d フレーム）" % [mean, lo, hi, sqrt(variance / n), values.size()]
