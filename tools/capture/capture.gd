extends SceneTree
## 画面の撮影（PRに付けるスクリーンショット用。AIも人も使える）
##
## 使い方（画面のあるPC）:
##   godot --script res://tools/capture/capture.gd -- --out=shots/main.png
## 画面のないサーバー（Linux）:
##   xvfb-run godot --rendering-driver opengl3 --script res://tools/capture/capture.gd -- --out=shots/main.png
##
## オプション:
##   --scene=res://scenes/main/main.tscn   撮る画面
##   --frames=60                            撮るまで待つフレーム数
##   --scale=1                              拡大率（画面そのままの大きさで撮る。縮小表示された画面を拡大したいときだけ増やす）
##   --demo=attack                          プレイヤーを案山子の前に動かして斬撃させてから撮る

var _opts: Dictionary = {
	"scene": "res://scenes/main/main.tscn",
	"out": "shots/capture.png",
	"frames": "60",
	"scale": "1",
	"demo": "",
}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			_opts[kv[0]] = kv[1]
	var scene: PackedScene = load(_opts["scene"])
	root.add_child(scene.instantiate())
	_run()


func _run() -> void:
	var frames := int(_opts["frames"])
	if _opts["demo"] == "attack":
		await _demo_attack()
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var s := int(_opts["scale"])
	if s > 1:
		img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
	var out: String = _opts["out"]
	var abs_out := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var err := img.save_png(abs_out)
	print("撮影: %s (%s)" % [abs_out, "OK" if err == OK else error_string(err)])
	quit(0 if err == OK else 1)


func _demo_attack() -> void:
	for i in 5:
		await process_frame
	var player := get_first_node_in_group("player") as Node2D
	var dummy := get_first_node_in_group("enemies") as Node2D
	if player == null or dummy == null:
		return
	player.global_position = dummy.global_position + Vector2(-18, 6)
	for i in 6:
		player.call("try_basic_attack", dummy.global_position)
		for f in 24:
			await process_frame
	player.call("try_basic_attack", dummy.global_position)  # 振っている途中を撮る
