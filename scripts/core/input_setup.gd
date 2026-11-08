extends Node
## 操作の割り当てをコードで登録する（project.godot を手で書き換えずに済むように）。
## 操作を変えたいときは、この表だけを直す。

const KEYS: Dictionary = {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"skill_3": [KEY_Q],
	"skill_4": [KEY_E],
	"skill_5": [KEY_R],
	"skill_6": [KEY_F],
	"toggle_debug": [KEY_F1],
	"toggle_skill_screen": [KEY_K],
	"toggle_equip_screen": [KEY_I],
	"restart_game": [KEY_F5],
	"cycle_camera": [KEY_F4],
	"toggle_help": [KEY_H],
	"toggle_autobattle": [KEY_F2],
	"dodge": [KEY_SPACE],
}

const MOUSE: Dictionary = {
	"skill_1": MOUSE_BUTTON_LEFT,   # 通常攻撃（スキル枠1）
	"skill_2": MOUSE_BUTTON_RIGHT,  # スキル枠2
}


func _enter_tree() -> void:
	for action: String in KEYS:
		_ensure_action(action)
		for keycode: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE:
		_ensure_action(action)
		var mev := InputEventMouseButton.new()
		mev.button_index = MOUSE[action]
		InputMap.action_add_event(action, mev)


func _ensure_action(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
