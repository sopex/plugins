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

namespace OPNsense\Netbird;

use OPNsense\Base\BaseModel;
use OPNsense\Core\Config;

class Settings extends BaseModel
{
    /* NetBird's built-in interface blacklist, needed because syncConfig() replaces the whole list */
    private const DEFAULT_IFACE_BLACKLIST = [
        'wt0',
        'wt',
        'utun',
        'tun0',
        'zt',
        'ZeroTier',
        'wg',
        'ts',
        'Tailscale',
        'tailscale',
        'docker',
        'veth',
        'br-',
        'lo',
    ];

    /**
     * Merge the plugin settings into NetBird's config.json. The file is created when missing,
     * NetBird fills in the remaining defaults (keys, management URL) on startup.
     */
    public function syncConfig($target = '/var/db/netbird/config.json')
    {
        $config = [];
        $raw = file_exists($target) ? trim((string)file_get_contents($target)) : '';
        if ($raw !== '') {
            $config = json_decode($raw, true);
            if (!is_array($config)) {
                syslog(LOG_ERR, 'netbird: failed to decode configuration: ' . json_last_error_msg());
                return;
            }
        }

        $wgPort = trim((string)$this->general->wireguardPort);
        $config['WgIface'] = (string)$this->general->interface ?: 'wt0';
        $config['WgPort'] = $wgPort === '' ? 51820 : (int)$wgPort;
        $config['MTU'] = (int)(string)$this->general->mtu ?: 1280;

        unset($config['IpMapping']); /* written by plugin versions before 1.4, unknown to NetBird */
        $config['NATExternalIPs'] = array_values(array_filter(explode(',', (string)$this->general->ipmapping)));

        $blacklist = array_merge(self::DEFAULT_IFACE_BLACKLIST, [$config['WgIface']]);
        $interfaces = Config::getInstance()->object()->interfaces ?? null;
        foreach (array_filter(explode(',', (string)$this->general->ifaceBlacklist)) as $ifKey) {
            $blacklist[] = (string)($interfaces->$ifKey->if ?? '') ?: $ifKey;
        }
        $config['IFaceBlackList'] = array_values(array_unique($blacklist));

        $opnsenseMode = (string)$this->routing->trafficHandling === 'opnsense';

        $config['NetworkMonitor'] = (string)$this->general->networkMonitor === '1';
        $config['DisableAutoConnect'] = (string)$this->general->disableAutoConnect === '1';
        $config['ServerSSHAllowed'] = (string)$this->ssh->enable === '1';
        $config['EnableSSHRoot'] = (string)$this->ssh->enableRoot === '1';
        $config['EnableSSHSFTP'] = (string)$this->ssh->enableSFTP === '1';
        $config['EnableSSHLocalPortForwarding'] = (string)$this->ssh->enableLocalPortForwarding === '1';
        $config['EnableSSHRemotePortForwarding'] = (string)$this->ssh->enableRemotePortForwarding === '1';
        $config['DisableSSHAuth'] = false;
        $config['DisableFirewall'] = $opnsenseMode;
        $config['DisableServerRoutes'] = $opnsenseMode;
        $config['BlockInbound'] = !$opnsenseMode && (string)$this->routing->blockInbound === '1';
        $config['DisableDNS'] = (string)$this->dns->enable !== '1';
        $config['CustomDNSAddress'] = trim((string)$this->dns->customAddress);
        $config['BlockLANAccess'] = (string)$this->routing->accessLan !== '1';
        $config['DisableClientRoutes'] = (string)$this->routing->acceptClientRoutes !== '1';
        $config['RosenpassEnabled'] = (string)$this->postquantum->enableRosenpass === '1';
        $config['RosenpassPermissive'] = (string)$this->postquantum->rosenpassPermissive === '1';

        $encoded = json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        $dir = dirname($target);
        if ($encoded === false || (!is_dir($dir) && !mkdir($dir, 0700, true))) {
            syslog(LOG_ERR, "netbird: failed to prepare configuration for $target");
            return;
        }

        /* write atomically, the daemon may read the file at any time */
        $tmpFile = tempnam($dir, 'config.json.');
        if (
            $tmpFile === false ||
            !chmod($tmpFile, 0600) ||
            file_put_contents($tmpFile, $encoded) === false ||
            !rename($tmpFile, $target)
        ) {
            if ($tmpFile !== false) {
                @unlink($tmpFile);
            }
            syslog(LOG_ERR, "netbird: failed to write configuration to $target");
        }
    }
}
