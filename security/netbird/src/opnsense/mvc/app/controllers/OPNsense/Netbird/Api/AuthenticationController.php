<?php

/*
 * Copyright (C) 2025 Ralph Moser, PJ Monitoring GmbH
 * Copyright (C) 2025 squared GmbH
 * Copyright (C) 2025 Christopher Linn, BackendMedia IT-Services GmbH
 * Copyright (C) 2025 NetBird GmbH
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

namespace OPNsense\Netbird\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\Netbird\Authentication;
use OPNsense\Netbird\Settings;

/**
 * netbird authentication controller
 * @package OPNsense\Netbird
 */
class AuthenticationController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'authentication';
    protected static $internalModelClass = '\OPNsense\Netbird\Authentication';

    public function getAction(): array
    {
        $mdl = new Authentication();

        return [
            'authentication' => [
                'managementUrl' => $mdl->managementUrl->getValue(),
                'setupKey' => '',
            ]
        ];
    }

    public function upAction(): array
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed'];
        }
        $this->throwReadOnly();

        $backend = new Backend();

        $status = json_decode($backend->configdRun("netbird status-json"), true);
        $connected = $status['management']['connected'] ?? false;

        if (json_last_error() === JSON_ERROR_NONE && $connected === true) {
            $backend->configdRun("netbird down");
        }

        $result = trim((string)$backend->configdRun('netbird up-setup-key'));

        $status = json_decode($backend->configdRun("netbird status-json"), true);
        $connected = $status['management']['connected'] ?? false;
        if (json_last_error() === JSON_ERROR_NONE && $connected === true) {
            $cfg = Config::getInstance()->object();
            $cfgChanged = false;
            if (isset($cfg->OPNsense->netbird->authentication->setupKey) && (string)$cfg->OPNsense->netbird->authentication->setupKey !== '') {
                $cfg->OPNsense->netbird->authentication->setupKey = '';
                $cfgChanged = true;
            }

            $settings = new Settings();
            if ((string)$settings->dns->unboundForward === '1') {
                $netbirdIp = trim((string)($status['netbirdIp'] ?? ''));
                $detected = $netbirdIp !== '' ? $settings->detectDnsResolver($netbirdIp) : '';
                if ($detected === '') {
                    $detected = $settings->detectDnsResolver('', true);
                }
                if ($detected !== '' && $settings->shouldAutoUpdateDnsResolver($detected)) {
                    $unboundConf = '/usr/local/etc/unbound.opnsense.d/netbird.conf';
                    $beforeHash = is_file($unboundConf) ? md5_file($unboundConf) : '';
                    $settings->dns->customAddress = $detected;
                    $settings->serializeToConfig();
                    Config::getInstance()->save();
                    $cfgChanged = false;
                    $settings->syncConfig();
                    $backend->configdpRun('template reload', ['OPNsense/Netbird']);
                    clearstatcache(true, $unboundConf);
                    $afterHash = is_file($unboundConf) ? md5_file($unboundConf) : '';
                    if ($beforeHash !== $afterHash) {
                        $backend->configdRun('unbound restart');
                    }
                }
            }

            if ($cfgChanged) {
                Config::getInstance()->save();
            }
        }

        return [
            'result' => $result,
            'connected' => $connected === true,
        ];
    }

    public function downAction(): array
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed'];
        }
        $this->throwReadOnly();

        $backend = new Backend();

        $status = json_decode($backend->configdRun("netbird status-json"), true);
        $connected = $status['management']['connected'] ?? false;

        if (json_last_error() === JSON_ERROR_NONE && $connected === true) {
            $result = $backend->configdRun("netbird down");
            return ['result' => trim((string)$result)];
        }
        return ['result' => 'already disconnected or not running'];
    }
}
