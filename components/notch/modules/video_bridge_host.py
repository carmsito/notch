#!/usr/bin/env python3
import json
import os
import struct
import sys
import time

STATE_PATH = "/home/emmanuel/.local/state/quickshell/video_island_payload.json"


def ensure_dir(path):
    folder = os.path.dirname(path)
    if folder and not os.path.exists(folder):
        os.makedirs(folder, exist_ok=True)


def write_payload(payload):
    ensure_dir(STATE_PATH)
    payload.setdefault("ts", int(time.time() * 1000))
    with open(STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f)


def read_message():
    raw_len = sys.stdin.buffer.read(4)
    if not raw_len:
        return None
    msg_len = struct.unpack("<I", raw_len)[0]
    if msg_len == 0:
        return None
    data = sys.stdin.buffer.read(msg_len)
    if not data:
        return None
    try:
        return json.loads(data.decode("utf-8"))
    except Exception:
        return None


def send_message(payload):
    raw = json.dumps(payload).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(raw)))
    sys.stdout.buffer.write(raw)
    sys.stdout.buffer.flush()


def main():
    while True:
        msg = read_message()
        if msg is None:
            break
        if isinstance(msg, dict):
            write_payload(msg)
            send_message({"ok": True})
        else:
            send_message({"ok": False, "error": "invalid"})


if __name__ == "__main__":
    main()
