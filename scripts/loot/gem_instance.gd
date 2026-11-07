class_name GemInstance
extends RefCounted

enum Kind { SKILL, SUPPORT }

var kind: Kind = Kind.SKILL
var id: String = ""


func _init(gem_kind: Kind = Kind.SKILL, gem_id: String = "") -> void:
	kind = gem_kind
	id = gem_id
