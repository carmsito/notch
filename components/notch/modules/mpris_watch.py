#!/usr/bin/env python3
import dbus
import json
import sys
import time


def _safe_str(value):
    try:
        return str(value)
    except Exception:
        return ""


def _safe_int(value):
    try:
        return int(value)
    except Exception:
        return 0


def _safe_list(value):
    try:
        return list(value)
    except Exception:
        return []


def _read_player(bus, name):
    obj = bus.get_object(name, "/org/mpris/MediaPlayer2")
    props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")

    status = _safe_str(props.Get("org.mpris.MediaPlayer2.Player", "PlaybackStatus"))
    metadata = props.Get("org.mpris.MediaPlayer2.Player", "Metadata")
    position = _safe_int(props.Get("org.mpris.MediaPlayer2.Player", "Position"))

    title = _safe_str(metadata.get("xesam:title", ""))
    artists = _safe_list(metadata.get("xesam:artist", []))
    artist = ", ".join([_safe_str(a) for a in artists]) if artists else ""
    length = _safe_int(metadata.get("mpris:length", 0))
    track_id = _safe_str(metadata.get("mpris:trackid", ""))
    url = _safe_str(metadata.get("xesam:url", ""))

    return {
        "name": name,
        "status": status,
        "title": title,
        "artist": artist,
        "position": position / 1_000_000.0,
        "length": length / 1_000_000.0,
        "trackId": track_id,
        "url": url,
    }


def main():
    bus = dbus.SessionBus()
    last_active = None

    while True:
        try:
            names = [n for n in bus.list_names() if n.startswith("org.mpris.MediaPlayer2.")]
        except Exception:
            names = []

        players = []
        for name in names:
            try:
                players.append(_read_player(bus, name))
            except Exception:
                continue

        active = None
        for player in players:
            if player.get("status") == "Playing":
                active = player
                break

        if not active and last_active:
            for player in players:
                if player.get("name") == last_active:
                    active = player
                    break

        if not active and players:
            active = players[0]

        if active:
            last_active = active.get("name")

        payload = {"players": players, "active": active or {}}
        sys.stdout.write(json.dumps(payload) + "\n")
        sys.stdout.flush()
        time.sleep(1)


if __name__ == "__main__":
    main()
