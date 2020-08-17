#!/bin/bash
#
# This script is run by wpa_cli (which runs as part of the wpa-autoap service) when the WiFi network state changes
# $1 has the interface name (EXCEPT for the unique case when it has "start")
# $2 has one of: AP-ENABLED, AP-DISABLED, CONNECTED, AP-STA-CONNECTED, AP-STA-DISCONNECTED, or DISCONNECTED
# $3 has a MAC address for (at least) AP-STA-CONNECTED and AP-STA-DISCONNECTED
#

device=$1

logmsg () {
    [ $debug -eq 0 ] && logger --id=$$ "$1"
}

logflags () {
    return       # Comment this out for flag logging when debug=0
    [ -f /var/run/autoAP.locked ] && s1="$(ls -l /var/run/autoAP.locked)" || s1="Not found"
    [ -f /var/run/autoAP.unlock ] && s2="$(ls -l /var/run/autoAP.unlock)" || s2="Not found"
    logmsg "autoAP: Lock status 1: $s1"
    logmsg "autoAP: Lock status 2: $s2"
}

is_client () {
    [ -e /etc/systemd/network/11-$device.network ] && return 0 || return 1
}

configure_ap () {
    if [ -e /etc/systemd/network/11-$device.network ]; then
	logmsg "autoAP: Configuring $device as an Access Point"
        mv /etc/systemd/network/11-$device.network /etc/systemd/network/11-$device.network~
        systemctl restart systemd-networkd
	[ -x /usr/local/bin/autoAP-local.sh ] && /usr/local/bin/autoAP-local.sh AccessPoint
    fi
}

configure_client () {
    if [ -e /etc/systemd/network/11-$device.network~ ]; then
	logmsg "autoAP: Configuring $device as a Wireless Client"
        mv /etc/systemd/network/11-$device.network~ /etc/systemd/network/11-$device.network
        systemctl restart systemd-networkd
	[ -x /usr/local/bin/autoAP-local.sh ] && /usr/local/bin/autoAP-local.sh Client
    fi
}

reconfigure_wpa_supplicant () {
# $1 has number of seconds to wait
    if [ -f /var/run/autoAP.locked ]
    then
	logmsg "autoAP: Reconfigure already locked. Unlocking..."
	touch /var/run/autoAP.unlock
	return
    else
	touch /var/run/autoAP.locked
	[ -f /var/run/autoAP.unlock ] && rm -f /var/run/autoAP.unlock
	logmsg "autoAP: Starting reconfigure wait loop"
	for ((i=0; i<=$1; i++)) do
	    sleep 1
	    if [ -f /var/run/autoAP.unlock ]
	    then
		logmsg "autoAP: Reconfigure wait unlocked"
		rm -f /var/run/autoAP.unlock
		rm -f /var/run/autoAP.locked
		logflags
		return
	    fi
	done
	# Completed loop, check for reconfigure
	rm -f /var/run/autoAP.unlock
	rm -f /var/run/autoAP.locked
	logmsg "autoAP: Checking wpa reconfigure after wait loop"
        if [ "$(wpa_cli -i $device all_sta)" = "" ]
	then
	    logmsg "autoAP: No stations connected; performing wpa reconfigure"
	    wpa_cli -i $device reconfigure
	fi
    fi
}
#
# Main code
#
if [ -f /usr/local/bin/autoAP.conf ]
then
    source /usr/local/bin/autoAP.conf
else
    enablewait="300"            # Seconds to wait in AP mode when AP enabled if no AP clients before wpa reconfigure
    disconnectwait="20"         # Seconds to wait in AP mode when a client disconnects before wpa reconfigure
    debug=0
fi
# Uncomment this if needed for debugging
#logger --id=$$ "autoAP enablewait=$enablewait | disconnectwait=$disconnectwait | debug=$debug"

#
# "start" called from wpa-autoAP@wlan0.service
# $1 = "start"
# $2 = device name (typically wlan0)
#
if [ "$1" == "start" ]
then
    [ -f /var/run/autoAP.locked ] && rm -f /var/run/autoAP.locked
    [ -f /var/run/autoAP.unlock ] && rm -f /var/run/autoAP.unlock
    [ -f /etc/systemd/network/11-wlan0.network~ ] && mv /etc/systemd/network/11-wlan0.network~ /etc/systemd/network/11-wlan0.network
    while [ ! -e /var/run/wpa_supplicant/$2 ]  # -e to test if in the namespace
    do
	logmsg "autoAP: Waiting for wpa_supplicant to come online"
	sleep 0.5
    done
    logmsg "autoAP: wpa_supplicant online, starting wpa_cli to monitor wpa_supplicant messages"
    exec /sbin/wpa_cli -i $2 -a /usr/local/bin/autoAP.sh 
    exit 0
fi
#
# For the rest of the operations:
#   $1 has the interface name
#   $2 has one of: AP-ENABLED, AP-DISABLED, CONNECTED, AP-STA-CONNECTED, AP-STA-DISCONNECTED, or DISCONNECTED
#   $3 has a MAC address for (at least) AP-STA-CONNECTED and AP-STA-DISCONNECTED
#
logmsg "autoAP $1 state $2 $3"  # Log incoming message 

case "$2" in

    # Configure access point if one is created
    AP-ENABLED)
	logflags
        configure_ap
        reconfigure_wpa_supplicant $enablewait &
        ;;

    # AP became disabled, configure as Client
    AP-DISABLED)
	logflags
	;;
    
    # Configure as client, if connected to some network
    CONNECTED)
	logflags
        if wpa_cli -i $device status | grep -q "mode=station"; then
	    logmsg "autoAP: CONNECTED in station mode, configuring client"
            configure_client
        fi
        ;;

    # Reconfigure wpa_supplicant to search for your wifi again if nobody is connected to the ap
    AP-STA-DISCONNECTED)
	logmsg "autoAP: Station $3 disconnected from autoAP"
	logflags
        reconfigure_wpa_supplicant $disconnectwait &
        ;;

    AP-STA-CONNECTED)
	logmsg "autoAP: Station $3 connected to autoAP"
	logflags
	touch /var/run/autoAP.unlock            # Cancel any waiting reconfigure since someone connected now
	;;

    DISCONNECTED)
	logflags
	if is_client
	then
	    logmsg "autoAP: Client disconnected, configuring as AP"
	    configure_ap
	fi
	;;

    *) # For debugging or curiosity
	logmsg "autoAP: Unrecognized state $2"
	;;
esac
exit 0
