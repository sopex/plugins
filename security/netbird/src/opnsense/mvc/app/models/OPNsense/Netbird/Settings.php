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
    public function syncConfig($target = '/var/db/netbird/config.json')
    {
        if (!file_exists($target)) {
            return;
        }

        $raw = file_get_contents($target);
        if ($raw === false) {
            syslog(LOG_ERR, "netbird: failed to read configuration from $target");
            return;
        }

        $config = json_decode($raw, true);
        if (!is_array($config)) {
            $jsonError = json_last_error_msg();
            syslog(LOG_ERR, "netbird: failed to decode configuration: $jsonError");
            return;
        }

        $wgIface = trim($this->general->interface->__toString());
        $config["WgIface"] = $wgIface !== '' ? $wgIface : 'wt0';
        $config["WgPort"] = (int)$this->general->wireguardPort->__toString();
        $mtu = (int)$this->general->mtu->__toString();
        $config["MTU"] = $mtu > 0 ? $mtu : 1280;

        $ipmapping = trim($this->general->ipmapping->__toString());
        unset($config["IpMapping"]);
        if ($ipmapping === '') {
            $config["NATExternalIPs"] = [];
        } else {
            $config["NATExternalIPs"] = array_values(array_filter(array_map('trim', explode(',', $ipmapping)), 'strlen'));
        }

        $ifaceBlacklist = [
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
            $config["WgIface"],
        ];
        $selectedIfaces = array_filter(array_map('trim', explode(',', $this->general->ifaceBlacklist->__toString())), 'strlen');
        if (!empty($selectedIfaces)) {
            $cfgObj = Config::getInstance()->object();
            foreach ($selectedIfaces as $ifKey) {
                $device = isset($cfgObj->interfaces->$ifKey->if) ? trim((string)$cfgObj->interfaces->$ifKey->if) : '';
                $ifaceBlacklist[] = $device !== '' ? $device : $ifKey;
            }
        }
        $config["IFaceBlackList"] = array_values(array_unique($ifaceBlacklist));

        $config["NetworkMonitor"] = $this->general->networkMonitor->__toString() == '1';
        $config["DisableAutoConnect"] = $this->general->disableAutoConnect->__toString() == '1';

        $config["ServerSSHAllowed"] = $this->ssh->enable->__toString() == '1';
        $config["EnableSSHRoot"] = $this->ssh->enableRoot->__toString() == '1';
        $config["EnableSSHSFTP"] = $this->ssh->enableSFTP->__toString() == '1';
        $config["EnableSSHLocalPortForwarding"] = $this->ssh->enableLocalPortForwarding->__toString() == '1';
        $config["EnableSSHRemotePortForwarding"] = $this->ssh->enableRemotePortForwarding->__toString() == '1';
        $config["DisableSSHAuth"] = false;

        $trafficHandling = $this->routing->trafficHandling->__toString();
        if ($trafficHandling === 'opnsense') {
            $config["DisableFirewall"] = true;
            $config["BlockInbound"] = false;
            $config["DisableServerRoutes"] = true;
        } else {
            $config["DisableFirewall"] = false;
            $config["BlockInbound"] = false;
            $config["DisableServerRoutes"] = false;
        }

        $config["DisableDNS"] = $this->dns->enable->__toString() != '1';
        $customDns = trim($this->dns->customAddress->__toString());
        if ($customDns === '' && $this->dns->unboundForward->__toString() == '1') {
            $customDns = '127.0.0.1:5053';
        }
        $config["CustomDNSAddress"] = $customDns;

        $config["BlockLANAccess"] = $this->routing->accessLan->__toString() != '1';
        $config["DisableClientRoutes"] = $this->routing->acceptClientRoutes->__toString() != '1';

        $config["RosenpassEnabled"] = $this->postquantum->enableRosenpass->__toString() == '1';
        $config["RosenpassPermissive"] = $this->postquantum->rosenpassPermissive->__toString() == '1';

        $encoded = json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        if ($encoded === false) {
            syslog(LOG_ERR, "netbird: failed to encode configuration for $target");
            return;
        }

        $dir = dirname($target);
        $tmpFile = @tempnam($dir, 'config.json.tmp.');
        if ($tmpFile === false) {
            syslog(LOG_ERR, "netbird: failed to create temporary file in $dir");
            return;
        }

        if (chmod($tmpFile, 0600) === false) {
            @unlink($tmpFile);
            syslog(LOG_ERR, "netbird: failed to set mode 0600 on $tmpFile");
            return;
        }

        if (file_put_contents($tmpFile, $encoded, LOCK_EX) === false) {
            @unlink($tmpFile);
            syslog(LOG_ERR, "netbird: failed to write updated configuration to $tmpFile");
            return;
        }

        if (!rename($tmpFile, $target)) {
            @unlink($tmpFile);
            syslog(LOG_ERR, "netbird: failed to rename $tmpFile to $target");
            return;
        }
    }
}
