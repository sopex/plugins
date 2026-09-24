#!/bin/sh

# Copyright (C) 2026 Deciso B.V.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Service control for all dynamic DNS backends. The rc.conf.d files generated
# from the templates decide which backend actually runs, additional backends
# (os-ddclient) hook in via backends/*.sh.

BACKENDS=/usr/local/opnsense/scripts/ddclient/backends

backend_hooks()
{
	for HOOK in ${BACKENDS}/*.sh; do
		if [ -f "${HOOK}" ]; then
			/bin/sh "${HOOK}" "${1}"
		fi
	done
}

case "${1}" in
start)
	/usr/local/etc/rc.d/ddclient_opn start
	backend_hooks start
	;;
stop)
	/usr/local/etc/rc.d/ddclient_opn onestop 2> /dev/null
	backend_hooks stop
	# a ddclient daemon may be left behind when os-ddclient was removed
	pkill -F /var/run/ddclient.pid 2> /dev/null
	;;
restart)
	${0} stop
	${0} start
	;;
force)
	rm -f /var/tmp/ddclient_opn.status
	/usr/local/etc/rc.d/ddclient_opn restart 2> /dev/null
	backend_hooks force
	;;
*)
	echo "Usage: ${0} start|stop|restart|force" >&2
	exit 1
	;;
esac

exit 0
