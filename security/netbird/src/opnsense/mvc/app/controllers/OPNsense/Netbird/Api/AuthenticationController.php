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

/**
 * netbird authentication controller
 * @package OPNsense\Netbird
 */
class AuthenticationController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'authentication';
    protected static $internalModelClass = '\OPNsense\Netbird\Authentication';

    public function upAction(): array
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed'];
        }
        $this->throwReadOnly();

        $backend = new Backend();
        $usedKey = (string)(Config::getInstance()->object()->OPNsense->netbird->authentication->setupKey ?? '');

        $status = json_decode((string)$backend->configdRun('netbird status-json'), true);
        if (json_last_error() === JSON_ERROR_NONE && ($status['management']['connected'] ?? false) === true) {
            /* registering with a new setup key requires a fresh login */
            $backend->configdRun('netbird down');
        }

        $raw = trim((string)$backend->configdRun('netbird up-setup-key'));
        $up = json_decode($raw, true);
        if (is_array($up) && array_key_exists('ok', $up)) {
            $upOk = $up['ok'] === true;
            $result = trim((string)($up['output'] ?? ''));
        } else {
            $upOk = false;
            $result = $raw;
        }

        $status = json_decode((string)$backend->configdRun('netbird status-json'), true);
        $connected = $upOk &&
            json_last_error() === JSON_ERROR_NONE &&
            ($status['management']['connected'] ?? false) === true;

        if ($connected && $usedKey !== '') {
            /* the setup key is not needed anymore once the peer is registered */
            $config = Config::getInstance();
            $config->lock();
            try {
                $cfg = $config->object();
                if ((string)($cfg->OPNsense->netbird->authentication->setupKey ?? '') === $usedKey) {
                    $cfg->OPNsense->netbird->authentication->setupKey = '';
                    $config->save();
                }
            } finally {
                $config->unlock();
            }
        }

        return [
            'result' => $result,
            'connected' => $connected,
        ];
    }

    public function downAction(): array
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed'];
        }
        $this->throwReadOnly();

        $backend = new Backend();

        $status = json_decode((string)$backend->configdRun('netbird status-json'), true);
        $connected = json_last_error() === JSON_ERROR_NONE && ($status['management']['connected'] ?? false) === true;

        if ($connected) {
            $raw = trim((string)$backend->configdRun('netbird down'));
            return [
                'result' => $raw === 'OK' ? '' : $raw,
                'disconnected' => $raw === 'OK',
            ];
        }
        return [
            'result' => 'already disconnected or not running',
            'disconnected' => true,
        ];
    }
}
