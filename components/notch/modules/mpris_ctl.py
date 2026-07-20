#!/usr/bin/env python3
import argparse
import dbus
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--player", required=True)
    parser.add_argument("--action", required=True, choices=["playpause", "play", "pause", "seek", "setpos"])
    parser.add_argument("--offset", type=float, default=0.0)
    parser.add_argument("--position", type=float, default=0.0)
    parser.add_argument("--track", default="")
    args = parser.parse_args()

    bus = dbus.SessionBus()
    obj = bus.get_object(args.player, "/org/mpris/MediaPlayer2")
    player = dbus.Interface(obj, "org.mpris.MediaPlayer2.Player")

    if args.action == "playpause":
        player.PlayPause()
    elif args.action == "play":
        player.Play()
    elif args.action == "pause":
        player.Pause()
    elif args.action == "seek":
        player.Seek(int(args.offset * 1_000_000))
    elif args.action == "setpos":
        if not args.track:
            sys.exit(1)
        player.SetPosition(dbus.ObjectPath(args.track), int(args.position * 1_000_000))


if __name__ == "__main__":
    main()
