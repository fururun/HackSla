class_name HudDemo
extends Node
## HUD 確認用（撮影・手動）。被ダメージと経験値を与えて表示する。
## 撮影: capture.gd --scene=res://scenes/test/hud_demo.tscn -- --dead / --levelup

func _ready() -> void:
	var vitals := PlayerVitals.new()
	vitals.take_damage(35.0)
	vitals.grant_xp(10)
	var hud := Hud.new()
	hud.setup(vitals)
	add_child(hud)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--dead"):
		vitals.tick(1.0)
		vitals.take_damage(9999.0)
	elif args.has("--levelup"):
		vitals.grant_xp(LevelCurve.xp_to_next(1))
