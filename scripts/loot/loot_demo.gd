class_name LootDemo
extends Node2D
## --demo=loot を渡した撮影時だけ撃破と歩行を自動で再現する。
var stash: Stash
var director: LootDirector
var player: Player
var manager: EnemyManager
var _frame: int = 0
var _automatic: bool = false
var _status: Label

func _ready() -> void:
	_automatic = "--demo=loot" in OS.get_cmdline_user_args()
	var world: Node2D = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	player = Player.new()
	player.position = Vector2(100, 156)
	world.add_child(player)
	manager = EnemyManager.new()
	manager.enemy_parent = world
	world.add_child(manager)
	manager.set_physics_process(false)
	stash = Stash.new()
	director = LootDirector.new()
	add_child(director)
	director.setup(manager, player, world, stash, func() -> int: return 1)
	director.rng.seed = 202020
	var hud: LootHud = LootHud.new()
	add_child(hud)
	hud.setup(stash)
	var screen: SkillScreen = SkillScreen.new()
	add_child(screen)
	screen.setup(player.caster, stash)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(10, 10)
	_status.add_theme_font_size_override("font_size", 8)
	layer.add_child(_status)
	var help: Label = Label.new()
	help.text = "WASD: 移動 / 左クリック: 攻撃 / K: スキル装備
装備・ジェムは近づくと回収 / 通貨は自動回収"
	help.position = Vector2(10, 237)
	help.add_theme_font_size_override("font_size", 8)
	layer.add_child(help)
	for index: int in 8:
		manager.spawn(DataDB.enemy("swarmling"), Vector2(205 + (index % 4) * 18, 144 + (index / 4) * 20))
	# 柱が見える既存装備も比較用に置く。ドロップ抽選結果は変更しない。
	var item: ItemInstance = ItemInstance.new()
	item.base = DataDB.bases.values()[0]
	for rarity: RarityDef in DataDB.rarities:
		if rarity.beam:
			item.rarity = rarity
			break
	director.spawn_drop(item, Vector2(260, 177))
	director.spawn_drop(GemInstance.new(GemInstance.Kind.SUPPORT, "scatter"), Vector2(280, 177))

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _automatic:
		if _frame == 10:
			for enemy: Enemy in manager._active.duplicate():
				enemy.take_hit(enemy.life, DataDB.skill("slash"))
		if _frame > 90 and _frame <= 230:
			player.position = player.position.move_toward(Vector2(290, 177), 1.5)
	_status.text = "T20  地面ドロップ → 歩いて回収
地面: %d / 装備中: %d" % [director.active_count(), stash.equipment.size()]

func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("17222b"))
	for x: int in range(-300, 600, 32):
		draw_line(Vector2(x, 40), Vector2(x + 400, 240), Color("263943"))
		draw_line(Vector2(x, 240), Vector2(x + 400, 40), Color("263943"))
