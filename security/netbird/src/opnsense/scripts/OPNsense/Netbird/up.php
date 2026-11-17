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

if ($setupKey !== '') {
    putenv('NB_SETUP_KEY=' . $setupKey);
} else {
    putenv('NB_SETUP_KEY');
}

$args = ['--no-browser'];
if ($managementUrl !== '') {
    $args[] = '-m ' . escapeshellarg($managementUrl);
}

$process = proc_open(
    'exec /usr/local/bin/netbird up ' . implode(' ', $args) . ' 2>&1',
    [0 => ['file', '/dev/null', 'r'], 1 => ['pipe', 'w']],
    $pipes
);
if (!is_resource($process)) {
    echo "Failed to start netbird up\n";
    exit(1);
}

/* read until exit, but give up after 30s or when NetBird falls back to an SSO prompt */
stream_set_blocking($pipes[1], false);
$output = '';
$ssoPromptDetected = false;
$timedOut = false;
$deadline = microtime(true) + 30.0;

while (true) {
    if (microtime(true) >= $deadline) {
        $timedOut = true;
        break;
    }
    $read = [$pipes[1]];
    $write = $except = null;
    if (@stream_select($read, $write, $except, 1) === false) {
        break;
    }
    $chunk = (string)fread($pipes[1], 4096);
    $output .= $chunk;
    if (
        $setupKey === '' &&
        (stripos($output, 'Please do the SSO login') !== false ||
            stripos($output, 'use this URL to log in') !== false)
    ) {
        $ssoPromptDetected = true;
        break;
    }
    if ($chunk === '' && feof($pipes[1])) {
        break;
    }
}

if ($timedOut || $ssoPromptDetected || proc_get_status($process)['running']) {
    proc_terminate($process, 9);
}
fclose($pipes[1]);
proc_close($process);

if ($ssoPromptDetected) {
    echo "Setup key is required to register this peer.\n";
    exit(0);
}

$output = rtrim($output, "\r\n");
if ($output !== '') {
    echo $output . "\n";
}
if ($timedOut) {
    echo "Timed out waiting for netbird up.\n";
}
