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

        function getElapsedTime(date) {
            if (!(date instanceof Date) || isNaN(date.getTime()) || date.getFullYear() <= 1 || date.getTime() <= 0) {
                return "-";
            }

            const now = new Date();
            const diff = now - date;
            if (diff < 1000) return "{{ lang._('Now') }}";

            const units = [
                { label: "day", ms: 86400000 },
                { label: "hour", ms: 3600000 },
                { label: "minute", ms: 60000 },
                { label: "second", ms: 1000 },
            ];

            const parts = [];
            let remaining = diff;

            for (const { label, ms } of units) {
                const val = Math.floor(remaining / ms);
                if (val > 0) {
                    parts.push(`${val} ${label}${val > 1 ? "s" : ""}`);
                    remaining %= ms;
                }
                if (parts.length === 2) break;
            }

            return parts.join(", ") + " ago";
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
                r => `[${r.uri}] is ${r.available ? "Available" : "Unavailable"}${r.error ? `, reason: ${r.error}` : ""}`,
                `${status.relays?.available || 0}/${status.relays?.total || 0} Available`
            );

            const dnsStr = fmtList(
                status.dnsServers,
                g => `[${g.servers?.join(", ") || "N/A"}] for [${g.domains?.join(", ") || "."}] is ${g.enabled ? "Available" : "Unavailable"}${g.error ? `, reason: ${g.error}` : ""}`,
                `${(status.dnsServers || []).filter(g => g.enabled).length}/${(status.dnsServers || []).length} Available`
            );

            let sshServerSummary = "-";
            if (status.sshServer && typeof status.sshServer === "object") {
                const sessionCount = Array.isArray(status.sshServer.sessions) ? status.sshServer.sessions.length : 0;
                sshServerSummary = status.sshServer.enabled
                    ? `Enabled (${sessionCount} active session${sessionCount === 1 ? "" : "s"})`
                    : "Disabled";
            }

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
                ["{{ lang._('Quantum resistance') }}", status.quantumResistance ? `true${status.quantumResistancePermissive ? " (permissive)" : ""}` : "false"],
                ["{{ lang._('Lazy connection') }}", status.lazyConnectionEnabled ? "true" : "false"],
                ["{{ lang._('SSH server') }}", sshServerSummary],
                ["{{ lang._('Networks') }}", status.networks?.length ? status.networks.join(", ") : "-"],
                ["{{ lang._('Peers count') }}", `${status.peers?.connected || 0}/${status.peers?.total || 0} Connected`],
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

            const $table = $('<table class="table table-hover table-striped table-condensed"></table>');
            const $thead = $('<thead></thead>');
            const $headerRow = $('<tr></tr>');
            const headers = [
                "{{ lang._('FQDN') }}",
                "{{ lang._('NetBird IP') }}",
                "{{ lang._('Status') }}",
                "{{ lang._('Connection Type') }}",
                "{{ lang._('ICE Candidate (L/R)') }}",
                "{{ lang._('ICE Endpoint (L/R)') }}",
                "{{ lang._('Relay Address') }}",
                "{{ lang._('Latency') }}",
                "{{ lang._('Transfer (Rx / Tx)') }}",
                "{{ lang._('Last Handshake') }}",
                "{{ lang._('Last Update') }}",
                "{{ lang._('Networks') }}",
                "{{ lang._('Quantum Resistance') }}",
            ];
            headers.forEach(h => $headerRow.append($('<th></th>').text(h)));
            $thead.append($headerRow);

            const $tbody = $('<tbody></tbody>');
            details.forEach(peer => {
                const getOrDefault = (val, def = '-') => (val !== undefined && val !== null && val !== '') ? String(val) : def;
                const localIceType = getOrDefault(peer.iceCandidateType?.local);
                const remoteIceType = getOrDefault(peer.iceCandidateType?.remote);
                const localIceEndpoint = getOrDefault(peer.iceCandidateEndpoint?.local);
                const remoteIceEndpoint = getOrDefault(peer.iceCandidateEndpoint?.remote);

                const quantumStatus = peer.quantumResistance
                    ? (status.quantumResistance ? 'true' : 'false (connection might not work without a remote permissive mode)')
                    : status.quantumResistance
                        ? (status.quantumResistancePermissive
                            ? "false (remote didn't enable quantum resistance)"
                            : "false (connection won't work without a permissive mode)")
                        : 'false';

                const networks = Array.isArray(peer.networks) && peer.networks.length
                    ? peer.networks.slice().sort().join(', ')
                    : '-';

                const lastUpdate = new Date(peer.lastStatusUpdate || 0);
                const handshake = new Date(peer.lastWireguardHandshake || 0);

                const latency = typeof peer.latency === 'number' && peer.latency > 0
                    ? `${(peer.latency / 1_000_000).toFixed(2)} ms`
                    : '-';

                const $tr = $('<tr></tr>');

                const $fqdnCell = $('<td></td>');
                $fqdnCell.append($('<div></div>').text(getOrDefault(peer.fqdn)));
                if (peer.publicKey) {
                    $fqdnCell.append($('<small class="text-muted"></small>').text(String(peer.publicKey)));
                }
                $tr.append($fqdnCell);

                $tr.append($('<td></td>').text(getOrDefault(peer.netbirdIp)));

                const peerStatus = getOrDefault(peer.status);
                const badgeClass = peerStatus.toLowerCase() === 'connected' ? 'label-success' : 'label-default';
                $tr.append($('<td></td>').append($(`<span class="label ${badgeClass}"></span>`).text(peerStatus)));

                $tr.append($('<td></td>').text(getOrDefault(peer.connectionType)));
                $tr.append($('<td></td>').text(`${localIceType} / ${remoteIceType}`));
                $tr.append($('<td></td>').text(`${localIceEndpoint} / ${remoteIceEndpoint}`));
                $tr.append($('<td></td>').text(getOrDefault(peer.relayAddress)));
                $tr.append($('<td></td>').text(latency));
                $tr.append($('<td></td>').text(`${formatBytes(peer.transferReceived || 0)} / ${formatBytes(peer.transferSent || 0)}`));
                $tr.append($('<td></td>').text(getElapsedTime(handshake)));
                $tr.append($('<td></td>').text(getElapsedTime(lastUpdate)));
                $tr.append($('<td></td>').text(networks));
                $tr.append($('<td></td>').text(quantumStatus));

                $tbody.append($tr);
            });

            $table.append($thead).append($tbody);
            $peersDetails.append($table);
        }

        function renderSshSessions(status) {
            const $container = $("#sshSessionsContainer");
            const $sshSessions = $("#sshSessions").empty();
            const sessions = status?.sshServer?.sessions || [];

            if (!status?.sshServer?.enabled || !sessions.length) {
                $container.addClass("hidden");
                return;
            }

            $container.removeClass("hidden");
            const $table = $('<table class="table table-hover table-striped table-condensed"></table>');
            const $thead = $('<thead></thead>');
            const $headerRow = $('<tr></tr>');
            [
                "{{ lang._('Username') }}",
                "{{ lang._('Remote Address') }}",
                "{{ lang._('Command') }}",
                "{{ lang._('Port Forward') }}",
            ].forEach(h => $headerRow.append($('<th></th>').text(h)));
            $thead.append($headerRow);

            const $tbody = $('<tbody></tbody>');
            sessions.forEach(s => {
                const $tr = $('<tr></tr>');
                $tr.append($('<td></td>').text(s.username || "-"));
                $tr.append($('<td></td>').text(s.remoteAddress || "-"));
                $tr.append($('<td></td>').text(s.command || "-"));
                $tr.append($('<td></td>').text(s.portForward || "-"));
                $tbody.append($tr);
            });

            $table.append($thead).append($tbody);
            $sshSessions.append($table);
        }

        function renderEvents(status) {
            const $container = $("#eventsContainer");
            const $events = $("#eventsList").empty();
            const events = Array.isArray(status?.events) ? status.events : [];

            if (!events.length) {
                $container.addClass("hidden");
                return;
            }

            $container.removeClass("hidden");
            const $table = $('<table class="table table-hover table-striped table-condensed"></table>');
            const $thead = $('<thead></thead>');
            const $headerRow = $('<tr></tr>');
            [
                "{{ lang._('Time') }}",
                "{{ lang._('Severity') }}",
                "{{ lang._('Category') }}",
                "{{ lang._('Message') }}",
                "{{ lang._('Details') }}",
            ].forEach(h => $headerRow.append($('<th></th>').text(h)));
            $thead.append($headerRow);

            const $tbody = $('<tbody></tbody>');
            events.forEach(ev => {
                const $tr = $('<tr></tr>');
                const ts = ev.timestamp ? new Date(ev.timestamp) : null;
                $tr.append($('<td></td>').text(ts ? getElapsedTime(ts) : "-"));
                $tr.append($('<td></td>').text(ev.severity || "-"));
                $tr.append($('<td></td>').text(ev.category || "-"));
                $tr.append($('<td></td>').text(ev.userMessage || ev.message || "-"));

                let detailsStr = "-";
                if (ev.metadata && typeof ev.metadata === "object" && Object.keys(ev.metadata).length > 0) {
                    detailsStr = Object.entries(ev.metadata)
                        .map(([k, v]) => `${k}: ${v}`)
                        .join(", ");
                } else if (ev.userMessage && ev.message && ev.userMessage !== ev.message) {
                    detailsStr = ev.message;
                }
                $tr.append($('<td></td>').text(detailsStr));
                $tbody.append($tr);
            });

            $table.append($thead).append($tbody);
            $events.append($table);
        }

        function loadConnectionStatus() {
            const $peersDetailContainer = $("#peersDetailContainer");
            const $refreshIcon = $("#refreshBtnIcon");
            $refreshIcon.addClass("fa-spin");

            ajaxGet('/api/netbird/status/status', {}, (data) => {
                $refreshIcon.removeClass("fa-spin");
                renderConnectionStatus(data);
                renderPeersTable(data);
                renderSshSessions(data);
                renderEvents(data);

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
            <div class="table-responsive" id="connStatus"></div>
        </div>
        <div class="col-md-12 hidden" id="peersDetailContainer">
            <h2>{{ lang._('Peers') }}</h2>
            <div class="table-responsive" id="peersDetail"></div>
        </div>
        <div class="col-md-12 hidden" id="sshSessionsContainer">
            <h2>{{ lang._('Active SSH Sessions') }}</h2>
            <div class="table-responsive" id="sshSessions"></div>
        </div>
        <div class="col-md-12 hidden" id="eventsContainer">
            <h2>{{ lang._('Recent Events') }}</h2>
            <div class="table-responsive" id="eventsList"></div>
        </div>
    </div>
</section>
