#!/bin/sh

/*
 * Copyright (C) 2026 Konstantinos Spartalis <cspartalis@potatonetworks.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

# Helper script for Netbird plugin to handle Unbound restarts upon interface status change.
# Since Netbird creates a virtual/volatile interface 'wt0' that Unbound needs to listen on,
# Unbound must be restarted/reloaded once wt0 gets an IP address.

trigger_unbound_restart() {
    # Run in background to avoid blocking the main service command
    (
        i=1
        while [ $i -le 45 ]; do
            if ifconfig wt0 2>/dev/null | grep -q 'inet'; then
                sleep 2
                /usr/local/sbin/configctl unbound restart
                break
            fi
            sleep 1
            i=$((i + 1))
        done
    ) >/dev/null 2>&1 &
}

case "$1" in
    start)
        /usr/local/etc/rc.d/netbird start
        trigger_unbound_restart
        ;;
    restart)
        /usr/local/etc/rc.d/netbird restart
        trigger_unbound_restart
        ;;
    up)
        /usr/local/bin/netbird up
        trigger_unbound_restart
        ;;
    up-setup-key)
        shift
        /usr/local/bin/netbird up "$@"
        trigger_unbound_restart
        ;;
    *)
        echo "Usage: $0 {start|restart|up|up-setup-key}"
        exit 1
        ;;
esac
