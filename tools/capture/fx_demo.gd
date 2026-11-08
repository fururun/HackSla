extends SceneTree
## スキルのエフェクトを実際に出して、時間をずらして撮る（エフェクトの見た目の確認用）
##
## 使い方（画面のあるPC）:
##   godot --script res://tools/capture/fx_demo.gd -- --out=shots/fx
## shots/fx_slash_a.png のように、スキルごとに「出た直後」と「少しあと」を撮る。
##
## オプション:
##   --out=shots/fx   出力の前につく名前

var _out: String = "shots/fx"
var _main: Node
var _player: Node2D


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(_main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out + "_" + label + ".png"
	var abs_path := path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	root.get_viewport().get_texture().get_image().save_png(abs_path)
	print("撮影: ", abs_path)


func _run() -> void:
	await _frames(5)
	_player = get_first_node_in_group("player") as Node2D
	_player.vitals.life = 99999.0  # 敵に殴られても死なない
	var swarm: Vector2 = (_main.map.markers["s"] as Array)[0]
	var caster: Node = _player.caster
	caster.fx_parent = _player.get_parent()  # 本来は Player.use_skill が設定する。直接 cast を呼ぶので自分で渡す
	var plan: Array = [
		# [名前, プレイヤーの位置（群れからの相対）, 枠, 待ち（撮影1回目, 2回目）]
		["slash", Vector2(-40, 8), 1, 5, 6],
		["area", Vector2(-10, 8), 2, 8, 14],
		["proj", Vector2(-80, 8), 3, 8, 16],
	]
	for item: Array in plan:
		_player.global_position = swarm + (item[1] as Vector2)
		await _frames(3)
		var hits: int = caster.cast(int(item[2]), swarm, _player.global_position)
		var busy := 0
		for f: Node in caster._fx_pool:
			if f.busy:
				busy += 1
		print("発動 ", item[0], " 枠", item[2], " 当てた数=", hits, " 再生中のエフェクト=", busy, "/", caster._fx_pool.size())
		await _frames(int(item[3]))
		await _shot(str(item[0]) + "_a")
		await _frames(int(item[4]))
		await _shot(str(item[0]) + "_b")
		await _frames(60)
	quit()
