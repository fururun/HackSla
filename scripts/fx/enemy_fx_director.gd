class_name EnemyFxDirector
extends Node
## 敵の攻撃のエフェクトを、信号に合わせて出す（見た目だけ。当たりは EnemyManager が決める）。
## 殴られた・範囲攻撃・岩落とし・突進・弾の発射と着弾に、それぞれ輪・火花・光を出す。

const HIT_COLOR := Color(1.0, 0.45, 0.35)
const SHOCK_COLOR := Color(1.0, 0.7, 0.35)

var _parent: Node
var _player: Node2D


func setup(manager: EnemyManager, player: Player, parent: Node) -> void:
	_parent = parent
	_player = player
	player.damaged.connect(_on_player_damaged)
	manager.aoe_telegraph.connect(_on_charge_up)
	manager.aoe_burst.connect(_on_aoe_burst)
	manager.rain_impact.connect(_on_rain_impact)
	manager.charge_started.connect(_on_charge_started)
	manager.charge_ended.connect(_on_charge_ended)
	manager.shot_charging.connect(_on_shot_charging)
	manager.shot_fired.connect(_on_shot_fired)
	manager.bullet_landed.connect(_on_bullet_landed)


## 殴られた：プレイヤーの体に、赤い火花と光
func _on_player_damaged(_amount: float, source: Node) -> void:
	var color: Color = HIT_COLOR
	if source is Enemy and source.definition != null and source.definition.behavior == "ranged":
		color = source.definition.color.lightened(0.4)
	EnemyFx.spawn(_parent, EnemyFx.Kind.BURST, _player.global_position, color, 16.0, 0.25)
	EnemyFx.spawn(_parent, EnemyFx.Kind.FLASH, _player.global_position, color, 9.0, 0.15)


## 範囲攻撃・叩きつけの、ため（足元に光が集まる）
func _on_charge_up(enemy: Enemy, radius: float, windup: float) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.CHARGE, enemy.global_position, SHOCK_COLOR, minf(radius * 0.5, 40.0), windup)


## 範囲攻撃：衝撃の輪が、予告の円いっぱいまで走り、火花が飛ぶ
func _on_aoe_burst(enemy: Enemy, radius: float) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.RING, enemy.global_position, SHOCK_COLOR, radius, 0.4)
	EnemyFx.spawn(_parent, EnemyFx.Kind.BURST, enemy.global_position, SHOCK_COLOR, minf(radius * 0.5, 36.0), 0.4)


func _on_rain_impact(pos: Vector2, radius: float) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.RING, pos, SHOCK_COLOR, radius, 0.3)
	EnemyFx.spawn(_parent, EnemyFx.Kind.BURST, pos, Color(0.85, 0.8, 0.7), radius * 0.6, 0.35)


func _on_charge_started(enemy: Enemy) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.RING, enemy.global_position, Color(0.9, 0.9, 0.95), 18.0, 0.25)


func _on_charge_ended(enemy: Enemy) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.RING, enemy.global_position, SHOCK_COLOR, 24.0, 0.3)
	EnemyFx.spawn(_parent, EnemyFx.Kind.BURST, enemy.global_position, Color(0.85, 0.8, 0.7), 14.0, 0.3)


## 撃つ前のため：光の粒が集まる
func _on_shot_charging(enemy: Enemy, windup: float) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.CHARGE, enemy.global_position, enemy.definition.color.lightened(0.5), 14.0, windup)


func _on_shot_fired(enemy: Enemy) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.FLASH, enemy.global_position, enemy.definition.color.lightened(0.5), 9.0, 0.15)


func _on_bullet_landed(pos: Vector2, color: Color) -> void:
	EnemyFx.spawn(_parent, EnemyFx.Kind.BURST, pos, color, 10.0, 0.22)
