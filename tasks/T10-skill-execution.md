---
id: T10
agent: claude
title: スキル実行（ジェム・補助・チェイン・撃破時爆発）
allowed: scripts/skills/ scripts/combat/ scripts/player/player.gd tests/test_skills.gd
---

## 目的
いまのプレイヤーは「通常攻撃（斬撃）だけ」を `player.gd` に直書きしている。スキルのデータ（`data/skills/` と `data/supports/` と `data/chains/`）から、スキル枠に入れたスキルを実際に出せるようにする。補助ジェム、スキルチェイン、撃破時の爆発まで含む。

## 前提（すでにあるもの）
- `DataDB`（`DataDB.skill(id)` ほか）、`SkillDef` / `SupportDef` / `ChainRule`、`ChainTracker`（`on_cast` / `preview`）
- ダメージ計算 `scripts/stats/damage_calc.gd`（`skill_damage` → `apply_resistance` / `apply_armor`）、`StatBlock`（T09）
- 敵：`EnemyManager`（`enemies` グループ、`Enemy.take_hit(amount, skill)`、`life`、`active`、`definition.life`）。倒れたかどうかは、`take_hit` の後に `active == false` で判定する
- スキルのデータ：`slash`（近接）、`frost_bloom`（冷気の範囲）、`fire_bolt`（火の飛び道具）、`shatter`（チェイン技・近接）。補助：`scatter`（飛び道具が散る）、`burst_on_kill`（撃破時爆発）。チェイン：`frost_bloom` → `slash` で `shatter`
- 入力：`skill_1`（左クリック）、`skill_2`（右クリック）、`skill_3〜6`（Q/E/R/F）は `input_setup.gd` に登録済み
- 斜め視点の距離・向きは `Iso.ground_distance()` / `Iso.in_ground_arc()` / `Facing`

## やること
1. **スキル枠**：`scripts/skills/skill_loadout.gd`（`class_name SkillLoadout`）を新設。枠の番号（1〜6）ごとに「スキルid」と「補助ジェムid（0〜1個）」を持つ。初期状態は 枠1=`slash`、枠2=`frost_bloom`、枠3=`fire_bolt`（補助なし）。実行時にあとから付け替えられるメソッドを用意する（装備画面T11が使う）
2. **実行本体**：`scripts/skills/skill_caster.gd`（`class_name SkillCaster`）を新設。入力は「どの枠・狙う位置・発動者の位置」。出力は当てた敵の数など。流れは次のとおり
   1. 枠のスキルを取り出し、`ChainTracker.on_cast` でチェイン技に変わるか判定
   2. 補助ジェムの `modifiers` を反映（下の表）。チェイン技のときは `chain_damage_mult` / `chain_area_mult` も反映
   3. 再使用時間（`cooldown × cooldown_mult`）を枠ごとに管理
   4. `kind` ごとに当てる
      - `melee`：狙った方向の扇形（既存の `try_basic_attack` と同じ当て方）
      - `area`：発動者の足元を中心とする円（`radius × area_mult`）
      - `projectile`：狙った方向へ飛ぶ弾を `projectile_count` ぶん出す（複数のときは扇状に等間隔）。弾は `speed`、`range` まで進み、敵に当たったら1体にダメージを与えて消える。`hop_count` があれば、当たった後に近くの敵へ伝わる。弾は**プール化**して使い回す（毎回 new しない）
   5. ダメージ：`roll_damage` → `DamageCalc.skill_damage` → `damage_mult` の順。敵への耐性・防御の反映は今回はしない（敵にその項目がない）
   6. 撃破時爆発（`explode_on_kill` / `explode_damage_ratio`）：倒した敵のその場で、確率で爆発させる。爆発のダメージは「倒した敵の最大ライフ × 割合」、範囲は固定の半径（定数ではなく、補助ジェムの `modifiers` に半径が無ければ 24 ドット相当を `scripts/combat/` の定数にまとめる）。**爆発で倒れた敵がさらに爆発する連鎖は、打ち止めなしにする**（ユーザー決定）。無限ループにならないよう、爆発の処理は再帰ではなく待ち行列で順に処理する
3. **プレイヤーとの接続**：`player.gd` を、`skill_1`〜`skill_6` の入力で `SkillCaster` を呼ぶ形に書き換える。いまの `try_basic_attack` は `SkillCaster` を使う形に置き換えてよい（`attacked` 信号は残し、互換性を保つ）。チェイン技が出たときの見た目は `SlashFx` を流用してよい（絵は仮）
4. **見た目（仮でよい）**：範囲スキルの円と飛び道具の弾は、`_draw` の仮の絵でよい。爆発も円がぱっと広がる程度でよい。作り込まない（演出は T18）
5. **テスト**：`tests/test_skills.gd` を新設（`test_` で始まる関数を書くだけで実行される）。チェインが出る/出ない、補助ジェムの効果（飛び道具の数、ダメージ倍率）、撃破時爆発の連鎖（敵を並べて、連鎖で全滅すること、無限ループにならないこと）、再使用時間、弾のプール再利用

## 仕様（企画書・data_schema から）
- 補助ジェム：スキル枠の横の補助枠にはめると、そのスキルだけ性能が変わる（拡散、撃破時爆発など）。`kinds` が空でなければ、その種類のスキルにだけ付けられる
- スキルチェイン：受付時間は無制限。直前に使った1スキルだけを見る。間に別のスキルを挟むと無効。2段階まで（チェイン技の後は数え直し）。特定スキル指定が優先。実装は `chain_tracker.gd`（すでにある）
- 補助ジェムの `modifiers`（使えるキーはこれだけ）：`damage_mult`（ダメージ倍率）、`area_mult`（範囲の倍率）、`cooldown_mult`（再使用時間の倍率）、`projectile_count`（飛び道具の追加数）、`hop_count`（当たった後に近くの敵へ伝わる回数）、`explode_on_kill`（倒した敵が爆発する確率 0〜1）、`explode_damage_ratio`（爆発のダメージ＝倒した敵の最大ライフに対する割合）、`chain_damage_mult`、`chain_area_mult`
- 数値は `data/` の JSON が正。コードに直接書かない。コードに残してよい数値は、`scripts/combat/` に名前を付けた定数としてまとめたものだけ
- 敵は物理演算を使わない。弾・爆発・エフェクトは大量に出るので、プール化前提

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0（既存のテストも通ること）
- 次の手順で動作を確認できる：メイン画面で、左クリック（斬撃）→ 右クリックの氷華（敵に当てる）→ すぐ左クリックで「砕氷」が出る。Q（火球）を押すと弾が飛ぶ。補助ジェムを付けた状態を、テストまたは `tools/capture/capture.gd` の画面で確かめる
- 見た目が変わるので、`godot --script res://tools/capture/capture.gd -- --out=shots/T10.png` で撮った画面を最後の報告に添える

## やらないこと
- スキル装備画面（T11）、ドロップからジェムを手に入れる処理（T14 の結果を使う話は後）
- ヒットストップ・ダメージ数字・画面揺れ（T18）
- 敵の体力バーや敵の攻撃・プレイヤーの体力（T08 と別）
- `scripts/enemies/` の変更（T08 が触る）。敵が倒れたかは `active` で判定する
- 新しい補助ジェムやスキルのデータ追加（既存のものだけで動かす）
