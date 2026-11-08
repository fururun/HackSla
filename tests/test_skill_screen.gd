extends RefCounted

var t: Variant


func test_available_and_equip() -> void:
	var caster: SkillCaster = SkillCaster.new()
	var screen: SkillScreen = SkillScreen.new()
	screen.setup(caster)
	var available: Array[SkillDef] = screen._available_skills()
	var expected: int = 0
	for skill: SkillDef in DataDB.skills.values():
		if not skill.chain_only:
			expected += 1
	t.check_eq(available.size(), expected, "通常スキルを全て出す")
	for skill: SkillDef in available:
		t.check(not skill.chain_only, "チェイン専用技は出ない")
	t.check(not screen._equip("shatter"), "専用技を装備操作でも拒否")
	t.check_eq(caster.loadout.skill_id(1), "slash", "拒否時は変更しない")
	t.check(screen._equip("fire_bolt"), "画面から火球に変更")
	t.check_eq(caster.loadout.skill_id(1), "fire_bolt", "ロードアウトへ反映")
	var projectile_supports: Array[SupportDef] = screen._available_supports(1)
	t.check(projectile_supports.has(DataDB.support("scatter")), "飛び道具には拡散が出る")
	screen._select_support = true
	t.check(screen._equip("scatter"), "画面から補助を装備")
	t.check_eq(caster.loadout.support_id(1), "scatter", "補助を反映")
	caster.loadout.set_skill(1, "slash")
	t.check(not screen._available_supports(1).has(DataDB.support("scatter")), "近接には拡散を出さない")
	t.check(screen._equip("burst_on_kill"), "全種類対応の補助を装備")
	t.check(not screen._equip("scatter"), "不適合な補助を拒否")
	t.check_eq(caster.loadout.support_id(1), "burst_on_kill", "拒否しても装備は保持")
	caster.loadout.clear_skill(1)
	t.check(screen._available_supports(1).is_empty(), "空の枠には補助候補なし")
	screen.free()
	caster.free()


func test_chain_privacy_and_counts() -> void:
	var caster: SkillCaster = SkillCaster.new()
	var screen: SkillScreen = SkillScreen.new()
	screen.setup(caster)
	t.check_eq(screen._discovered_count(), 0, "初期は未発見")
	for entry: Dictionary in screen._chain_entries():
		t.check_eq(entry["name"], "？", "未発見の名前を隠す")
		t.check_eq(entry["description"], "", "未発見の説明を隠す")
	caster.chain.discovered[DataDB.chains[0].id] = true
	caster.chain.discovered["unknown_test_id"] = true
	t.check_eq(screen._discovered_count(), 1, "実在する発見数だけ数える")
	t.check_eq(screen._chain_entries()[0]["name"], DataDB.chains[0].name, "発見済みの名前を表示")
	t.check_eq(screen._chain_entries()[0]["description"], DataDB.chains[0].description, "発見済みの説明を表示")
	screen.free()
	caster.free()


func test_pause_toggle_and_restore() -> void:
	var tree: SceneTree = t as SceneTree
	var caster: SkillCaster = SkillCaster.new()
	var screen: SkillScreen = SkillScreen.new()
	screen.setup(caster)
	tree.root.add_child(screen)
	screen.open()
	screen.open()
	t.check(tree.paused and screen.is_open(), "開くと一時停止、二重openは無害")
	t.check_eq(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "停止中も操作可能")
	screen.toggle()
	t.check(not tree.paused and not screen.is_open(), "閉じると再開")
	tree.paused = true
	screen.toggle()
	screen.close()
	t.check(tree.paused, "元々停止中なら停止を維持")
	tree.paused = false
	screen.open()
	screen.free()
	t.check(not tree.paused, "画面破棄時にも再開")
	caster.free()


func test_mouse_controls_and_key() -> void:
	var tree: SceneTree = t as SceneTree
	var caster: SkillCaster = SkillCaster.new()
	var screen: SkillScreen = SkillScreen.new()
	screen.setup(caster)
	tree.root.add_child(screen)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	screen._unhandled_input(key)
	t.check(screen.is_open() and tree.paused, "K入力で開く")
	var skill_button: Button = screen._slots.get_child(2) as Button
	skill_button.pressed.emit()
	var choice: Button = screen._choices.get_child(4) as Button
	choice.pressed.emit()
	t.check_eq(caster.loadout.skill_id(1), "fire_bolt", "候補ボタンから付け替え")
	var support_button: Button = screen._slots.get_child(3) as Button
	support_button.pressed.emit()
	t.check(screen._select_support, "補助ボタンで補助一覧を選択")
	var support_choice: Button = screen._choices.get_child(0) as Button
	support_choice.pressed.emit()
	t.check_eq(caster.loadout.support_id(1), screen._available_supports(1)[0].id, "補助候補を装備")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	(screen._slots.get_child(3) as Button).gui_input.emit(right)
	t.check_eq(caster.loadout.support_id(1), "", "補助枠の右クリックで解除")
	(screen._slots.get_child(2) as Button).gui_input.emit(right)
	t.check_eq(caster.loadout.skill_id(1), "", "スキル枠の右クリックで解除")
	key.echo = true
	screen._unhandled_input(key)
	t.check(screen.is_open(), "キーリピートでは閉じない")
	key.echo = false
	screen._unhandled_input(key)
	t.check(not screen.is_open() and not tree.paused, "停止中もK入力で閉じる")
	screen.free()
	caster.free()


func test_stash_filters_and_optional_setup() -> void:
	var stash: Stash = Stash.new()
	stash.gems.clear()
	stash.add_gem(GemInstance.new(GemInstance.Kind.SKILL, "fire_bolt"))
	var caster: SkillCaster = SkillCaster.new()
	caster.loadout.set_skill(1, "fire_bolt")
	var screen: SkillScreen = SkillScreen.new()
	screen.setup(caster, stash)
	t.check_eq(screen._available_skills().size(), 1, "所持スキルだけ候補")
	t.check(not screen._equip("slash"), "未所持は装備不可")
	t.check(screen._available_supports(1).is_empty(), "未所持補助は候補に出ない")
	stash.add_gem(GemInstance.new(GemInstance.Kind.SUPPORT, "scatter"))
	t.check_eq(screen._available_supports(1).size(), 1, "所持補助が増える")
	screen._select_support = true
	t.check(screen._equip("scatter"), "拾った補助を装備")
	caster.loadout.set_skill(1, "slash")
	t.check(screen._available_supports(1).is_empty(), "所持していても適合性を守る")
	stash.add_gem(GemInstance.new(GemInstance.Kind.SKILL, "shatter"))
	t.check_eq(screen._available_skills().size(), 1, "所持しても専用技は除外")
	screen.setup(caster)
	t.check(screen._available_skills().size() > 1, "省略すると従来の全候補")
	screen.free()
	caster.free()
