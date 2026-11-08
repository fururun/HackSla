class_name SheetFx
extends Sprite2D
## pixelfx（MIT）から書き出したスプライトシートを再生する。SkillCaster などがプールして使い回す。
## 再生設定は data/fx/sheets.json、画像は art/fx/pixelfx/。画像は右向き・原点（足元／命中点）が pivot。

signal finished(fx: SheetFx)

const CONFIG_PATH: String = "res://data/fx/sheets.json"
const SHEET_DIR: String = "res://art/fx/pixelfx/"
const MIN_SCALE: float = 0.15
const MAX_SCALE: float = 2.5

static var _config: Dictionary = {}
static var _defs: Dictionary = {}  ## キー -> 読み込み済みの定義

var busy: bool = false
var _def: Dictionary = {}
var _t: float = 0.0
var _loop: bool = false


func _init() -> void:
	z_index = 5
	centered = false
	region_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # 縮小したときに粒が欠けないようにやわらかく
	hide()
	set_process(false)


# ---- 設定の読み込み ----

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_config = parsed if parsed is Dictionary else {"sheets": {}}
	return _config


## キーから再生に必要な情報を作る（画像とシートの情報は最初の1回だけ読む）。無いキーは空の辞書。
static func def_of(key: String) -> Dictionary:
	if _defs.has(key):
		return _defs[key]
	var entry: Dictionary = (config().get("sheets", {}) as Dictionary).get(key, {})
	if entry.is_empty():
		return {}
	var sheet: String = str(entry.get("sheet", key))
	var texture := load(SHEET_DIR + sheet + ".png") as Texture2D
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEET_DIR + sheet + ".json"))
	if texture == null or not meta is Dictionary:
		return {}
	var info: Dictionary = (meta as Dictionary).get("meta", {}).get("pixelfx", {})
	var frame_size: Array = info.get("frameSize", [1, 1])
	var pivot: Array = info.get("pivot", [0, 0])
	var count: int = int(info.get("frames", 1))
	var span: Array = entry.get("frames", [0, count - 1])
	var def := {
		"texture": texture,
		"frame_size": Vector2(float(frame_size[0]), float(frame_size[1])),
		"pivot": Vector2(float(pivot[0]), float(pivot[1])),
		"columns": maxi(1, int(info.get("columns", 1))),
		"fps": float(info.get("fps", 30.0)),
		"first": clampi(int(span[0]), 0, count - 1),
		"last": clampi(int(span[1]), 0, count - 1),
		"speed": float(entry.get("speed", 1.0)),
		"ref": float(entry.get("ref", 0.0)),
		"scale": float(entry.get("scale", 1.0)),
		"fit": float(entry.get("fit", 1.0)),  # 範囲の大きさに対する絵の大きさの割合（地面の輪を別に描くとき、絵を内側に収める）
		"loop": bool(entry.get("loop", false)),
	}
	_defs[key] = def
	return def


## スキルに使う再生キー（個別の指定 → 種類×属性の既定の順）。無ければ ""
static func key_for_skill(skill: SkillDef) -> String:
	var cfg := config()
	var overrides: Dictionary = cfg.get("skill_overrides", {})
	if overrides.has(skill.id):
		return str(overrides[skill.id])
	var by_kind: Dictionary = (cfg.get("by_kind", {}) as Dictionary).get(skill.kind, {})
	if by_kind.has(skill.element):
		return str(by_kind[skill.element])
	return str(by_kind.get("default", ""))


static func hit_key(element: String) -> String:
	return str((config().get("hit_by_element", {}) as Dictionary).get(element, ""))


## 範囲の絵の再生キー（属性ごと。なければ、物理のもの）
static func area_key(element: String) -> String:
	var area: Dictionary = (config().get("by_kind", {}) as Dictionary).get("area", {})
	return str(area.get(element, area.get("physical", "")))


static func explosion_key() -> String:
	return str(config().get("explosion", ""))


# ---- 再生 ----

## 画面上の向き dir（画像は右向き）に合わせた回転。左向き（dir.x < 0）は左右反転（scale.x が負）で使うので、
## 反転した絵を回す向きは逆になる。反転後の絵は左を向いており、回転 r で (−cos r, −sin r) の向きになるため、
## 目的の向き (−cos φ, +sin φ)（φ = (−dir.x, dir.y) の角度）にするには r = −φ。
static func rotation_for(dir: Vector2) -> float:
	if dir.x < 0.0:
		return -Vector2(-dir.x, dir.y).angle()
	return dir.angle()


## size_px が正なら、絵の ref（届く距離）がそのドット数になるよう拡大縮小する。0以下なら設定の scale のまま
func play(key: String, pos: Vector2, size_px: float = 0.0, rot: float = 0.0, mirror: bool = false) -> bool:
	var def := def_of(key)
	if def.is_empty():
		return false
	_def = def
	texture = def["texture"]
	var frame_size: Vector2 = def["frame_size"]
	offset = -(def["pivot"] as Vector2)
	var s: float = float(def["scale"])
	if size_px > 0.0 and float(def["ref"]) > 0.0:
		s = size_px * float(def["fit"]) / float(def["ref"])
	s = clampf(s, MIN_SCALE, MAX_SCALE)
	scale = Vector2(-s if mirror else s, s)
	rotation = rot
	global_position = pos
	reset_physics_interpolation()  # 使い回しの瞬間移動で、前の場所から滑ってこないように
	_loop = bool(def["loop"])
	_t = 0.0
	busy = true
	_show_frame(int(def["first"]))
	show()
	set_process(true)
	return true


func stop() -> void:
	if not busy:
		return
	busy = false
	hide()
	set_process(false)
	finished.emit(self)


## 時間を進める（テストからも呼べる）
func advance(delta: float) -> void:
	if not busy:
		return
	_t += delta * float(_def["speed"]) * float(_def["fps"])
	var first: int = _def["first"]
	var last: int = _def["last"]
	var length := last - first + 1
	var index := first + int(_t)
	if index > last:
		if _loop:
			_t = fposmod(_t, float(length))
			index = first + int(_t)
		else:
			stop()
			return
	_show_frame(index)


func current_frame() -> int:
	return int(_def.get("first", 0)) + int(_t) if busy else -1


func _process(delta: float) -> void:
	advance(delta)


func _show_frame(index: int) -> void:
	var frame_size: Vector2 = _def["frame_size"]
	var columns: int = _def["columns"]
	region_rect = Rect2(Vector2(float(index % columns), float(index / columns)) * frame_size, frame_size)
