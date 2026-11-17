{#
 # Copyright (C) 2025 Ralph Moser, PJ Monitoring GmbH
 # Copyright (C) 2025 squared GmbH
 # Copyright (C) 2025 Christopher Linn, BackendMedia IT-Services GmbH
 # Copyright (C) 2025 NetBird GmbH
 # All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without modification,
 # are permitted provided that the following conditions are met:
 #
 # 1.  Redistributions of source code must retain the above copyright notice,
 #     this list of conditions and the following disclaimer.
 #
 # 2.  Redistributions in binary form must reproduce the above copyright notice,
 #     this list of conditions and the following disclaimer in the documentation
 #     and/or other materials provided with the distribution.
 #
 # THIS SOFTWARE IS PROVIDED “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES,
 # INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 # AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 # AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 # OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 # POSSIBILITY OF SUCH DAMAGE.
 #}

<script>
    $(document).ready(() => {
        let refreshTimer = null;
        let statusInFlight = false;

        function getElapsedTime(date) {
            if (!(date instanceof Date) || isNaN(date.getTime()) || date.getFullYear() <= 1 || date.getTime() <= 0) {
                return "-";
            }

            const now = new Date();
            const diff = now - date;
            if (diff < 1000) return "{{ lang._('Now') }}";

            const units = [
                { label: "d", ms: 86400000 },
                { label: "h", ms: 3600000 },
                { label: "m", ms: 60000 },
                { label: "s", ms: 1000 },
            ];

            const parts = [];
            let remaining = diff;

            for (const { label, ms } of units) {
                const val = Math.floor(remaining / ms);
                if (val > 0) {
                    parts.push(`${val}${label}`);
                    remaining %= ms;
                }
                if (parts.length === 2) break;
            }

            return `${parts.join(" ")} ago`;
        }

        function formatBytes(bytes) {
            const num = Number(bytes) || 0;
            const unit = 1024;

            if (num < unit) {
                return `${num} B`;
            }

            const units = ['Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei'];
            const exp = Math.min(units.length, Math.floor(Math.log(num) / Math.log(unit)));
            const prefix = units[exp - 1];
            const value = num / Math.pow(unit, exp);

            return `${value.toFixed(1)} ${prefix}B`;
        }

        /* cells are plain values (rendered as text) or jQuery elements */
        function buildTable(headers, rows) {
            const $headerRow = $('<tr></tr>');
            headers.forEach(h => $headerRow.append($('<th></th>').text(h)));

            const $tbody = $('<tbody></tbody>');
            rows.forEach(cells => {
                const $tr = $('<tr></tr>');
                cells.forEach(cell => {
                    const $td = $('<td></td>');
                    cell instanceof jQuery ? $td.append(cell) : $td.text(String(cell ?? '-'));
                    $tr.append($td);
                });
                $tbody.append($tr);
            });

            return $('<table class="table table-hover table-striped table-condensed"></table>')
                .append($('<thead></thead>').append($headerRow), $tbody);
        }

        function renderConnectionStatus(status) {
            const $connStatus = $("#connStatus").empty();
            if (!status || Object.keys(status).length === 0) {
                $connStatus.append(
                    $('<div class="alert alert-warning"></div>').text("{{ lang._('No status available.') }}")
                );
                return;
            }

            const fmtConn = ({ connected, url, error } = {}) =>
                connected
                    ? `Connected${url ? ` to ${url}` : ''}`
                    : `Disconnected${error ? `, reason: ${error}` : ''}`;

            const fmtList = (items, fmtFn, fallback) =>
                items?.length ? items.map(fmtFn).join("\n") : fallback;

            const managementStr = fmtConn(status.management);
            const signalStr = fmtConn(status.signal);
            const interfaceType = status.usesKernelInterface ? "Kernel" : status.netbirdIp ? "Userspace" : "N/A";
            const interfaceIp = status.netbirdIp || "N/A";

            const relaysStr = fmtList(
                status.relays?.details,
                r => {
                    const state = r.available ? "Available" : "Unavailable";
                    return `[${r.uri}] is ${state}${r.error ? `, reason: ${r.error}` : ""}`;
                },
                `${status.relays?.available || 0}/${status.relays?.total || 0} Available`
            );

            const dnsGroups = status.dnsServers || [];
            const dnsStr = fmtList(
                status.dnsServers,
                g => {
                    const servers = g.servers?.join(", ") || "N/A";
                    const domains = g.domains?.join(", ") || ".";
                    const state = g.enabled ? "Available" : "Unavailable";
                    return `[${servers}] for [${domains}] is ${state}${g.error ? `, reason: ${g.error}` : ""}`;
                },
                `${dnsGroups.filter(g => g.enabled).length}/${dnsGroups.length} Available`
            );

            let sshServerSummary = "-";
            if (status.sshServer && typeof status.sshServer === "object") {
                const sessionCount = Array.isArray(status.sshServer.sessions) ? status.sshServer.sessions.length : 0;
                sshServerSummary = status.sshServer.enabled
                    ? `Enabled (${sessionCount} active session${sessionCount === 1 ? "" : "s"})`
                    : "Disabled";
            }

            const quantumStr = status.quantumResistance
                ? `true${status.quantumResistancePermissive ? " (permissive)" : ""}`
                : "false";
            const peersCountStr = `${status.peers?.connected || 0}/${status.peers?.total || 0} Connected`;

            const rows = [
                ["{{ lang._('Daemon version') }}", status.daemonVersion || "-"],
                ["{{ lang._('CLI version') }}", status.cliVersion || "-"],
                ["{{ lang._('Profile') }}", status.profileName || "-"],
                ["{{ lang._('Management') }}", managementStr],
                ["{{ lang._('Signal') }}", signalStr],
                ["{{ lang._('Relays') }}", relaysStr],
                ["{{ lang._('Nameservers') }}", dnsStr],
                ["{{ lang._('FQDN') }}", status.fqdn || "-"],
                ["{{ lang._('NetBird IP') }}", interfaceIp],
                ["{{ lang._('Interface type') }}", interfaceType],
                ["{{ lang._('Quantum resistance') }}", quantumStr],
                ["{{ lang._('Lazy connection') }}", status.lazyConnectionEnabled ? "true" : "false"],
                ["{{ lang._('SSH server') }}", sshServerSummary],
                ["{{ lang._('Networks') }}", status.networks?.length ? status.networks.join(", ") : "-"],
                ["{{ lang._('Peers count') }}", peersCountStr],
            ];

            const $table = $('<table class="table table-hover table-striped table-condensed"></table>');
            const $tbody = $('<tbody></tbody>');

            rows.forEach(([label, value]) => {
                const $tr = $('<tr></tr>');
                $tr.append($('<th style="width: 220px;"></th>').text(label));
                $tr.append($('<td style="white-space: pre-wrap;"></td>').text(String(value ?? "-")));
                $tbody.append($tr);
            });

            $table.append($tbody);
            $connStatus.append($table);
        }

        function renderPeersTable(status) {
            const $peersDetails = $("#peersDetail").empty();
            const details = status?.peers?.details || [];

            if (!details.length) {
                $peersDetails.append(
                    $('<p class="text-muted"></p>').text("{{ lang._('No peers found.') }}")
                );
                return;
            }

            const headers = [
                "{{ lang._('FQDN') }}",
                "{{ lang._('NetBird IP') }}",
                "{{ lang._('Status') }}",
                "{{ lang._('Connection') }}",
                "{{ lang._('ICE (Local / Remote)') }}",
                "{{ lang._('Latency') }}",
                "{{ lang._('Transfer (Rx / Tx)') }}",
                "{{ lang._('Last Handshake') }}",
                "{{ lang._('Networks') }}",
            ];

            const getOrDefault = (val, def = '-') =>
                (val !== undefined && val !== null && val !== '') ? String(val) : def;
            const statusRank = (s) => {
                const lower = String(s || '').toLowerCase();
                if (lower === 'connected') return 0;
                if (lower === 'connecting') return 1;
                return 2;
            };

            const sortedDetails = details.slice().sort((a, b) => {
                const rankDiff = statusRank(a.status) - statusRank(b.status);
                if (rankDiff !== 0) return rankDiff;
                return String(a.fqdn || '').localeCompare(String(b.fqdn || ''));
            });

            const fmtIceSide = (prefix, type, endpoint) => {
                if (!type && !endpoint) return null;
                const parts = [prefix];
                if (type) parts.push(String(type));
                if (endpoint) parts.push(String(endpoint));
                return parts.join(' ');
            };

            const rows = sortedDetails.map(peer => {
                const localIce = fmtIceSide('L:', peer.iceCandidateType?.local, peer.iceCandidateEndpoint?.local);
                const remoteIce = fmtIceSide('R:', peer.iceCandidateType?.remote, peer.iceCandidateEndpoint?.remote);
                let iceCell = '-';
                if (localIce || remoteIce) {
                    iceCell = $('<div></div>');
                    if (localIce) iceCell.append($('<div></div>').text(localIce));
                    if (remoteIce) iceCell.append($('<div></div>').text(remoteIce));
                }

                const networks = Array.isArray(peer.networks) && peer.networks.length
                    ? peer.networks.slice().sort().join(', ')
                    : '-';

                const handshake = new Date(peer.lastWireguardHandshake || 0);

                const latency = typeof peer.latency === 'number' && peer.latency > 0
                    ? `${(peer.latency / 1_000_000).toFixed(2)} ms`
                    : '-';

                const $fqdn = $('<span></span>').text(getOrDefault(peer.fqdn));
                if (peer.publicKey) {
                    $fqdn.attr('title', `Public key: ${peer.publicKey}`);
                }

                const peerStatus = getOrDefault(peer.status);
                const statusLower = peerStatus.toLowerCase();
                const badgeClass = statusLower === 'connected'
                    ? 'label-success'
                    : (statusLower === 'connecting' ? 'label-info' : 'label-default');

                const connType = getOrDefault(peer.connectionType);
                let connCell = connType;
                if (peer.relayAddress && connType.toLowerCase() === 'relayed') {
                    connCell = $('<span></span>')
                        .attr('title', String(peer.relayAddress))
                        .text(connType)
                        .append(' ', $('<i class="fa fa-info-circle text-muted"></i>'));
                }

                return [
                    $fqdn,
                    getOrDefault(peer.netbirdIp),
                    $(`<span class="label ${badgeClass}"></span>`).text(peerStatus),
                    connCell,
                    iceCell,
                    latency,
                    `${formatBytes(peer.transferReceived || 0)} / ${formatBytes(peer.transferSent || 0)}`,
                    getElapsedTime(handshake),
                    networks,
                ];
            });

            $peersDetails.append(buildTable(headers, rows));
        }

        function loadConnectionStatus() {
            if (statusInFlight) {
                return;
            }
            statusInFlight = true;
            const $peersDetailContainer = $("#peersDetailContainer");
            const $refreshIcon = $("#refreshBtnIcon");
            $refreshIcon.addClass("fa-spin");

            ajaxGet('/api/netbird/status/status', {}, (data) => {
                statusInFlight = false;
                $refreshIcon.removeClass("fa-spin");
                renderConnectionStatus(data);
                renderPeersTable(data);

                const isConnected = data?.management?.connected === true;
                $peersDetailContainer.toggleClass("hidden", !isConnected);
            });
        }

        $("#refreshBtn").on("click", () => {
            loadConnectionStatus();
        });

        $("#autoRefreshToggle").on("change", function () {
            if (refreshTimer) {
                clearInterval(refreshTimer);
                refreshTimer = null;
            }
            if ($(this).is(":checked")) {
                refreshTimer = setInterval(loadConnectionStatus, 10000);
            }
        });

        loadConnectionStatus();
        updateServiceControlUI('netbird');
    });
</script>
<section class="page-content-main">
    <div class="content-box">
        <div class="col-md-12" style="margin-top: 10px; margin-bottom: 10px;">
            <div class="pull-right">
                <label class="checkbox-inline" style="margin-right: 12px;">
                    <input type="checkbox" id="autoRefreshToggle" />
                    {{ lang._('Auto-refresh') }}
                </label>
                <button class="btn btn-default btn-sm" id="refreshBtn" type="button">
                    <i class="fa fa-refresh" id="refreshBtnIcon"></i> {{ lang._('Refresh') }}
                </button>
            </div>
            <h2>{{ lang._('Connection Status') }}</h2>
            <div class="table-responsive" id="connStatus" style="overflow-x: auto;"></div>
        </div>
        <div class="col-md-12 hidden" id="peersDetailContainer">
            <h2>{{ lang._('Peers') }}</h2>
            <div class="table-responsive" id="peersDetail" style="overflow-x: auto;"></div>
        </div>
    </div>
</section>
