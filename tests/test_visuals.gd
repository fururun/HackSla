extends RefCounted

var t: Variant


func test_floor_pattern_is_coordinate_deterministic() -> void:
	var first: Dictionary = {}
	var variants: Dictionary = {}
	for y: int in range(-12, 13):
		for x: int in range(-12, 13):
			var cell := Vector2i(x, y)
			var tile: Vector2i = IsoMap.floor_tile(cell)
			first[cell] = tile
			variants[tile.y] = true
			t.check(tile.x == posmod(x + y, 2) and tile.y >= 0 and tile.y < IsoMap.FLOOR_VARIANTS, "負座標でも有効な床")
	for cell: Vector2i in first.keys():
		t.check_eq(IsoMap.floor_tile(cell), first[cell], "他の座標を処理しても模様は同じ")
	t.check(variants.size() >= IsoMap.FLOOR_VARIANTS - 1, "複数の模様が選ばれる")
	var a: TileSetAtlasSource = IsoMap.make_tileset().get_source(0)
	var b: TileSetAtlasSource = IsoMap.make_tileset().get_source(0)
	t.check_eq(a.texture.get_image().get_data(), b.texture.get_image().get_data(), "床と壁の生成画像が毎回一致")


func test_tileset_has_all_floor_variants_and_both_walls() -> void:
	var tiles: TileSet = IsoMap.make_tileset()
	var source: TileSetAtlasSource = tiles.get_source(0)
	for variant: int in IsoMap.FLOOR_VARIANTS:
		for shade: int in 2:
			t.check(source.has_tile(Vector2i(shade, variant)), "床の全模様が存在")
	for coord: Vector2i in [IsoMap.WALL, IsoMap.LOW_WALL]:
		t.check(source.has_tile(coord), "高い壁と低い縁が存在")
		t.check_eq(source.get_tile_data(coord, 0).get_collision_polygons_count(0), 1, "壁の衝突を維持")
	t.check_eq(tiles.tile_size, Vector2i(Iso.TILE_W, Iso.TILE_H), "タイル寸法を維持")


func test_debris_pool_capacity_expiry_and_reuse() -> void:
	var pool := DeathDebris.new()
	var first: int = pool.emit_at(Vector2(10, 20))
	for i: int in range(1, DeathDebris.CAPACITY):
		pool.emit_at(Vector2(i, 0))
	t.check_eq(pool.active_count(), DeathDebris.CAPACITY, "同時数は上限まで")
	t.check_eq(pool.emit_at(Vector2(50, 0)), first, "満杯なら固定スロットを再利用")
	t.check_eq(pool.active_count(), DeathDebris.CAPACITY, "上限を超えない")
	pool.tick(DeathDebris.DURATION * 0.5)
	t.check_eq(pool.active_count(), DeathDebris.CAPACITY, "途中は演出を維持")
	pool.tick(DeathDebris.DURATION)
	t.check_eq(pool.active_count(), 0, "0.3秒経過で消える")
	t.check(not pool.is_processing(), "空のプールは毎フレーム処理しない")
	pool.emit_at(Vector2.ZERO)
	t.check_eq(pool.active_count(), 1, "終了したスロットを再利用")
	t.check_eq(pool._remaining.size(), DeathDebris.CAPACITY, "ストレージも固定長")
	pool.free()


func test_hit_flash_and_death_entry_recycle() -> void:
	var tree: SceneTree = t
	await tree.process_frame
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var def: EnemyDef = tree.root.get_node("DataDB").enemy("swarmling")
	var enemy: Enemy = manager.spawn(def, Vector2(100, 100))
	t.check(not enemy.is_flashing() and not enemy.is_processing(), "未被弾は点滅処理なし")
	enemy.take_hit(0.0, null)
	t.check(not enemy.is_flashing(), "無効な被弾で点滅しない")
	enemy.take_hit(1.0, null)
	t.check(enemy.is_flashing() and enemy.is_processing(), "被弾から点滅開始")
	enemy.tick_flash(Enemy.FLASH_DURATION * 0.5)
	t.check(enemy.is_flashing(), "0.04秒後も白い")
	enemy.take_hit(1.0, null)
	enemy.tick_flash(Enemy.FLASH_DURATION * 0.75)
	t.check(enemy.is_flashing(), "連続被弾で時間を更新")
	enemy.tick_flash(Enemy.FLASH_DURATION)
	t.check(not enemy.is_flashing() and not enemy.is_processing(), "終了後は処理も止まる")
	enemy.take_hit(def.life, null)
	var pool := manager.get_node(NodePath(DeathDebris.POOL_NAME)) as DeathDebris
	t.check_eq(pool.active_count(), 1, "撃破入口で破片を出す")
	t.check_eq(pool._origins[0], Vector2(100, 100), "撃破位置に出る")
	enemy.take_hit(def.life, null)
	t.check_eq(pool.active_count(), 1, "撃破済みの被弾で演出を重複しない")
	var reused: Enemy = manager.spawn(def, Vector2.ZERO)
	t.check_eq(reused, enemy, "敵自身も再利用")
	t.check(not reused.is_flashing() and not reused.is_processing(), "再利用へ点滅を持ち越さない")
	reused.take_hit(def.life, null)
	t.check_eq(manager.get_node(NodePath(DeathDebris.POOL_NAME)), pool, "同じプールを再利用")
	t.check_eq(pool.active_count(), 2, "二度目の撃破も演出")
	manager.queue_free()
	await tree.process_frame
