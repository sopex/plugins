#!/bin/sh

for CONF in /usr/local/etc/ddclient.conf /usr/local/etc/ddclient.json; do
	if [ -f ${CONF} ]; then
		chmod 0600 ${CONF}
	fi
done
