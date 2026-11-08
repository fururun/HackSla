extends RefCounted
var t: Variant

func _item(tier: int, stats: Dictionary) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.base = ItemBaseDef.new()
	item.base.slot = "weapon"
	item.base.name = "試験の剣"
	item.base.stats = stats
	item.rarity = RarityDef.new()
	item.rarity.tier = tier
	item.rarity.color = Color.YELLOW
	return item

func test_labels_and_changes() -> void:
	var keys: Array[String] = ["life", "armor", "damage_pct", "fire_damage_pct", "cold_damage_pct", "lightning_damage_pct", "cast_speed_pct", "move_speed_pct", "area_pct", "cooldown_pct", "fire_res", "cold_res", "lightning_res", "life_on_kill"]
	for key: String in keys:
		t.check(StatLabels.display_name(key) != key, "日本語名: " + key)
		t.check_eq(StatLabels.format_value(key, 12.0), "+12" + ("%" if key.ends_with("_pct") or key.ends_with("_res") else ""), "値の単位: " + key)
	t.check_eq(StatLabels.display_name("unknown"), "unknown", "未知のキーは維持")
	t.check_eq(StatLabels.format_value("life", -5.5), "−5.5", "小数と減少")
	var old: ItemInstance = _item(0, {"life": 10, "armor": 5, "fire_res": 3})
	var item: ItemInstance = _item(1, {"life": 40, "armor": 5, "damage_pct": 12})
	var lines: Array[Dictionary] = StatLabels.changes(item, old)
	t.check_eq(lines.size(), 3, "不変を除外し新旧の和集合で比較")
	var by_key: Dictionary = {}
	for line: Dictionary in lines:
		by_key[line["key"]] = line
	t.check_eq(by_key["life"]["text"], "最大ライフ +30", "増加行")
	t.check_eq(by_key["fire_res"]["text"], "火耐性 −3%", "失われた性能")
	t.check_eq(by_key["life"]["color"], StatLabels.INCREASE_COLOR, "増加の色")
	t.check_eq(by_key["fire_res"]["color"], StatLabels.DECREASE_COLOR, "減少の色")
	t.check_eq(StatLabels.changes(item).size(), 3, "前装備なしでは全性能")

func test_signals_and_hud() -> void:
	var stash: Stash = Stash.new()
	var equipped: Array = []
	var skipped: Array = []
	stash.equipped.connect(func(slot: String, item: ItemInstance, previous: ItemInstance) -> void: equipped.append([slot, item, previous]))
	stash.skipped.connect(func(item: ItemInstance) -> void: skipped.append(item))
	var hud: LootHud = LootHud.new()
	hud.setup(stash)
	var low: ItemInstance = _item(0, {"armor": 10})
	var high: ItemInstance = _item(1, {"life": 30, "armor": 5})
	stash.collect(low)
	stash.collect(high)
	t.check_eq(equipped, [["weapon", low, null], ["weapon", high, low]], "新旧の装備を通知")
	t.check_eq(hud._recent[1]["text"], "装備した：" + high.display_name(), "装備した通知")
	t.check_eq(hud._recent[1]["lines"].size(), 2, "増減を各行に表示")
	stash.collect(low)
	t.check_eq(skipped, [low], "見送りを通知")
	t.check(hud._recent[2]["text"].begins_with("見送り："), "見送りの表示")
	hud.free()

func test_screen_slots_pause_refresh_and_details() -> void:
	var tree: SceneTree = t as SceneTree
	var stash: Stash = Stash.new()
	var vitals: PlayerVitals = PlayerVitals.new()
	var screen: EquipScreen = EquipScreen.new()
	screen.setup(stash, vitals)
	t.check_eq(screen.slot_entries().size(), 6, "6部位")
	for entry: Dictionary in screen.slot_entries():
		t.check_eq(entry["name"], "—", "空部位")
	tree.root.add_child(screen)
	screen.open()
	t.check(tree.paused and screen.is_open(), "開くと停止")
	var item: ItemInstance = _item(0, {"life": 30})
	var affix: AffixDef = DataDB.affixes.values()[0]
	item.affixes.append({"id": affix.id, "value": 7})
	stash.collect(item)
	t.check_eq(screen.slot_entries()[0]["name"], item.display_name(), "装備更新")
	t.check(screen._details.get_child(1).text.contains(affix.name), "全付与効果の名前")
	t.check(screen._totals.get_child(1).text.contains(str(vitals.max_life())), "vitalsの最大ライフ")
	var input: InputEventAction = InputEventAction.new()
	input.action = "toggle_equip_screen"
	input.pressed = true
	screen._unhandled_input(input)
	t.check(not tree.paused and not screen.is_open(), "閉じると再開")
	tree.paused = true
	screen.open()
	screen.close()
	t.check(tree.paused, "元々停止していた場合は停止を維持")
	tree.paused = false
	screen.free()
	# UIの遅延破棄を次のテストへ持ち越さない。
	await tree.process_frame

func test_ground_name_distance_and_reuse() -> void:
	var drop: GroundDrop = GroundDrop.new()
	var item: ItemInstance = _item(0, {})
	drop.activate(item, Vector2.ZERO)
	drop.update_name_visibility(Vector2(0, GroundDrop.NAME_RADIUS))
	t.check(drop._name_label == null, "遠いものはラベルを作らない")
	drop.update_name_visibility(Vector2(0, GroundDrop.NAME_RADIUS * 0.5))
	t.check(drop._name_label.visible, "アイソ距離の境界で表示")
	t.check_eq(drop._name_label.text, item.display_name(), "装備名")
	t.check_eq(drop._name_label.get_theme_color("font_color"), item.rarity.color, "レアリティ色")
	var label: Label = drop._name_label
	drop.update_name_visibility(Vector2(1000, 0))
	t.check(not label.visible, "離れると非表示")
	drop.deactivate()
	drop.activate(2, Vector2.ZERO)
	drop.update_name_visibility(Vector2.ZERO)
	t.check(not label.visible, "通貨へ再利用時は非表示")
	drop.activate(item, Vector2.ZERO)
	drop.update_name_visibility(Vector2.ZERO)
	t.check_eq(drop._name_label, label, "ラベルも再利用")
	drop.free()
