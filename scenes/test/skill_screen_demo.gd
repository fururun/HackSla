class_name SkillScreenDemo
extends Node
## 撮影・手動操作用。実データからチェインを1つ発見済みにする。

func _ready() -> void:
	var caster: SkillCaster = SkillCaster.new()
	add_child(caster)
	if not DataDB.chains.is_empty():
		caster.chain.discovered[DataDB.chains[0].id] = true
	var screen: SkillScreen = SkillScreen.new()
	screen.setup(caster)
	add_child(screen)
	screen.open()
