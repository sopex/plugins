ddclient_enable="YES"
ddclient_setup="/usr/local/opnsense/scripts/ddclient/setup.sh"
ddclient_flags="-daemon {{OPNsense.DynDNS.general.daemon_delay|default('300')}}"
