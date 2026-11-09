extends Node2D
## テスト用のメイン画面：マップを作り、プレイヤーと案山子を置く。

const MAP_PATH: String = "res://data/maps/field_01.txt"  ## 広いマップ。作り方は tools/maps/make_field_01.py、設計は docs/map_field_01.md
const RARE_CHANCE_AT_BRUTE: float = 0.3  ## 岩殻の印で、レアモンスター（黄金の岩殻）に入れ替わる確率
const RARE_CHANCE_AT_PACK: float = 0.06  ## スライムの群れの印で、近くにレアモンスターも現れる確率
const LEGEND_CHEST_CHANCE: float = 0.03  ## ゲームを始めるたびに、レジェンドの宝箱が置かれる確率（超低確率）
const START_NOTICE_SECONDS: float = 10.0  ## スタート構成のお知らせを出す秒数
const SMALL_PACK_SIZE: int = 6  ## マップの印 f の群れの数
## カメラの引き（拡大率）。1.0 で、画面が 480x270 ドットの範囲。0.5 なら、2倍の範囲（960x540）が見える。
## 画面を3倍に拡大して描く（1440x810）とき、2/3 なら、ドット1つがちょうど画面の2ピクセルになって、にじまない。
const CAMERA_ZOOM: float = 1.0  ## 標準の引き（1.0＝ドットが3ピクセル。F4で変えられる）

var world: Node2D
var map: IsoMap
var player: Player
var stash: Stash  ## 持ち物（拾ったジェム・装備・通貨）
var skill_tree: SkillTree  ## スキルツリーの取得状況（ポイントは player.vitals.points）
var tree_screen: SkillTreeScreen
var carried_over: bool = false  ## 引き継いでリスタートした直後か（レベル・ツリー・装備を持ち越している）
var game_log: GameLog  ## 遊んだ記録とデバッグの記録
var camera: Camera2D
var loot_hud: LootHud
var legend_chest: TreasureChest  ## 置かれたレジェンドの宝箱（置かれなかったときは空）
var balance_log: BalanceLog  ## バランス調整用の記録（1プレイにつき1行。balance_logs/runs.jsonl）
var dps_meter: DpsMeter
var loot_director: LootDirector
var start_skill_ids: Array[String] = []  ## 今回のスタートのスキル構成（毎回ランダム。必ずチェインが1つは組める）
var start_loadout_text: String = ""
var autopilot: Autopilot = Autopilot.new()  ## デバッグ用の自動戦闘（F2）
var _autopilot_label: Label
var camera_mode: int = 0
var _camera_label: Label

## カメラの見え方の候補（F4 で順に切り替えて、がくつきの出ないものを探す）。
## [名前, 引き, 追従をなめらかにする, ピクセルへの吸着]
const CAMERA_MODES: Array = [
	["標準: 引き1.0・追従なし（固定）・吸着なし", 1.0, false, false],
	["A: 引き0.5・なめらか追従・吸着あり", 0.5, true, true],
	["B: 引き0.5・追従なし（固定）・吸着なし（標準）", 0.5, false, false],
	["C: 引き0.5・追従なし（プレイヤーに固定）・吸着あり", 0.5, false, true],
	["D: 引き2/3・なめらか追従・吸着あり（ドットがちょうど2ピクセル）", 0.6667, true, true],
	["E: 引き2/3・追従なし・吸着あり", 0.6667, false, true],
	["F: 引き1.0・なめらか追従・吸着あり（ドットが3ピクセル）", 1.0, true, true],
]


func _ready() -> void:
	if "--area=crypt" in OS.get_cmdline_user_args():  # 見た目の確認用：地下墓所のタイル
		IsoMap.art_path = IsoMap.CRYPT_ART_PATH
		IsoMap.mural_path = "res://art/tiles/mural_field_01_crypt.png"
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	map = IsoMap.new()
	map.name = "Map"
	add_child(map)
	move_child(map, 0)
	var map_rows: PackedStringArray = load_map(MAP_PATH)
	map.build(map_rows, world)
	var lights := WorldLights.new()  # たいまつ・色つきの光だまり
	lights.name = "Lights"
	add_child(lights)
	lights.build(map_rows, map)

	player = Player.new()
	player.name = "Player"
	player.position = map.marker("P")
	player.autopilot = autopilot
	world.add_child(player)

	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * CAMERA_ZOOM  # 引き：小さいほど、広い範囲が見える（標準は 1.0）
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # プレイヤーと同じ物理の刻みで追う（がくつき防止）
	camera.position_smoothing_enabled = false  # 標準は、追従なし（プレイヤーに固定）。ふるるん さんが、がくつきのない設定として選んだ（設定B）
	camera.position_smoothing_speed = 8.0
	camera.offset = Vector2(0, -10)
	player.add_child(camera)

	for pos: Vector2 in map.markers.get("D", []):
		var dummy := TrainingDummy.new()
		dummy.position = pos
		world.add_child(dummy)

	var manager := _add_enemies()
	manager.blocked = func(pos: Vector2) -> bool: return not map.is_floor_at(pos)  # 弾・突進・後退が、壁を抜けない
	var enemy_fx := EnemyFxDirector.new()  # 敵の攻撃のエフェクト
	enemy_fx.name = "EnemyFxDirector"
	add_child(enemy_fx)
	enemy_fx.setup(manager, player, world)
	stash = Stash.new()
	skill_tree = SkillTree.new()
	_roll_start_loadout()
	_add_skill_screen(stash)
	_add_progression(manager, stash)
	carried_over = RunCarry.apply(player.vitals, stash, skill_tree, player.caster.loadout)  # 引き継いでリスタートなら、レベル・ツリー・装備を戻す
	game_log = GameLog.new()  # 遊んだ記録とデバッグの記録（user://logs/）
	game_log.name = "GameLog"
	add_child(game_log)
	game_log.open()
	game_log.setup(player, manager, stash)
	game_log.play("start_loadout", {"skills": start_skill_ids})
	game_log.play("run_start", {"restart": RunCarry.mode_name(RunCarry.last_mode), "carried": carried_over, "level": player.vitals.level, "tree": skill_tree.taken_count()})
	var restart_listener := RestartListener.new()
	add_child(restart_listener)
	_add_help()
	# バランス調整用の記録（使ったスキル・最終装備・ドロップ・最大DPS・ボスの討伐の速さ）
	balance_log = BalanceLog.new()
	balance_log.name = "BalanceLog"
	add_child(balance_log)
	balance_log.setup(manager, player, stash, loot_director, autopilot, dps_meter, start_skill_ids)
	balance_log.legend_chest_spawned = legend_chest != null
	balance_log.legend_chest = legend_chest
	balance_log.skill_tree = skill_tree
	# 自動戦闘の周回：ボスを倒す・やられたら、自動でやり直す
	var auto_loop := AutoLoop.new()
	auto_loop.name = "AutoLoop"
	add_child(auto_loop)
	auto_loop.setup(manager, player, autopilot)
	auto_loop.restart_requested.connect(func(reason: String, run: int) -> void:
		if game_log != null:
			game_log.play("auto_restart", {"reason": reason, "run": run})
		restart_listener.restart(auto_loop.restart_mode))
	if autopilot.load_state():  # やり直す前に、自動戦闘が入っていたなら、そのまま続ける
		set_autopilot(true)


## F4：カメラの見え方を切り替える（がくつきの原因を探すため）
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		set_help_open(not _help_open)
	if event.is_action_pressed("toggle_autobattle"):
		set_autopilot(autopilot.toggle())
	if event.is_action_pressed("autobattle_route"):
		autopilot.cycle_route()
		set_autopilot(autopilot.enabled)
	if event.is_action_pressed("autobattle_support"):
		autopilot.auto_support = not autopilot.auto_support
		_apply_auto_support()
		set_autopilot(autopilot.enabled)
	if event.is_action_pressed("autobattle_chests"):
		autopilot.toggle_chests()
		set_autopilot(autopilot.enabled)
	if event.is_action_pressed("cycle_camera"):
		apply_camera_mode((camera_mode + 1) % CAMERA_MODES.size())


## 自動戦闘が入っていて、補助ジェムを自動でつける設定なら、いま持っているジェムで、各枠につける
func _apply_auto_support() -> void:
	if autopilot.enabled and autopilot.auto_support and player != null:
		var changed: int = autopilot.equip_supports(player.caster)
		if changed > 0 and game_log != null:
			game_log.play("auto_support", {"changed": changed})


## 自動戦闘が入っているあいだは、貯まったツリーのポイントを、自動で使う（手で遊ぶときは、自分で選ぶ）
func _auto_spend_points() -> void:
	if autopilot.enabled and skill_tree != null and player != null:
		var taken: int = skill_tree.auto_take(player.vitals)
		if taken > 0 and game_log != null:
			game_log.play("auto_tree", {"taken": taken})


## 自動戦闘の表示（画面の上の中央）
func set_autopilot(on: bool) -> void:
	autopilot.enabled = on
	_apply_auto_support()
	_auto_spend_points()
	if _autopilot_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_autopilot_label = Label.new()
		_autopilot_label.position = Vector2(170, 4)
		_autopilot_label.add_theme_font_size_override("font_size", 8)
		_autopilot_label.add_theme_color_override("font_color", Color("#7dffb0"))
		_autopilot_label.add_theme_constant_override("outline_size", 2)
		_autopilot_label.add_theme_color_override("font_outline_color", Color.BLACK)
		layer.add_child(_autopilot_label)
	_autopilot_label.text = autopilot.settings_text() if on else ""
	if game_log != null:
		game_log.play("autopilot", {"on": on})


func apply_camera_mode(index: int) -> void:
	camera_mode = index
	var m: Array = CAMERA_MODES[index]
	camera.zoom = Vector2.ONE * float(m[1])
	camera.position_smoothing_enabled = bool(m[2])
	get_viewport().snap_2d_transforms_to_pixel = bool(m[3])
	get_viewport().snap_2d_vertices_to_pixel = bool(m[3])
	camera.reset_smoothing()
	if _camera_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_camera_label = Label.new()
		_camera_label.position = Vector2(6, 16)
		_camera_label.add_theme_font_size_override("font_size", 8)
		_camera_label.add_theme_color_override("font_color", Color("#ffd34d"))
		_camera_label.add_theme_constant_override("outline_size", 3)
		_camera_label.add_theme_color_override("font_outline_color", Color.BLACK)
		layer.add_child(_camera_label)
	_camera_label.text = "カメラ %s　(F4で切り替え)" % str(m[0])
	if game_log != null:
		game_log.play("camera_mode", {"mode": str(m[0])})


## スタート時のスキル構成を、ランダムに決める（必ず、チェインが1つは組める）。持ち物にも、そのスキルを入れる
func _roll_start_loadout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var carried: Array[String] = RunCarry.carried_skills()
	start_skill_ids = carried if not carried.is_empty() else StartLoadout.roll(rng)  # 引き継ぎなら、前のスキル構成のまま
	for slot: int in start_skill_ids.size():
		player.caster.loadout.set_skill(slot + 1, start_skill_ids[slot])
		stash.add_gem(GemInstance.new(GemInstance.Kind.SKILL, start_skill_ids[slot]))
	start_loadout_text = StartLoadout.describe(start_skill_ids)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if loot_hud == null:
		return
	if connected:
		loot_hud.notify("コントローラー接続: %s" % Input.get_joy_name(device), UiStyle.ACCENT, 6.0)
	else:
		loot_hud.notify("コントローラーが切れました", UiStyle.WARNING, 6.0)


## 超低確率で、金色のレジェンドの宝箱を、マップの印 L のうち1か所に置く。force が true なら、かならず置く（試験用）
func _place_legend_chest(force: bool) -> TreasureChest:
	var spots: Array = map.markers.get("L", [])
	if spots.is_empty() or loot_director == null:
		return null
	if not force and randf() >= LEGEND_CHEST_CHANCE:
		return null
	var chest := TreasureChest.new()
	chest.legend = true
	chest.position = spots[randi() % spots.size()]
	world.add_child(chest)
	chest.opened.connect(func(c: TreasureChest) -> void:
		loot_director.drop_legend_chest(c.global_position)
		if game_log != null:
			game_log.play("legend_chest_opened", {})
		if loot_hud != null:
			loot_hud.notify("レジェンドの宝箱を開けた！", Color("#ffb03d"), 6.0))
	legend_chest = chest
	return chest


## 体力・経験値・ドロップ・装備をつなぐ
func _add_progression(manager: EnemyManager, stash: Stash) -> void:
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(player.vitals)
	dps_meter = DpsMeter.new()  # DPS（右上）
	dps_meter.name = "DpsMeter"
	add_child(dps_meter)
	manager.enemy_hit.connect(func(_enemy: Enemy, amount: float, _killed: bool) -> void: dps_meter.record(amount))
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is TrainingDummy:
			node.damaged.connect(dps_meter.record)
	# チェイン技が出たら、派手な演出（輪・閃光・火花・文字・画面の揺れ）
	player.caster.cast_done.connect(func(_slot: int, skill: SkillDef, _hits: int, chained: bool) -> void:
		if chained:
			ChainFx.play(world, skill, player.global_position, player.aim_target(), manager, player.caster))
	# 回復：緑の数字と、緑の輪
	player.vitals.healed.connect(func(amount: float) -> void:
		DamageNumber.spawn(world, player.global_position + Vector2(0, -30), amount, Color("#7dffb0"))
		EnemyFx.spawn(world, EnemyFx.Kind.RING, player.global_position, Color("#7dffb0"), 24.0, 0.5)
		EnemyFx.spawn(world, EnemyFx.Kind.BURST, player.global_position, Color("#b5ffd0"), 16.0, 0.45))
	# 受けたダメージは、プレイヤーの頭の上に赤い数字で出す
	player.damaged.connect(func(amount: float, _source: Node) -> void: DamageNumber.spawn(world, player.global_position + Vector2(0, -30), amount, Color("#ff6b5e")))
	var boss_bar := BossBar.new()  # ボスの体力の棒（画面の上の中央）
	boss_bar.name = "BossBar"
	add_child(boss_bar)
	boss_bar.setup(manager)
	var skill_bar := SkillBar.new()  # 画面下の、使えるスキルと再使用までの秒数
	skill_bar.name = "SkillBar"
	add_child(skill_bar)
	skill_bar.setup(player.caster, player.vitals)

	# 敵に殴られる／倒した経験値
	manager.player_hit.connect(player.on_player_hit)
	manager.enemy_hit.connect(func(enemy: Enemy, _amount: float, killed: bool) -> void:
		if killed and enemy.definition != null:
			player.vitals.grant_xp(enemy.definition.xp))

	# ドロップ：倒した敵の位置に出て、歩いて拾う
	var director := LootDirector.new()
	loot_director = director
	director.name = "LootDirector"
	add_child(director)
	director.setup(manager, player, world, stash, func() -> int: return player.vitals.level)
	autopilot.director = director
	autopilot.map = map
	autopilot.stash = stash
	stash.changed.connect(_apply_auto_support)  # 新しい補助ジェムを拾ったら、付け直す
	director.is_valid_position = func(pos: Vector2) -> bool: return map.is_floor_at(pos, true)  # 壁の中・壁ぎわに置かない
	# 宝箱：近づくと開いて、まとまった数のドロップが出る（最初の広場に置く）
	for pos: Vector2 in map.markers.get("C", []):
		var chest := TreasureChest.new()
		chest.position = pos
		world.add_child(chest)
		chest.opened.connect(func(c: TreasureChest) -> void: director.drop_chest(c.global_position))

	_place_legend_chest(false)
	var equip_screen := EquipScreen.new()
	equip_screen.name = "EquipScreen"
	add_child(equip_screen)
	equip_screen.setup(stash, player.vitals)
	loot_hud = LootHud.new()
	loot_hud.name = "LootHud"
	add_child(loot_hud)
	loot_hud.setup(stash)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)  # コントローラーがつながった／切れたのを、画面に出す
	for pad: int in Input.get_connected_joypads():
		_on_joy_connection_changed(pad, true)
	loot_hud.notify(start_loadout_text, UiStyle.ACCENT, START_NOTICE_SECONDS)  # 今回の、スタート構成と、組めるチェイン
	if legend_chest != null:
		loot_hud.notify("どこかに、金色に輝く宝箱がある…", Color("#ffb03d"), START_NOTICE_SECONDS)

	# 装備のステータスを、体力・スキルのダメージ計算が見ている入れ物に反映する
	var apply_equipment := func() -> void:
		player.caster.stats.clear()
		player.caster.stats.merge(stash.equipment_stats())
		player.caster.stats.merge(skill_tree.stats())  # スキルツリーで取ったノードの効果
		player.vitals.life = minf(player.vitals.life, player.vitals.max_life())  # 最大ライフが下がったら、いまのライフも合わせる
		player.vitals.changed.emit()
	stash.changed.connect(apply_equipment)
	skill_tree.changed.connect(apply_equipment)
	apply_equipment.call()
	tree_screen = SkillTreeScreen.new()
	tree_screen.name = "SkillTreeScreen"
	add_child(tree_screen)
	tree_screen.setup(skill_tree, player.vitals)
	player.vitals.leveled_up.connect(func(_level: int) -> void: _auto_spend_points())
	# 装備を着替えたら、体のまわりに金色の輪と火花を出す（強くなった実感）
	stash.equipped.connect(func(_slot: String, _item: ItemInstance, _previous: ItemInstance) -> void:
		EnemyFx.spawn(world, EnemyFx.Kind.RING, player.global_position, Color(1.0, 0.85, 0.3), 30.0, 0.55)
		EnemyFx.spawn(world, EnemyFx.Kind.BURST, player.global_position, Color(1.0, 0.9, 0.5), 22.0, 0.5))


## マップの印（s=スライムの群れ、b=岩殻）に敵を置く。時間で湧かせず、倒しに行く配置
func _add_enemies() -> EnemyManager:
	var manager := EnemyManager.new()
	manager.name = "EnemyManager"
	manager.enemy_parent = world  # 壁・プレイヤーと同じ Y軸ソートの親に置き、描画順を合わせる
	world.add_child(manager)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var swarm: EnemyDef = DataDB.enemy("swarmling")
	var brute: EnemyDef = DataDB.enemy("brute")
	for pos: Vector2 in map.markers.get("f", []):
		manager.spawn_pack(swarm, pos, rng, SMALL_PACK_SIZE)  # 小さな群れ（序盤用）
	for pos: Vector2 in map.markers.get("s", []):
		manager.spawn_pack(swarm, pos, rng)
	var rare: EnemyDef = DataDB.enemy("gilded_golem")  # 低い確率で出る、色違いのレアモンスター
	for pos: Vector2 in map.markers.get("b", []):
		manager.spawn(rare if rng.randf() < RARE_CHANCE_AT_BRUTE else brute, pos)
	for key: String in ["f", "s"]:
		for pos: Vector2 in map.markers.get(key, []):
			if rng.randf() < RARE_CHANCE_AT_PACK:
				manager.spawn(rare, pos + Vector2(16, 0))
	var spitter: EnemyDef = DataDB.enemy("spitter")
	for pos: Vector2 in map.markers.get("r", []):  # 遠くから撃つスライム（2〜3匹）
		manager.spawn_pack(spitter, pos, rng)
	var boss_def: EnemyDef = DataDB.enemy("rock_lord")
	for pos: Vector2 in map.markers.get("X", []):  # ボス（最後の部屋）
		manager.spawn(boss_def, pos)
	return manager


func _add_skill_screen(stash: Stash) -> void:
	var screen := SkillScreen.new()
	screen.name = "SkillScreen"
	add_child(screen)
	screen.setup(player.caster, stash)


static func load_map(path: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().is_empty():
			rows.append(line.strip_edges(false, true))
	return rows


const HELP_FULL: String = "WASD: 移動　Space: 回避\n左クリック: スキル1　右クリック: スキル2　Q: スキル3\nK: スキル装備　I: 装備　T: スキルツリー\nG: 回復　F2: 自動戦闘　F4: カメラ切替\nF5: リセット　F9: 引き継いでリスタート\nコントローラー: 左スティック 移動 / A 回避 / B 回復 / RT・RB・X・Y スキル\nBack: スキル装備　Start: 装備　右押込み: ツリー　左押込み: 自動戦闘\nH: このヘルプを閉じる"
const HELP_COMPACT: String = "H: 操作ヘルプ"
const HELP_SHOW_SECONDS: float = 8.0  ## 起動してすぐは操作を出し、この時間がたったら、小さな「H: 操作ヘルプ」だけにする

var _help_label: Label
var _help_open: bool = true


## 操作ヘルプ。画面にかぶらないよう、最初の数秒だけ出し、あとは小さな一言にする（H で開閉）
func _add_help() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_help_label = Label.new()
	_help_label.position = Vector2(6, 4)
	_help_label.add_theme_font_size_override("font_size", 7)
	_help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_help_label.add_theme_constant_override("outline_size", 2)
	_help_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_help_label)
	set_help_open(true)
	get_tree().create_timer(HELP_SHOW_SECONDS).timeout.connect(func() -> void: set_help_open(false))


func set_help_open(open: bool) -> void:
	_help_open = open
	if _help_label != null:
		_help_label.text = HELP_FULL if open else HELP_COMPACT
		_help_label.modulate.a = 1.0 if open else 0.55
