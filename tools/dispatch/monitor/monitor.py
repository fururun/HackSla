#!/usr/bin/env python3
"""
monitor.py — AI外注管理ボード（監視サーバー）

各AIを「外注先の会社」に見立てて、発注から納品・検収・完了までの流れと、
いまの作業状況をブラウザで見られるようにします。Pythonの標準機能だけで動きます。

使い方（ゲームのリポジトリの中で）:
    python3 tools/dispatch/monitor/monitor.py            # http://localhost:8765 を開く
    python3 tools/dispatch/monitor/monitor.py --port 9000
    python3 tools/dispatch/monitor/monitor.py --lan      # 同じWi-Fiのスマホから見る

読むもの（書き換えはしません）:
    .dispatch/events.jsonl   … dispatch.sh / review.sh / cleanup.sh が残す取引記録
    .dispatch/logs/          … 各タスクの作業ログと発注書（プロンプト）
    tasks/*.md               … まだ発注していない指示書（発注準備）
    git のブランチ            … マージ済みかどうか
"""
import argparse
import glob
import http.server
import json
import os
import re
import socket
import subprocess
import sys
import time
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
KIT_DIR = os.path.dirname(HERE)

COMPANIES = {
    "claude": {"name": "Claude社", "role": "設計・統括・レビュー"},
    "codex": {"name": "Codex社", "role": "実装（並列の主力）"},
    "gemini": {"name": "Gemini社", "role": "数値設計・調査・検証"},
    "muse": {"name": "Muse社", "role": "ツール・小さな実装"},
}

# 発注フローの段階（ボードの列）
STAGES = {
    "draft": "発注準備",
    "ordered": "発注済み",
    "working": "作業中",
    "delivered": "検収待ち",
    "accepted": "検収OK",
    "rejected": "差し戻し",
    "failed": "失敗",
    "no_change": "納品物なし",
    "done": "完了",
}

ID_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


def git(root, *args):
    try:
        return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return ""


def read_conf_base(root):
    path = os.path.join(KIT_DIR, "agents.conf")
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = re.match(r'^\s*BASE_BRANCH="?([^"\s]*)"?', line)
                if m and m.group(1):
                    return m.group(1)
    except OSError:
        pass
    return git(root, "symbolic-ref", "--short", "HEAD").strip() or "main"


def front_matter(path):
    data = {}
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return data
    if not lines or lines[0].strip() != "---":
        return data
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" in line:
            k, v = line.split(":", 1)
            data[k.strip()] = v.strip()
    return data


def read_events(root):
    events = []
    path = os.path.join(root, ".dispatch", "events.jsonl")
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                    ev["ts"] = int(ev.get("ts", 0))
                    events.append(ev)
                except (ValueError, TypeError):
                    continue
    except OSError:
        pass
    events.sort(key=lambda e: e["ts"])
    return events


def log_tail(root, task_id, n):
    path = os.path.join(root, ".dispatch", "logs", f"{task_id}.log")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = [l.rstrip("\n") for l in f.readlines()]
        return [l for l in lines if l.strip()][-n:]
    except OSError:
        return []


def ja_changed(s):
    """'3 files changed, 12 insertions(+), 2 deletions(-)' → '3ファイル・12行追加・2行削除'"""
    if not s or s == "なし":
        return s
    parts = []
    for num, word in re.findall(r"(\d+) (file|insertion|deletion)", s):
        parts.append(num + {"file": "ファイル", "insertion": "行追加", "deletion": "行削除"}[word])
    return "・".join(parts) or s


def build_state(root):
    now = int(time.time())
    base = read_conf_base(root)
    events = read_events(root)
    merged = set(b.strip() for b in git(root, "branch", "--merged", base, "--format=%(refname:short)").splitlines())
    existing = set(b.strip() for b in git(root, "branch", "--format=%(refname:short)").splitlines())

    tasks = {}

    def task(tid):
        if tid not in tasks:
            tasks[tid] = {
                "id": tid, "agent": "", "title": "", "stage": "draft", "allowed": "",
                "ordered_at": None, "started_at": None, "finished_at": None,
                "secs": None, "rc": None, "changed": "", "pr": "", "note": "",
                "rejects": 0, "runs": 0, "mock": False, "file": "", "tail": [],
            }
        return tasks[tid]

    # 発注準備：tasks/ にあるがまだ発注していない指示書
    for path in sorted(glob.glob(os.path.join(root, "tasks", "*.md"))):
        if os.path.basename(path).startswith("_"):
            continue
        fm = front_matter(path)
        tid = fm.get("id")
        if not tid:
            continue
        t = task(tid)
        t["agent"] = fm.get("agent", "").lower()
        t["title"] = fm.get("title", "")
        t["allowed"] = fm.get("allowed", "")
        t["file"] = os.path.relpath(path, root)

    # 取引記録を時系列で当てはめる
    for ev in events:
        tid = ev.get("id", "")
        if not tid:
            continue
        t = task(tid)
        kind = ev.get("event")
        if ev.get("agent") and ev["agent"] != "-":
            t["agent"] = ev["agent"]
        if kind == "ordered":
            t.update({
                "stage": "ordered", "ordered_at": ev["ts"], "started_at": None, "finished_at": None,
                "secs": None, "rc": None, "changed": "", "pr": "", "note": "",
                "title": ev.get("title") or t["title"], "allowed": ev.get("allowed") or t["allowed"],
                "mock": ev.get("mock") == "1", "file": ev.get("file") or t["file"],
            })
            t["runs"] += 1
        elif kind == "started":
            t["stage"] = "working"
            t["started_at"] = ev["ts"]
        elif kind == "finished":
            rc = int(ev.get("rc") or 0)
            t.update({"finished_at": ev["ts"], "rc": rc, "secs": int(ev.get("secs") or 0),
                      "changed": ev.get("changed", ""), "pr": ev.get("pr", "")})
            if rc != 0:
                t["stage"] = "failed"
            elif ev.get("changed") in ("", "なし"):
                t["stage"] = "no_change"
            else:
                t["stage"] = "delivered"
        elif kind == "accepted":
            t["stage"] = "accepted"
            t["note"] = ev.get("note", "")
        elif kind == "rejected":
            t["stage"] = "rejected"
            t["note"] = ev.get("note", "")
            t["rejects"] += 1
        elif kind == "closed":
            if t["stage"] in ("delivered", "accepted"):
                t["stage"] = "done"

    # gitの状態で補う：納品済みでブランチがマージされていたら完了
    for t in tasks.values():
        branch = f"task/{t['id']}"
        if t["stage"] in ("delivered", "accepted") and branch in existing and branch in merged:
            t["stage"] = "done"
        if t["stage"] == "working":
            t["elapsed"] = now - (t["started_at"] or now)
            t["tail"] = log_tail(root, t["id"], 3)
        t["stage_label"] = STAGES.get(t["stage"], t["stage"])
        t["changed_ja"] = ja_changed(t["changed"])
        t["company"] = COMPANIES.get(t["agent"], {"name": t["agent"] or "未定", "role": ""})["name"]

    # 会社ごとの成績
    companies = []
    for key, info in COMPANIES.items():
        mine = [t for t in tasks.values() if t["agent"] == key]
        finished = [ev for ev in events if ev.get("event") == "finished" and ev.get("agent") == key]
        ok = [ev for ev in finished if str(ev.get("rc")) == "0" and ev.get("changed") not in ("", "なし")]
        secs = [int(ev.get("secs") or 0) for ev in ok]
        rejects = sum(t["rejects"] for t in mine)
        working = [t for t in mine if t["stage"] in ("ordered", "working")]
        companies.append({
            "key": key, **info,
            "status": "作業中" if working else "待機中",
            "working": [t["id"] for t in working],
            "orders": sum(t["runs"] for t in mine),
            "delivered": len(ok),
            "failed": len([ev for ev in finished if str(ev.get("rc")) != "0"]),
            "rejected": rejects,
            "done": len([t for t in mine if t["stage"] == "done"]),
            "avg_secs": round(sum(secs) / len(secs)) if secs else None,
            "success_rate": max(0, round(100 * (len(ok) - rejects) / len(finished))) if finished else None,
        })

    # 取引履歴（新しい順）
    feed = []
    words = {"ordered": "を発注", "started": "が着手", "accepted": "を検収OK", "rejected": "を差し戻し", "closed": "が完了"}
    for ev in reversed(events[-60:]):
        tid = ev.get("id", "")
        t = tasks.get(tid, {})
        comp = COMPANIES.get(t.get("agent", ""), {}).get("name", "")
        kind = ev.get("event")
        if kind == "finished":
            if str(ev.get("rc")) != "0":
                text, tone = f"{comp}の{tid}が失敗（終了コード {ev.get('rc')}）", "bad"
            elif ev.get("changed") in ("", "なし"):
                text, tone = f"{comp}の{tid}は納品物なし", "warn"
            else:
                text, tone = f"{comp}が{tid}を納品（{ja_changed(ev.get('changed'))}）", "good"
        else:
            text = f"{tid}{words.get(kind, kind)}" if kind in ("ordered", "accepted", "rejected", "closed") else f"{comp}{words.get(kind, kind)}：{tid}"
            if kind == "ordered":
                text = f"{comp}に{tid}「{ev.get('title', '')}」を発注"
            if kind == "closed" and t.get("stage") != "done":
                text = f"{tid}の作業場所を片付け"
            if ev.get("note"):
                text += f"（{ev['note']}）"
            tone = {"rejected": "bad", "accepted": "good"}.get(kind, "info")
            if kind == "closed" and t.get("stage") == "done":
                tone = "good"
        feed.append({"t": ev.get("t", ""), "ts": ev["ts"], "text": text, "tone": tone, "id": tid})

    order = list(STAGES.keys())
    task_list = sorted(tasks.values(), key=lambda t: (order.index(t["stage"]) if t["stage"] in order else 99, t["id"]))
    return {
        "now": now,
        "repo": os.path.basename(root),
        "base": base,
        "stages": STAGES,
        "companies": companies,
        "tasks": task_list,
        "feed": feed[:30],
        "demo": False,
    }


def task_detail(root, tid):
    logs = os.path.join(root, ".dispatch", "logs")
    def read(path, limit=None):
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
            return text[-limit:] if limit else text
        except OSError:
            return ""
    prompt = read(os.path.join(logs, f"{tid}.prompt.md"))
    if not prompt:
        for path in glob.glob(os.path.join(root, "tasks", "*.md")):
            if front_matter(path).get("id") == tid:
                prompt = read(path)
                break
    return {"id": tid, "prompt": prompt, "log": read(os.path.join(logs, f"{tid}.log"), 20000)}


def make_handler(root):
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, code, body, ctype):
            data = body.encode("utf-8") if isinstance(body, str) else body
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path in ("/", "/index.html"):
                with open(os.path.join(HERE, "index.html"), encoding="utf-8") as f:
                    return self.send(200, f.read(), "text/html; charset=utf-8")
            if url.path == "/api/state":
                return self.send(200, json.dumps(build_state(root), ensure_ascii=False), "application/json; charset=utf-8")
            if url.path == "/api/task":
                tid = urllib.parse.parse_qs(url.query).get("id", [""])[0]
                if not ID_RE.match(tid):
                    return self.send(400, '{"error":"bad id"}', "application/json")
                return self.send(200, json.dumps(task_detail(root, tid), ensure_ascii=False), "application/json; charset=utf-8")
            self.send(404, "not found", "text/plain; charset=utf-8")
    return Handler


def main():
    ap = argparse.ArgumentParser(description="AI外注管理ボード")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--lan", action="store_true", help="同じネットワークの他の端末（スマホなど）から見られるようにする")
    ap.add_argument("--repo", default=".", help="ゲームのリポジトリの場所（省略時は今いる場所）")
    args = ap.parse_args()

    root = subprocess.run(["git", "-C", args.repo, "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    if not root:
        sys.exit("エラー: gitリポジトリの中で実行するか、--repo で場所を指定してください")

    host = "0.0.0.0" if args.lan else "127.0.0.1"
    server = http.server.ThreadingHTTPServer((host, args.port), make_handler(root))
    print(f"AI外注管理ボード: http://localhost:{args.port}  （対象: {root}）")
    if args.lan:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("10.255.255.255", 1))
            print(f"スマホから: http://{s.getsockname()[0]}:{args.port}  ※閲覧専用。信頼できるネットワークでのみ使ってください")
            s.close()
        except OSError:
            pass
    print("止めるときは Ctrl+C")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n終了しました")


if __name__ == "__main__":
    main()
