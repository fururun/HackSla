extends RefCounted
## AI が描いたドット絵（岩殻・宝箱・案山子・ドロップのアイコン・侍）が読み込めること、アイコンの選び方

var t: Variant


func test_sprites_load() -> void:
	for path: String in [
		"res://art/sprites/enemies/rockgolem_front.png",
		"res://art/sprites/enemies/rockgolem_back.png",
		"res://art/sprites/enemies/rockgolem_side.png",
		"res://art/sprites/objects/chest_closed.png",
		"res://art/sprites/objects/chest_open.png",
		"res://art/sprites/objects/training_dummy.png",
		"res://art/sprites/player/player_front.png",
		"res://art/sprites/player/player_back.png",
		"res://art/sprites/player/player_side.png",
	]:
		t.check(load(path) is Texture2D, "絵を読める: %s" % path)
	for name: String in ["gem_skill", "gem_support", "sword", "armor", "ring", "coin"]:
		t.check(load("res://art/sprites/icons/icon_%s.png" % name) is Texture2D, "アイコンを読める: %s" % name)


func test_drop_icon_choice() -> void:
	t.check_eq(GroundDrop.icon_name(GemInstance.new(GemInstance.Kind.SKILL, "slash")), "gem_skill", "スキルジェム")
	t.check_eq(GroundDrop.icon_name(GemInstance.new(GemInstance.Kind.SUPPORT, "scatter")), "gem_support", "補助ジェム")
	t.check_eq(GroundDrop.icon_name(12), "coin", "通貨")
	var roller := LootRoller.new(RandomNumberGenerator.new())
	var seen := {}
	for i in 400:
		var item: ItemInstance = roller.roll_item(10)
		if item != null:
			seen[str(item.base.slot)] = GroundDrop.icon_name(item)
	for slot: String in seen:
		var expected := "sword" if slot == "weapon" else ("ring" if slot in ["ring", "amulet"] else "armor")
		t.check_eq(seen[slot], expected, "部位 %s のアイコン" % slot)
	t.check(seen.size() >= 1, "装備が出る")
	# 部位ごとの選び方は、部位名から直接確かめる（出る部位は抽選とレベルに左右されるため）
	for pair: Array in [["weapon", "sword"], ["ring", "ring"], ["amulet", "ring"], ["armor", "armor"], ["helmet", "armor"], ["boots", "armor"]]:
		var item := ItemInstance.new()
		item.base = ItemBaseDef.new()
		item.base.slot = pair[0]
		t.check_eq(GroundDrop.icon_name(item), pair[1], "部位 %s のアイコン" % pair[0])
