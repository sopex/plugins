<?php

/*
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

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;

/**
 * Class ServiceController
 * @package OPNsense\Netbird
 */
class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\OPNsense\Netbird\Settings';
    protected static $internalServiceEnabled = 'general.enable';
    protected static $internalServiceTemplate = 'OPNsense/Netbird';
    protected static $internalServiceName = 'netbird';

    protected function invokeInterfaceRegistration()
    {
        return true;
    }

    public function reconfigureAction()
    {
        $unboundConf = '/usr/local/etc/unbound.opnsense.d/netbird.conf';
        $beforeHash = is_file($unboundConf) ? md5_file($unboundConf) : '';

        $model = $this->getModel();
        $enabled = (string)$model->general->enable === '1';
        $unboundForward = (string)$model->dns->unboundForward === '1';
        $preRestartResolver = ($this->request->isPost() && $enabled && $unboundForward)
            ? $model->detectDnsResolver()
            : '';

        $result = parent::reconfigureAction();

        if ($this->request->isPost()) {
            $backend = new Backend();

            if ($enabled && $unboundForward) {
                $detectedResolver = '';
                for ($i = 0; $i < 35; $i++) {
                    usleep(200000);
                    $detectedResolver = $model->detectDnsResolver();
                    if ($detectedResolver !== '') {
                        break;
                    }
                }
                if ($detectedResolver === '') {
                    $detectedResolver = $preRestartResolver !== ''
                        ? $preRestartResolver
                        : $model->detectDnsResolver('', true);
                }
                if ($detectedResolver !== '' && $model->shouldAutoUpdateDnsResolver($detectedResolver)) {
                    $model->dns->customAddress = $detectedResolver;
                    $model->serializeToConfig();
                    Config::getInstance()->save();
                    $model->syncConfig();
                    $backend->configdpRun('template reload', [static::$internalServiceTemplate]);
                }
            }

            clearstatcache(true, $unboundConf);
            $afterHash = is_file($unboundConf) ? md5_file($unboundConf) : '';
            if ($beforeHash !== $afterHash) {
                $backend->configdRun('unbound restart');
            }
        }

        return $result;
    }
}
