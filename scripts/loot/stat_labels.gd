class_name StatLabels
extends RefCounted

const NAMES: Dictionary = {
	"life": "最大ライフ", "armor": "防御", "damage_pct": "ダメージ",
	"fire_damage_pct": "火ダメージ", "cold_damage_pct": "冷気ダメージ",
	"lightning_damage_pct": "雷ダメージ", "cast_speed_pct": "スキルの速さ",
	"move_speed_pct": "移動速度", "area_pct": "範囲", "cooldown_pct": "再使用時間の短縮",
	"fire_res": "火耐性", "cold_res": "冷気耐性", "lightning_res": "雷耐性",
	"life_on_kill": "撃破時のライフ回復", "mana": "最大マナ", "mana_regen": "マナ回復（毎秒）",
}
const INCREASE_COLOR: Color = Color("8ce6a0")
const DECREASE_COLOR: Color = Color("ff9b91")

static func display_name(key: String) -> String:
	return str(NAMES.get(key, key))

static func format_value(key: String, value: float) -> String:
	var number: String = str(roundi(absf(value))) if is_equal_approx(value, roundf(value)) else String.num(absf(value), 2)
	return ("−" if value < 0.0 else "+") + number + ("%" if key.ends_with("_pct") or key.ends_with("_res") else "")

static func stat_line(key: String, value: float) -> String:
	return display_name(key) + " " + format_value(key, value)

## 新旧の和集合を比較し、失われた性能も表示する。
static func changes(new_item: ItemInstance, old_item: ItemInstance = null) -> Array[Dictionary]:
	var current: Dictionary = new_item.total_stats()
	var previous: Dictionary = old_item.total_stats() if old_item != null else {}
	var keys: Dictionary = current.duplicate()
	keys.merge(previous)
	var lines: Array[Dictionary] = []
	for key: String in keys:
		var delta: float = float(current.get(key, 0.0)) - float(previous.get(key, 0.0))
		if is_zero_approx(delta):
			continue
		lines.append({"key": key, "value": delta, "text": stat_line(key, delta),
			"color": INCREASE_COLOR if delta > 0.0 else DECREASE_COLOR})
	return lines
