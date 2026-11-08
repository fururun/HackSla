class_name GameLog
extends Node
## プレイのログ（遊んだ記録）と、デバッグのログ（エラー・警告・負荷の記録）を、ファイルに残す。
##   プレイのログ  user://logs/play_<日時>.log   起動・撃破・レベルアップ・死亡・ボス・宝箱・拾ったもの・スキルの使用、終了時のまとめ
##   デバッグのログ user://logs/debug_<日時>.log  エラー・警告（エンジンのものも）、10秒ごとの状態（FPS・敵の数・体力など）
## 場所の見つけかた：Windows では %APPDATA%\Godot\app_userdata\HackSla\logs\（Godot のメニュー「プロジェクト → ユーザーデータフォルダを開く」でも開ける）
## 古いログは、種類ごとに最新 KEEP_FILES 個だけ残して、自動で消す。

const KEEP_FILES: int = 20
const SNAPSHOT_INTERVAL: float = 10.0
const LOW_FPS: float = 40.0  ## これを下回ったら、デバッグのログに警告を書く
const HITCH_MS: int = 250  ## 1フレームにこれ以上かかったら（実時間）、「引っかかり」としてデバッグのログに書く
const SLOW_WARN_MS: int = 1500  ## 時間の流れが遅いまま、これ以上続いたら警告する（ヒットストップの戻り忘れ）
const REAL_DIR: String = "user://logs"
const TOOL_DIR: String = "user://logs_tools"  ## テスト・撮影（--script）で動かしたときは、遊んだログと混ざらないよう別の場所へ

var dir: String = ""
var play_path: String = ""
var debug_path: String = ""
var kills: int = 0
var deaths: int = 0
var skill_uses: Dictionary = {}  ## スキルの名前 -> 使った回数
var picked: int = 0
var chests_opened: int = 0
var level: int = 1

var _play: FileAccess
var _debug: FileAccess
var _mutex := Mutex.new()
var _started_ms: int = 0
var _snapshot_left: float = SNAPSHOT_INTERVAL
var _logger: _EngineLogger
var _player: Node
var _manager: Node
var _closed: bool = false
var _last_frame_ms: int = 0
var _frames_seen: int = 0
var _was_paused: bool = false
var _warned_stuck: bool = false
var _slow_ms: int = 0
var _warned_slow: bool = false


## エンジンのエラー・警告を、デバッグのログに流す（別スレッドから呼ばれることがある）
class _EngineLogger extends Logger:
	var sink: Callable

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind := "WARNING" if error_type == Logger.ERROR_TYPE_WARNING else "ERROR"
		if sink.is_valid():
			sink.call("%s %s (%s:%d %s)" % [kind, rationale if not rationale.is_empty() else code, file, line, function])


## 遊ぶときの保存先。テスト・撮影のときは別の場所
static func default_dir() -> String:
	return TOOL_DIR if OS.get_cmdline_args().has("--script") else REAL_DIR


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 一時停止中も動いて、止まっているときの様子を記録する


## ログのファイルを開く。dir を省略すると default_dir()
func open(log_dir: String = "") -> void:
	dir = log_dir if not log_dir.is_empty() else default_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	play_path = "%s/play_%s.log" % [dir, stamp]
	debug_path = "%s/debug_%s.log" % [dir, stamp]
	_play = FileAccess.open(play_path, FileAccess.WRITE)
	_debug = FileAccess.open(debug_path, FileAccess.WRITE)
	_started_ms = Time.get_ticks_msec()
	_rotate("play_")
	_rotate("debug_")
	_logger = _EngineLogger.new()
	_logger.sink = Callable(self, "debug")
	OS.add_logger(_logger)
	play("start", {"version": Engine.get_version_info().get("string", "?"), "renderer": RenderingServer.get_video_adapter_name()})
	debug("log opened: %s" % dir)


## プレイのログに1行書く（例：play("level_up", {"level": 3})）
func play(event: String, data: Dictionary = {}) -> void:
	_write(_play, event, data)


## デバッグのログに1行書く
func debug(message: String) -> void:
	_write(_debug, message, {})


## 画面の状態をつないで、遊んだ記録を取り始める
func setup(player: Node, manager: Node, stash: Object = null) -> void:
	_player = player
	_manager = manager
	if manager != null and manager.has_signal("enemy_hit"):
		manager.connect("enemy_hit", _on_enemy_hit)
	var vitals: Object = player.get("vitals") if player != null else null
	if vitals != null:
		vitals.connect("leveled_up", _on_level_up)
		vitals.connect("died", _on_died)
	var caster: Object = player.get("caster") if player != null else null
	if caster != null:
		caster.connect("cast_done", _on_cast)
	if stash != null and stash.has_signal("picked_up"):
		stash.connect("picked_up", _on_picked)
	for chest: Node in get_tree().get_nodes_in_group("chests"):
		chest.connect("opened", _on_chest_opened)


## 止まって見えるときの手がかりを残すため、ゲームが止まっていても（一時停止・ヒットストップ）動く。
## 時間は実時間で測る（ゲームの時間は、止まると進まないため）。
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var frame_ms := now - _last_frame_ms
	_last_frame_ms = now
	if frame_ms > HITCH_MS and _last_frame_ms > 0 and _frames_seen > 5:
		debug("HITCH frame=%dms time_scale=%.2f paused=%s enemies=%d" % [frame_ms, Engine.time_scale, str(get_tree().paused), get_tree().get_nodes_in_group("enemies").size()])
	_frames_seen += 1
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		play("paused" if paused else "resumed", {"screens_open": PauseHolder.count()})
		if not paused and PauseHolder.count() > 0:
			debug("WARNING resumed while screens are open")
	if paused and PauseHolder.count() == 0 and not _warned_stuck:
		_warned_stuck = true
		debug("WARNING paused but no screen is open (stuck pause)")
	elif not paused:
		_warned_stuck = false
	if Engine.time_scale < 1.0:
		_slow_ms += frame_ms
		if _slow_ms > SLOW_WARN_MS and not _warned_slow:
			_warned_slow = true
			debug("WARNING time_scale=%.2f for %dms (stuck hit-stop?)" % [Engine.time_scale, _slow_ms])
	else:
		_slow_ms = 0
		_warned_slow = false
	_snapshot_left -= frame_ms / 1000.0
	if _snapshot_left <= 0.0:
		_snapshot_left = SNAPSHOT_INTERVAL
		snapshot()


## 状態の記録（デバッグのログ）。FPS が低いときは警告も書く
func snapshot() -> void:
	var fps := Engine.get_frames_per_second()
	var enemies := get_tree().get_nodes_in_group("enemies").size() if is_inside_tree() else 0
	var pos := Vector2.ZERO
	var life := -1.0
	if is_instance_valid(_player):
		pos = (_player as Node2D).global_position
		var v: Object = _player.get("vitals")
		life = float(v.get("life")) if v != null else -1.0
	debug("snapshot fps=%d enemies=%d life=%.0f level=%d pos=(%.0f,%.0f) kills=%d paused=%s time_scale=%.2f" % [fps, enemies, life, level, pos.x, pos.y, kills, str(get_tree().paused), Engine.time_scale])
	if fps < LOW_FPS and fps > 0:
		debug("WARNING low fps=%d enemies=%d" % [fps, enemies])


func _on_enemy_hit(enemy: Object, _amount: float, killed: bool) -> void:
	if not killed:
		return
	kills += 1
	var def: Object = enemy.get("definition")
	var boss: bool = def != null and bool(def.get("is_boss"))
	if boss:
		play("boss_defeated", {"name": def.get("name"), "kills": kills})
	elif kills % 25 == 0:
		play("kills", {"total": kills})


func _on_level_up(new_level: int) -> void:
	level = new_level
	play("level_up", {"level": new_level, "kills": kills})


func _on_died() -> void:
	deaths += 1
	play("player_died", {"level": level, "kills": kills})


func _on_cast(_slot: int, skill: Object, _hits: int, chained: bool) -> void:
	var n: String = str(skill.get("id"))
	skill_uses[n] = int(skill_uses.get(n, 0)) + 1
	if chained and int(skill_uses[n]) == 1:
		play("chain_first_time", {"skill": n})


func _on_picked(value: Variant) -> void:
	picked += 1
	if value is Object and (value as Object).has_method("display_name"):
		play("picked", {"item": (value as Object).call("display_name")})


func _on_chest_opened(_chest: Node) -> void:
	chests_opened += 1
	play("chest_opened", {"count": chests_opened})


## 終わるときに、まとめを書いて閉じる
func close_logs() -> void:
	if _closed:
		return
	_closed = true
	var seconds := (Time.get_ticks_msec() - _started_ms) / 1000
	play("summary", {"seconds": seconds, "kills": kills, "deaths": deaths, "level": level, "picked": picked,
		"chests": chests_opened, "skills": JSON.stringify(skill_uses)})
	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null
	_mutex.lock()
	_play = null  # 閉じる
	_debug = null
	_mutex.unlock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		close_logs()


func _exit_tree() -> void:
	close_logs()


func _write(file: FileAccess, text: String, data: Dictionary) -> void:
	if file == null:
		return
	var t := (Time.get_ticks_msec() - _started_ms) / 1000
	var line := "[%02d:%02d] %s" % [t / 60, t % 60, text]
	for key: String in data:
		line += " %s=%s" % [key, str(data[key])]
	_mutex.lock()
	file.store_line(line)
	file.flush()
	_mutex.unlock()


## 種類ごとに、新しい順に KEEP_FILES 個だけ残す
func _rotate(prefix: String) -> void:
	var names: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.begins_with(prefix) and f.ends_with(".log"):
			names.append(f)
	names.sort()  # 日時が名前に入っているので、名前順＝古い順
	while names.size() > KEEP_FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(names.pop_front())))
