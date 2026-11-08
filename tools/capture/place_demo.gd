extends SceneTree
## マップの印の位置にプレイヤーを置いて、その場の画面を撮る（部屋やボスの見た目の確認用）
##
## 使い方（画面のあるPC）:
##   godot --script res://tools/capture/place_demo.gd -- --at=X --out=shots/boss
##   --at=印    P / X / s / f / b / C など。複数あるときは、--index=2 で2番目
##   --dx=0 --dy=0   印からのずらし（画面のドット）
##   --frames=90     撮るまで待つフレーム数
##   --kill=1        その場の敵を全部倒す前に撮る、ではなく、プレイヤーの無敵（体力を大きくする）にする

var _opts: Dictionary = {"at": "P", "out": "shots/place", "index": "0", "dx": "0", "dy": "0", "frames": "90"}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1]
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	_run(main)


func _run(main: Node) -> void:
	for i in 5:
		await process_frame
	var player := get_first_node_in_group("player") as Node2D
	var list: Array = main.map.markers.get(str(_opts["at"]), [])
	if list.is_empty():
		print("印が見つかりません: ", _opts["at"])
		quit(1)
		return
	var pos: Vector2 = list[clampi(int(_opts["index"]), 0, list.size() - 1)]
	player.global_position = pos + Vector2(float(_opts["dx"]), float(_opts["dy"]))
	player.vitals.life = 99999.0  # 敵に殴られても死なない（撮影用）
	for i in int(_opts["frames"]):
		await process_frame
	await RenderingServer.frame_post_draw
	var out: String = str(_opts["out"]) + ".png"
	var abs_out := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	root.get_viewport().get_texture().get_image().save_png(abs_out)
	print("撮影: ", abs_out)
	quit()
