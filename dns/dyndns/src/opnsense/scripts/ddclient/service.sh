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
	_result=0
	for HOOK in ${BACKENDS}/*.sh; do
		if [ -f "${HOOK}" ]; then
			/bin/sh "${HOOK}" "${1}" || _result=1
		fi
	done
	return ${_result}
}

RESULT=0

case "${1}" in
start)
	/usr/local/etc/rc.d/ddclient_opn start || RESULT=1
	backend_hooks start || RESULT=1
	;;
stop)
	/usr/local/etc/rc.d/ddclient_opn onestop 2> /dev/null
	backend_hooks stop || RESULT=1
	# a ddclient daemon may be left behind when os-ddclient was removed
	PIDFILE=/var/run/ddclient.pid
	if [ -f "${PIDFILE}" ]; then
		PID=$(cat "${PIDFILE}" 2> /dev/null)
		if [ -n "${PID}" ] && kill -0 "${PID}" 2> /dev/null; then
			kill -TERM "${PID}" 2> /dev/null
			for _ in $(jot 30 2> /dev/null || seq 1 30); do
				if ! kill -0 "${PID}" 2> /dev/null; then
					break
				fi
				sleep 1
			done
			if kill -0 "${PID}" 2> /dev/null; then
				RESULT=1
			fi
		fi
		if [ "${RESULT}" -eq 0 ]; then
			rm -f "${PIDFILE}"
		fi
	fi
	;;
restart)
	"${0}" stop || exit $?
	"${0}" start || RESULT=1
	;;
force)
	rm -f /var/tmp/ddclient_opn.status
	/usr/local/etc/rc.d/ddclient_opn restart 2> /dev/null || RESULT=1
	backend_hooks force || RESULT=1
	;;
*)
	echo "Usage: ${0} start|stop|restart|force" >&2
	exit 1
	;;
esac

exit ${RESULT}
