{% from 'OPNsense/ddclient/backend.macro' import effective_backend %}
{% if not helpers.empty('OPNsense.DynDNS.general.enabled') and effective_backend() == 'ddclient' %}
{%   include 'OPNsense/ddclient/legacy/rc.conf.d' ignore missing %}
{% else %}
ddclient_enable="NO"
{% endif %}
