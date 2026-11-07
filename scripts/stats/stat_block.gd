class_name StatBlock
extends RefCounted
## stat のキー → 合計値。装備・ツリー・ジェムの付与効果をここに足していく。

var _values: Dictionary = {}


func add(key: String, value: float) -> void:
	_values[key] = float(_values.get(key, 0.0)) + value


## 別の StatBlock の中身を全部足す
func merge(other: StatBlock) -> void:
	for key: String in other._values:
		add(key, float(other._values[key]))


## 無いキーは 0.0
func get_value(key: String) -> float:
	return float(_values.get(key, 0.0))
