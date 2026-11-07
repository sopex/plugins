/*
 * Copyright (C) 2026 NetBird GmbH
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

export default class NetBird extends BaseTableWidget {
    constructor() {
        super();
    }

    getGridOptions() {
        return {
            sizeToContent: 650
        };
    }

    getMarkup() {
        let $container = $('<div></div>');
        let $netbirdStatusTable = this.createTable('netbirdStatusTable', {
            headerPosition: 'left'
        });

        $container.append($netbirdStatusTable);
        return $container;
    }

    escapeHtml(value) {
        return $('<div></div>').text(String(value ?? '-')).html();
    }

    async onWidgetTick() {
        const serviceStatusData = await this.ajaxCall('/api/netbird/service/status');
        if (!serviceStatusData || serviceStatusData.status !== 'running') {
            this.displayError(this.translations.serviceDisabled);
            return;
        }

        const nbData = await this.ajaxCall('/api/netbird/status/status');
        if (!nbData || Object.keys(nbData).length === 0) {
            this.displayError(this.translations.noData);
            return;
        }

        const statusData = this.parseData(nbData);
        if (!this.dataChanged('netbird-data', statusData)) {
            return;
        }

        this.updateWidgetTable(statusData);
    }

    parseData(data) {
        const isOnline = data.management?.connected === true;
        const signalConnected = data.signal?.connected === true;
        const relaysAvailable = data.relays?.available ?? 0;
        const relaysTotal = data.relays?.total ?? 0;
        const peersConnected = data.peers?.connected ?? 0;
        const peersTotal = data.peers?.total ?? 0;

        return {
            isOnline: isOnline,
            online: isOnline ? this.translations.yes : this.translations.no,
            version: data.daemonVersion || '-',
            fqdn: data.fqdn || '-',
            netbirdIP: data.netbirdIp || '-',
            signal: signalConnected ? this.translations.connected : this.translations.disconnected,
            relays: `${relaysAvailable}/${relaysTotal}`,
            peers: `${peersConnected}/${peersTotal}`
        };
    }

    updateWidgetTable(data) {
        const rows = [];
        const color = data.isOnline ? 'text-success' : 'text-danger';

        rows.push([
            `<div><i class="fa fa-circle ${color}"></i> ${this.escapeHtml(this.translations.online)}</div>`,
            `<div>${this.escapeHtml(data.online)}</div>`
        ]);

        rows.push([
            `<div>${this.escapeHtml(this.translations.version)}</div>`,
            `<div>${this.escapeHtml(data.version)}</div>`
        ]);

        rows.push([
            `<div>${this.escapeHtml(this.translations.fqdn)}</div>`,
            `<div>${this.escapeHtml(data.fqdn)}</div>`
        ]);

        rows.push([
            `<div>${this.escapeHtml(this.translations.netbirdIP)}</div>`,
            `<div>${this.escapeHtml(data.netbirdIP)}</div>`
        ]);

        rows.push([
            `<div>${this.escapeHtml(this.translations.signal)}</div>`,
            `<div>${this.escapeHtml(data.signal)}</div>`
        ]);

        rows.push([
            `<div>${this.escapeHtml(this.translations.relays)}</div>`,
            `<div>${this.escapeHtml(data.relays)}</div>`
        ]);

        rows.push([
            `<div>${this.escapeHtml(this.translations.peers)}</div>`,
            `<div>${this.escapeHtml(data.peers)}</div>`
        ]);

        $('#netbirdStatusTable .error-message').remove();
        super.updateTable('netbirdStatusTable', rows);
    }

    displayError(message) {
        this.dataChanged('netbird-data', null);
        $('#netbirdStatusTable').empty().append(
            $('<div class="error-message"></div>').text(message)
        );
    }
}
