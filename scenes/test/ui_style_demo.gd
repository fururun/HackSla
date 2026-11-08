class_name UiStyleDemo
extends Node
## capture.gd -- --scene=res://scenes/test/ui_style_demo.tscn --view=hud|skill|equip|low|dead|levelup
var _caster: SkillCaster
var _elapsed: float = 0.0
var _view: String = "hud"

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			_view = arg.trim_prefix("--view=")
	var stash: Stash = Stash.new()
	var vitals: PlayerVitals = PlayerVitals.new()
	_caster = SkillCaster.new()
	add_child(_caster)
	_caster.loadout.set_support(1, "burst_on_kill")
	_caster.chain.discovered[DataDB.chains[0].id] = true
	_caster.chain.last_skill = DataDB.skill("frost_bloom")
	var hud: Hud = Hud.new()
	hud.setup(vitals)
	add_child(hud)
	var bar: SkillBar = SkillBar.new()
	bar.setup(_caster)
	add_child(bar)
	var loot: LootHud = LootHud.new()
	loot.setup(stash)
	add_child(loot)
	stash.collect(128)
	stash.collect(GemInstance.new(GemInstance.Kind.SKILL, "slash"))
	var item: ItemInstance = ItemInstance.new()
	item.base = DataDB.bases.values()[0]
	item.rarity = DataDB.rarities[2]
	var affix: AffixDef = DataDB.affixes.values()[0]
	item.affixes.append({"id": affix.id, "value": 7.0})
	stash.collect(item)
	vitals.stats = stash.equipment_stats()
	vitals.life = vitals.max_life()
	vitals.grant_xp(10)
	if _view == "low":
		vitals.take_damage(vitals.max_life() * 0.75)
	elif _view == "dead":
		vitals.take_damage(vitals.max_life())
	elif _view == "levelup":
		vitals.grant_xp(LevelCurve.xp_to_next(1))
	if _view == "skill":
		var screen: SkillScreen = SkillScreen.new()
		screen.setup(_caster, stash)
		add_child(screen)
		screen.open()
	elif _view == "equip":
		var screen: EquipScreen = EquipScreen.new()
		screen.setup(stash, vitals)
		add_child(screen)
		screen.open()
	else:
		# 撮影時にも実際のCDと完了フラッシュを観察できる。
		_caster.cast(2, Vector2.RIGHT, Vector2.ZERO)

func _process(delta: float) -> void:
	_elapsed += delta
	if _view in ["hud", "low"] and _elapsed >= 0.5 and _elapsed - delta < 0.5:
		for index: int in 3:
			DamageNumber.spawn(self, Vector2(150 + index * 65, 145), [8.0, 45.0, 120.0][index])
