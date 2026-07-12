{% if helpers.exists('OPNsense.MdnsBridge.general.enabled') and OPNsense.MdnsBridge.general.enabled == '1' %}
mdns_bridge_enable="YES"
mdns_bridge_config="/usr/local/etc/mdns-bridge.conf"
{% if helpers.exists('OPNsense.MdnsBridge.general.enablecarp') and OPNsense.MdnsBridge.general.enablecarp == '1' %}
required_files="/var/run/mdns-bridge.CARP_MASTER"
{% endif %}
{% else %}
mdns_bridge_enable="NO"
{% endif %}
