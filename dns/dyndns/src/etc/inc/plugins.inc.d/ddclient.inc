<?php

/*
 * Copyright (C) 2022 Deciso B.V.
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


function ddclient_services()
{
    $services = [];
    $cnf = \OPNsense\Core\Config::getInstance()->object();
    $is_enabled = false;
    if ($cnf->OPNsense && $cnf->OPNsense->DynDNS && $cnf->OPNsense->DynDNS->general) {
        $is_enabled = $cnf->OPNsense->DynDNS->general->enabled == '1';
    }

    if ($is_enabled) {
        $backend = \OPNsense\DynDNS\DynDNS::backendInfo((string)$cnf->OPNsense->DynDNS->general->backend);
        $is_ddclient = $backend['effective'] == 'ddclient';
        $services[] = [
            'description' => $is_ddclient ? gettext('Dynamic DNS (ddclient)') : gettext('Dynamic DNS'),
            'configd' => [
                'restart' => ['ddclient restart'],
                'start' => ['ddclient start'],
                'stop' => ['ddclient stop'],
            ],
            'name' => 'ddclient',
            'pidfile' => $is_ddclient ? ($backend['descriptor']['pidfile'] ?? '/var/run/ddclient.pid') : '/var/run/ddclient_opn.pid',
        ];
    }

    return $services;
}

function ddclient_xmlrpc_sync()
{
    $result = [];

    $result[] = [
        'description' => gettext('Dynamic DNS'),
        'section' => 'OPNsense.DynDNS',
        'services' => ['ddclient'],
        'id' => 'ddclient',
    ];

    return $result;
}

function ddclient_syslog()
{
    $logfacilities = [];

    $logfacilities['ddclient'] = [
        'facility' => ['ddclient'],
    ];

    return $logfacilities;
}
