# autoAP
Simplified Automatic Access Point for Raspberry Pi if no connected WiFi

## Overview

autoAP provides a simple mechanism for turning a Raspberry Pi into an Access Point if the Pi is unable to connect to it's defined WiFi network. autoAP is simple to install and super-lightweight, requiring only one additional process.

autoAP is not intended to replace hostapd. If your use case needs a full-function Access Point, you want hostapd. A typical use case for autoAP would be for a Pi that you're taking outside of your known WiFi networks, and want to connect to it from another device in order to configure it, use it for demonstration purposes, etc.

autoAP was initially created by [jake](https://raspberrypi.stackexchange.com/users/92303/jake) and posted in the article [Automatically Create Hotspot if no Network is Available](https://raspberrypi.stackexchange.com/questions/100195/automatically-create-hotspot-if-no-network-is-available). autoAP is built on the original idea, but with code improvements and an easy-to-use installer.

There are other tools, such as [wifi-connect](https://github.com/balena-io/wifi-connect). My take is that wifi-connect is a more heavyweight solution with correspondingly more features.

autoAP, on the other hand, is super-lightweight, and can install on Raspbian Full or Raspbian Lite and does not require any additional software to be installed.

## Requirements

autoAP has minimal system requirements, but they are important:

* autoAP has been tested only on Raspbian Buster. It *should* run on Stretch, but that remains to be verified.
* autoAP requires use of systemd-networkd for network configuration. The provided script (rpi-networkconfig) can be used to reconfigure networking to use systemd-networkd.

## Installation

Download install-autoAP, autoAP.sh, and rpi-networkconfig to /usr/local/bin on your Pi, and run install-autoAP:

Download/install directions:

* `sudo curl -L https://github.com/gitbls/autoAP/raw/master/autoAP.sh -o /usr/local/bin/autoAP.sh`
* `sudo curl -L https://github.com/gitbls/autoAP/raw/master/install-autoAP -o /usr/local/bin/install-autoAP`
* `sudo curl -L https://github.com/gitbls/autoAP/raw/master/rpi-networkconfig -o /usr/local/bin/rpi-networkconfig`
* `sudo chmod 755 /usr/local/bin/autoAP.sh /usr/local/bin/install-autoAP /usr/local/bin/rpi-networkconfig`
* `sudo /usr/local/bin/install-autoAP`

install-autoAP will configure your system for autoAP. The detailed steps are described here for your convenience and reference.

* Check to see if systemd-networkd is enabled. If not, you can complete install-autoAP and then use rpi-networkconfig to reconfigure the network afterwards
* Prompt for the SSID and password for Access Point mode
* Try to get your current WiFi configuration from /etc/wpa_supplicant/wpa_supplicant.conf or /etc/wpa_supplicant/wpa_supplicant-wlan0.conf if one or the other is available. If they are not available, install-autoAP will prompt for the following information:
    * WiFi Country
    * Your WiFi SSID
    * Your WiFi Password
* If /etc/wpa_supplicant/wpa_supplicant.conf exists, it will be renamed to /etc/wpa_supplicant/wpa_supplicant.conf-orig, to avoid confusion
* Similarly, if wpa_supplicant.conf does not exist, but wpa_supplicant-wlan0.conf does, it will be renamed to /etc/wpa_supplicant/wpa_supplicant-wlan0.conf-orig
* Write the file /etc/wpa_supplicant/wpa_supplicant-wlan0.conf with the gathered information, defining both your WiFi network and the Access Point mode SSID and Password
* *All double quotes will be removed from SSIDs and passwords*, so don't use a double quote in a password or SSID name. If you do, you'll need to manually edit /etc/wpa_supplicant/wpa_supplicant-wlan0.conf to correct the entry.
* install-autoAP will create:
    * **/etc/systemd/network/11-wlan0.network** and **12-wlan0AP.network**. These are the network configuration files used by systemd-networkd for your wireless network.
    * **/etc/systemd/system/wpa-autoap@wlan0.service**, which is the service definition for the process that monitors the WiFi status and switches from Access Point mode to Client mode (and back) as appropriate.
    * **/usr/local/bin/autoap-local.sh**, which is a skeleton file that you can modify to call your scripts or programs that are interested in WiFi mode changes. For instance, if you want to start a program when the Pi enters Access Point mode (and stop when it enters Client mode), you would add the appropriate start and stop commands in the fairly obvious places
    * **/usr/local/bin/autoAP.conf**, which has the autoAP monitor configuration information. The parameters are:
        * **enablewait** (defaults to 300 seconds, or 5 minutes): This is the amount of time that autoAP will wait before it tries to connect to your WiFi again after Access Point mode is started. You might want this to be longer if you want the Access Point to remain active for a long period of time or shorter if you only need it briefly. **NOTE:**If the enablewait time is on the short side, your system log will grow more quickly.
        * **disconnectwait** (defaults to 20 seconds): This is the amount of time that autoAP will wait after the last client disconnects from the Access Point before it tries to reconnect to your WiFi. You might want this to be longer if you expect to disconnect and reconnect to your autoAP access point frequently over longer time spans.
        * **debug** (defaults to 0 [on]): If debug is set to 0 [on], autoAP will log some additional information to the system log for troubleshooting. Set this to 1 to disable the additional logging.

As a last step, install-autoAP will remind you to switch to systemd-networkd if it is not currently running on the Pi.

`sudo /usr/local/bin/rpi-networkconfig` will make the appropriate network software configuration changes to enable your selected network "machinery". rpi-networkconfig can switch between dhcpcd, systemd-networkd, and NetworkManager, although configuration files are only created for systemd-networkd. rpi-networkconfig will not overwrite the configuration written by install-autoAP. rpi-networkconfig will create /etc/systemd/system/10-eth0.network for your Ethernet device, and it will be set for DHCP operation. 

In summary, the network configuration files for systemd-networkd in **/etc/systemd/network**:

* **10-eth0.network** &mdash; Defines the network for the Ethernet device
* **11-wlan0.network** &mdash; Defines the network for the WiFi device in normal mode
* **12-wlan0AP.network** &mdash; Defines the network for the WiFi device in Access Point mode

And the systemd services installed are in **/etc/systemd/system**:

* **wpa-autoap@wlan0 .service** &mdash; The main service for autoAP
* **wpa-autoap-restore.service** &mdash; Restores the network configuration as needed when the system is restarted

If you made it this far, it's time to reboot!

## Operation

### Usage
If you are planning to use autoAP, make sure that wpa-autoap@wlan0 service is enabled. If you aren't planning to use autoAP, you can (but don't need to, as it's very lightweight) simply disable wpa-autoap@wlan0 and the network will behave normally. 

To enable: 

* `sudo systemctl enable wpa-autoap@wlan0` and then restart the system

To disable:

* `sudo systemctl disable wpa-autoap@wlan0`

**NOTE: **Do not disable the wpa-autoap-restore service. It is needed to re-enable the standard WiFi connection. See /usr/local/bin/install-autoap for details.


### Detailed Operational Description

The system startup will proceed normally. The wpa-autoap@wlan0 service is bound to the service wpa_supplicant@wlan0, so systemd will start it automatically if it's enabled. wpa_supplicant@wlan0 is running the same old wpa_supplicant, so it will process WiFi connects, disconnects, etc, just as before. 

If wpa_supplicant times out trying to connect to your WiFi (for instance, if the Pi is not at home or your router/access point is down), it will then look at the next defined network (the autoap Access Point network), which changes the wpa_supplicant mode to AP. A message is sent to wpa-autoap (wpa_cli), which calls /usr/local/bin/autoAP.sh with the network name and the event AP-ENABLED. autoAP will reconfigure the network to Access Point mode, restart systemd-networkd, and call /usr/local/bin/autoap-local.sh to do any additional desired processing.

When the last client disconnects from the Access Point, autoAP will wait **disconnectwait** time units before reverting to WiFi scanning mode, looking for your WiFi network. If your WiFi network is not found, it will restart Access Point mode.

Similarly, when the Access Point is started, it will wait **enablewait** time units before reverting to WiFi scanning mode.

## Troubleshooting

The first step in tracking down problems is to examine the system journal (journalctl) for error information. You can also enable debugging, which will output additional status information to the system journal. You enable debugging by sudo editing /usr/local/bin/autoAP.conf and changing debug=1 to debug=0. The debug logging will start the next time wpa_supplicant notices a wireless transition or the autoAP reconfigure timer expires. The command **sudo journalctl | egrep -i 'wpa|autoAP'** may be helpful in seeing the chain of events.
## Known Issues

* If wpa-autoap@wlan0 is enabled at system startup, it may fail to start the first or second time due to what appears to be a startup race condition between it and wpa_supplicant@wlan0. It's completely harmless since the service automatically restarts on failure, but for those of you who look through logs, you may see this.
* ???

## Futures

In no particular order, things I'm thinking about for autoAP:

* Lightweight web page for additional configuration while in Access Point mode
* Improved wpa_supplicant network profile support. Currently only a single WiFi network configuration (e.g., your Home network) is supported by the installer, in addition to the Access Point. You can, however, add additional WiFi network configurations to /etc/wpa_supplicant/wpa_supplicant-wlan0.conf after installing autoAP.
* Integration with dhcpcd and/or Network Manager
* Your suggestions?

## Final Thoughts

This is the first release. It has been well-tested by me, but has not been exposed to the variety of devices, different usage models, and users in the world. If you run into any problems, please post them on this GitHub, and I'll work with you to resolve them.
