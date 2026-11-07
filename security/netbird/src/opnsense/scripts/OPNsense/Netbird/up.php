#!/usr/local/bin/php
<?php

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

require_once("config.inc");

$auth = new \OPNsense\Netbird\Authentication();
$settings = new \OPNsense\Netbird\Settings();

$settings->syncConfig();

$managementUrl = trim((string)$auth->managementUrl->getValue());
$setupKey = trim((string)$auth->setupKey->getValue());
$hostname = trim((string)$settings->general->hostname->getValue());

$keyFile = null;
$args = ['--no-browser'];

try {
    if ($managementUrl !== '') {
        $args[] = '-m ' . escapeshellarg($managementUrl);
    }

    if ($hostname !== '') {
        $args[] = '--hostname ' . escapeshellarg($hostname);
    }

    if ($setupKey !== '') {
        $keyFile = tempnam('/tmp', 'netbird_key_');
        if ($keyFile === false) {
            echo "Failed to create temporary setup key file\n";
            exit(0);
        }
        if (chmod($keyFile, 0600) === false || file_put_contents($keyFile, $setupKey, LOCK_EX) === false) {
            echo "Failed to write temporary setup key file\n";
            exit(0);
        }
        $args[] = '--setup-key-file ' . escapeshellarg($keyFile);
    } else {
        $statusOutput = [];
        exec('/usr/local/bin/netbird status --json 2>/dev/null', $statusOutput);
        $rawStatus = implode("\n", $statusOutput);
        $statusJson = json_decode($rawStatus, true);
        $daemonStatus = is_array($statusJson) ? ($statusJson['daemonStatus'] ?? $statusJson['status'] ?? '') : '';

        if ($daemonStatus === '' && preg_match('/^Daemon status:\s*(\S+)/mi', $rawStatus, $matches)) {
            $daemonStatus = $matches[1];
        }

        if ($daemonStatus === '') {
            $textOutput = [];
            exec('/usr/local/bin/netbird status 2>/dev/null', $textOutput);
            if (preg_match('/^Daemon status:\s*(\S+)/mi', implode("\n", $textOutput), $matches)) {
                $daemonStatus = $matches[1];
            }
        }

        if (in_array($daemonStatus, ['NeedsLogin', 'LoginFailed'], true)) {
            echo "Setup key is required to register this peer.\n";
            exit(0);
        }
    }

    $cmd = 'exec /usr/local/bin/netbird up';
    if (!empty($args)) {
        $cmd .= ' ' . implode(' ', $args);
    }
    $cmd .= ' 2>&1';

    $descriptors = [
        0 => ['file', '/dev/null', 'r'],
        1 => ['pipe', 'w'],
    ];
    $pipes = [];
    $process = proc_open($cmd, $descriptors, $pipes);
    if (!is_resource($process)) {
        echo "Failed to start netbird up\n";
        exit(0);
    }

    stream_set_blocking($pipes[1], false);
    $output = '';
    $ssoPromptDetected = false;

    while (!feof($pipes[1])) {
        $read = [$pipes[1]];
        $write = null;
        $except = null;
        $ready = @stream_select($read, $write, $except, 1, 0);
        if ($ready === false) {
            break;
        }
        if ($ready > 0) {
            $chunk = fread($pipes[1], 4096);
            if ($chunk === false || $chunk === '') {
                if (feof($pipes[1])) {
                    break;
                }
                continue;
            }
            $output .= $chunk;
            if (
                $setupKey === '' &&
                (stripos($output, 'Please do the SSO login') !== false ||
                    stripos($output, 'use this URL to log in') !== false)
            ) {
                $ssoPromptDetected = true;
                proc_terminate($process, 9);
                break;
            }
        }
        $procStatus = proc_get_status($process);
        if (!$procStatus['running']) {
            $rest = stream_get_contents($pipes[1]);
            if (is_string($rest) && $rest !== '') {
                $output .= $rest;
            }
            break;
        }
    }

    fclose($pipes[1]);
    proc_close($process);

    if ($ssoPromptDetected) {
        echo "Setup key is required to register this peer.\n";
        exit(0);
    }

    echo rtrim($output, "\r\n") . "\n";
} finally {
    if ($keyFile !== null && file_exists($keyFile)) {
        @unlink($keyFile);
    }
}
