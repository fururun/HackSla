class_name EquipPreview
extends Node2D
## 撮影用: --preview=equip / pickup / ground
var _stash: Stash
var _vitals: PlayerVitals

func _ready() -> void:
	_stash = Stash.new()
	_vitals = PlayerVitals.new()
	_stash.changed.connect(func() -> void:
		_vitals.stats.clear()
		_vitals.stats.merge(_stash.equipment_stats()))
	var mode: String = "equip"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			mode = arg.trim_prefix("--preview=")
	var old: ItemInstance = _item("leather_vest", 0)
	_stash.collect(old)
	var improved: ItemInstance = _item("leather_vest", 2)
	improved.affixes = [{"id": "life_1", "value": 30}]
	if mode == "equip":
		_stash.collect(improved)
		_stash.collect(_item("rust_sword", 1))
		var screen: EquipScreen = EquipScreen.new()
		add_child(screen)
		screen.setup(_stash, _vitals)
		screen._select("armor")
		screen.open()
	else:
		var player: Node2D = Node2D.new()
		player.position = Vector2(200, 160)
		add_child(player)
		var marker: Polygon2D = Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -14), Vector2(5, 0)])
		marker.color = Color("b3ccd9")
		player.add_child(marker)
		var manager: EnemyManager = EnemyManager.new()
		add_child(manager)
		var director: LootDirector = LootDirector.new()
		add_child(director)
		director.setup(manager, player, self, _stash, func() -> int: return 1)
		director.spawn_drop(_item("leather_vest", 2), Vector2(245, 170))
		director.spawn_drop(_item("leather_vest", 4), Vector2(180, 185))
		director.spawn_drop(_item("leather_vest", 0), Vector2(400, 215))
		var hint: Label = Label.new()
		hint.text = "近くの装備だけ名前を表示 / 遠い装備は印のみ"
		hint.position = Vector2(12, 245)
		hint.add_theme_font_size_override("font_size", 8)
		add_child(hint)
		if mode == "pickup":
			var hud: LootHud = LootHud.new()
			add_child(hud)
			hud.setup(_stash)
			# 同じ部位の旧装備と比較し、増加と減少の両方を示す。
			var replacement: ItemInstance = _item("leather_vest", 2)
			replacement.base = ItemBaseDef.new()
			replacement.base.slot = old.base.slot
			replacement.base.name = old.base.name
			replacement.base.stats = old.base.stats.duplicate()
			replacement.base.stats["armor"] -= 5
			replacement.affixes = improved.affixes.duplicate()
			_stash.collect(replacement)
			_stash.collect(old)
			_stash.collect(GemInstance.new(GemInstance.Kind.SUPPORT, "scatter"))

func _item(base_id: String, tier: int) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.base = DataDB.bases.get(base_id, DataDB.bases.values()[0])
	for rarity: RarityDef in DataDB.rarities:
		if rarity.tier == tier:
			item.rarity = rarity
	return item

func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("17222b"))
	for x: int in range(-300, 600, 32):
		draw_line(Vector2(x, 40), Vector2(x + 400, 240), Color("263943"))
		draw_line(Vector2(x, 240), Vector2(x + 400, 40), Color("263943"))
