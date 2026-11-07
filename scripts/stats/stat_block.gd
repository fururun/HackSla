class_name StatBlock
extends RefCounted
## ステータスの合計（stat のキー → 合計値）。装備・スキルツリー・バフなどを足し合わせて使う。
## キーは AffixDef.STATS（docs/data_schema.md の「stat に使えるキー」）。

var _values: Dictionary = {}


static func from_dict(d: Dictionary) -> StatBlock:
	var s := StatBlock.new()
	for key: String in d:
		s.add(key, float(d[key]))
	return s


func add(key: String, value: float) -> void:
	_values[key] = _values.get(key, 0.0) + value


func merge(other: StatBlock) -> void:
	for key: String in other._values:
		add(key, other._values[key])


func get_value(key: String) -> float:
	return _values.get(key, 0.0)


func keys() -> Array:
	return _values.keys()


func duplicate_block() -> StatBlock:
	var s := StatBlock.new()
	s._values = _values.duplicate()
	return s
