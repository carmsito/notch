#!/usr/bin/env python3
import dbus
import dbus.mainloop.glib
import json
import sys
import time

try:
    from gi.repository import GLib
except Exception:
    GLib = None


def emit(payload):
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def on_notify(app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout):
    payload = {
        "type": "notify",
        "id": int(replaces_id) if replaces_id else int(time.time() * 1000),
        "appName": str(app_name),
        "title": str(summary),
        "body": str(body),
        "timestamp": int(time.time() * 1000),
    }
    emit(payload)


def on_closed(notification_id, reason):
    payload = {
        "type": "close",
        "id": int(notification_id),
    }
    emit(payload)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()

    bus.add_signal_receiver(
        on_notify,
        dbus_interface="org.freedesktop.Notifications",
        signal_name="Notify",
    )

    bus.add_signal_receiver(
        on_closed,
        dbus_interface="org.freedesktop.Notifications",
        signal_name="NotificationClosed",
    )

    if GLib is None:
        # Fallback: keep process alive without GLib
        while True:
            time.sleep(1)
    else:
        loop = GLib.MainLoop()
        loop.run()


if __name__ == "__main__":
    main()
