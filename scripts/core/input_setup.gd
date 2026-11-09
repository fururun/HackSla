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
	"restart_game": [KEY_F5],  # リセット（完全にやり直す）
	"restart_carry": [KEY_F9],  # 引き継いでリスタート
	"toggle_skill_tree": [KEY_T],
	"cycle_camera": [KEY_F4],
	"toggle_help": [KEY_H],
	"toggle_autobattle": [KEY_F2],
	"heal": [KEY_G],
	"autobattle_route": [KEY_F3],
	"autobattle_chests": [KEY_F6],
	"autobattle_support": [KEY_F7],
	"dodge": [KEY_SPACE],
}

const MOUSE: Dictionary = {
	"skill_1": MOUSE_BUTTON_LEFT,   # 通常攻撃（スキル枠1）
	"skill_2": MOUSE_BUTTON_RIGHT,  # スキル枠2
}


## コントローラー（Xbox基準。ボタン番号は Godot の JoyButton / JoyAxis）
##   左スティック／十字キー＝移動　A＝回避　B＝回復　RT＝スキル1　RB＝スキル2　X＝スキル3　Y＝スキル4　LT＝スキル5　LB＝スキル6
##   Back＝スキル装備　Start＝装備　右スティック押し込み＝スキルツリー　左スティック押し込み＝自動戦闘
## 画面の中では、十字キー／左スティックで選び、A＝決定、B＝閉じる、Y＝（スキル装備画面で）外す
const JOY_BUTTONS: Dictionary = {
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"dodge": [JOY_BUTTON_A],
	"heal": [JOY_BUTTON_B],
	"skill_2": [JOY_BUTTON_RIGHT_SHOULDER],
	"skill_3": [JOY_BUTTON_X],
	"skill_4": [JOY_BUTTON_Y],
	"skill_6": [JOY_BUTTON_LEFT_SHOULDER],
	"toggle_skill_screen": [JOY_BUTTON_BACK],
	"toggle_equip_screen": [JOY_BUTTON_START],
	"toggle_skill_tree": [JOY_BUTTON_RIGHT_STICK],
	"toggle_autobattle": [JOY_BUTTON_LEFT_STICK],
}

## [JoyAxis, 向き(+1/-1)]
const JOY_AXES: Dictionary = {
	"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"skill_1": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"skill_5": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
}

const STICK_DEADZONE: float = 0.3
const TRIGGER_DEADZONE: float = 0.5


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
	for action: String in JOY_BUTTONS:
		_ensure_action(action, false)
		for button: int in JOY_BUTTONS[action]:
			var jev := InputEventJoypadButton.new()
			jev.button_index = button
			InputMap.action_add_event(action, jev)
	for action: String in JOY_AXES:
		_ensure_action(action, false)
		for pair: Array in JOY_AXES[action]:
			var aev := InputEventJoypadMotion.new()
			aev.axis = int(pair[0])
			aev.axis_value = float(pair[1])
			InputMap.action_add_event(action, aev)
		InputMap.action_set_deadzone(action, TRIGGER_DEADZONE if action.begins_with("skill_") else STICK_DEADZONE)


func _ensure_action(action: String, reset: bool = true) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	elif reset:
		InputMap.action_erase_events(action)
