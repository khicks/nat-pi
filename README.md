# Raspberry Pi NAT Box

This is a simple script for setting up a Raspberry Pi 4
(Debian Buster) as a WiFi-tethered NAT box with WiFi as
WAN and Ethernet as LAN.

# Installation

From a default install of Debian Buster on RPi4, copy or clone the
project files to your Raspberry Pi and run `install.sh`.
You will be asked a few questions to set up a new local user
and connect to WiFi.

# Known issues and caveats

* Internet access is required for initial setup. You may be able
  to accomplish this using the same WiFi network you intend to
  tether from, but I only tested over Ethernet.
* You need local console access and ideally a display during initial
  setup. It cannot be done completely headlessly unless you enable
  SSH from the file system when initially flashing the OS image.
* The DHCP server is a bit finicky. After setup, have your LAN machine
  connected to the Raspberry Pi before powering the Raspberry Pi on.