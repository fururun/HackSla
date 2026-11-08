extends Node2D
## テスト用のメイン画面：マップを作り、プレイヤーと案山子を置く。

const MAP_PATH: String = "res://data/maps/field_01.txt"  ## 広いマップ。作り方は tools/maps/make_field_01.py、設計は docs/map_field_01.md
const SMALL_PACK_SIZE: int = 6  ## マップの印 f の群れの数
## カメラの引き（拡大率）。1.0 で、画面が 480x270 ドットの範囲。0.5 なら、2倍の範囲（960x540）が見える。
## 画面を3倍に拡大して描く（1440x810）とき、2/3 なら、ドット1つがちょうど画面の2ピクセルになって、にじまない。
const CAMERA_ZOOM: float = 0.5

var world: Node2D
var map: IsoMap
var player: Player
var stash: Stash  ## 持ち物（拾ったジェム・装備・通貨）
var game_log: GameLog  ## 遊んだ記録とデバッグの記録


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	map = IsoMap.new()
	map.name = "Map"
	add_child(map)
	move_child(map, 0)
	map.build(load_map(MAP_PATH), world)

	player = Player.new()
	player.name = "Player"
	player.position = map.marker("P")
	world.add_child(player)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * CAMERA_ZOOM  # 引き：小さいほど、広い範囲が見える
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # プレイヤーと同じ物理の刻みで追う（がくつき防止）
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.offset = Vector2(0, -10)
	player.add_child(cam)

	for pos: Vector2 in map.markers.get("D", []):
		var dummy := TrainingDummy.new()
		dummy.position = pos
		world.add_child(dummy)

	var manager := _add_enemies()
	stash = Stash.new()
	_add_skill_screen(stash)
	_add_progression(manager, stash)
	game_log = GameLog.new()  # 遊んだ記録とデバッグの記録（user://logs/）
	game_log.name = "GameLog"
	add_child(game_log)
	game_log.open()
	game_log.setup(player, manager, stash)
	add_child(RestartListener.new())
	_add_help()


## 体力・経験値・ドロップ・装備をつなぐ
func _add_progression(manager: EnemyManager, stash: Stash) -> void:
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(player.vitals)
	var boss_bar := BossBar.new()  # ボスの体力の棒（画面の上の中央）
	boss_bar.name = "BossBar"
	add_child(boss_bar)
	boss_bar.setup(manager)
	var skill_bar := SkillBar.new()  # 画面下の、使えるスキルと再使用までの秒数
	skill_bar.name = "SkillBar"
	add_child(skill_bar)
	skill_bar.setup(player.caster)

	# 敵に殴られる／倒した経験値
	manager.player_hit.connect(player.on_player_hit)
	manager.enemy_hit.connect(func(enemy: Enemy, _amount: float, killed: bool) -> void:
		if killed and enemy.definition != null:
			player.vitals.grant_xp(enemy.definition.xp))

	# ドロップ：倒した敵の位置に出て、歩いて拾う
	var director := LootDirector.new()
	director.name = "LootDirector"
	add_child(director)
	director.setup(manager, player, world, stash, func() -> int: return player.vitals.level)
	director.is_valid_position = func(pos: Vector2) -> bool: return map.is_floor_at(pos, true)  # 壁の中・壁ぎわに置かない
	# 宝箱：近づくと開いて、まとまった数のドロップが出る（最初の広場に置く）
	for pos: Vector2 in map.markers.get("C", []):
		var chest := TreasureChest.new()
		chest.position = pos
		world.add_child(chest)
		chest.opened.connect(func(c: TreasureChest) -> void: director.drop_chest(c.global_position))

	var equip_screen := EquipScreen.new()
	equip_screen.name = "EquipScreen"
	add_child(equip_screen)
	equip_screen.setup(stash, player.vitals)
	var loot_hud := LootHud.new()
	loot_hud.name = "LootHud"
	add_child(loot_hud)
	loot_hud.setup(stash)

	# 装備のステータスを、体力・スキルのダメージ計算が見ている入れ物に反映する
	var apply_equipment := func() -> void:
		player.caster.stats.clear()
		player.caster.stats.merge(stash.equipment_stats())
		player.vitals.changed.emit()
	stash.changed.connect(apply_equipment)


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
	for pos: Vector2 in map.markers.get("b", []):
		manager.spawn(brute, pos)
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


func _add_help() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var help := Label.new()
	help.text = "WASD: 移動　左クリック: スキル1　右クリック: スキル2　Q: スキル3　K: スキル装備　I: 装備　F5: やり直し"
	help.position = Vector2(6, 4)
	help.add_theme_font_size_override("font_size", 8)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	help.add_theme_constant_override("outline_size", 2)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(help)
