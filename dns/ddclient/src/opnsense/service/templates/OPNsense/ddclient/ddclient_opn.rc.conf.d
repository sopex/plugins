{% if not helpers.empty('OPNsense.DynDNS.general.enabled') and not helpers.file_exists('/usr/local/opnsense/version/ddclient') %}
ddclient_opn_enable="YES"
ddclient_opn_setup="/usr/local/opnsense/scripts/ddclient/setup.sh"
{% else %}
ddclient_opn_enable="NO"
{% endif %}
