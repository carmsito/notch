#!/usr/bin/env python3
import dbus
import dbus.mainloop.glib
from gi.repository import GLib
import sys

def device_found(address, properties):
    """Callback when a device is discovered"""
    name = properties.get('Name', 'Unknown')
    # Only print new devices (not already paired)
    if not properties.get('Paired', False):
        print(f"Device {address} {name}", flush=True)

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    
    bus = dbus.SystemBus()
    adapter = bus.get_object('org.bluez', '/org/bluez/hci0')
    adapter_iface = dbus.Interface(adapter, 'org.bluez.Adapter1')
    
    # Listen for new devices
    def interfaces_added(path, interfaces):
        if 'org.bluez.Device1' not in interfaces:
            return
        
        props = interfaces['org.bluez.Device1']
        address = props.get('Address', '')
        name = props.get('Name', '')
        paired = props.get('Paired', False)
        rssi = props.get('RSSI', -100)
        
        # Filtrer: ne garder que les appareils non appairés avec un vrai nom et un signal correct
        if not paired and name and name != address and rssi > -80:
            print(f"Device {address} {name}", flush=True)
    
    bus.add_signal_receiver(
        interfaces_added,
        dbus_interface='org.freedesktop.DBus.ObjectManager',
        signal_name='InterfacesAdded'
    )
    
    # Start discovery
    adapter_iface.StartDiscovery()
    
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        adapter_iface.StopDiscovery()

if __name__ == '__main__':
    main()
