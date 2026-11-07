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
        function updateConditionalFields() {
            const sshEnabled = $("#settings\\.ssh\\.enable").is(":checked");
            const sshSubFields = [
                "#settings\\.ssh\\.enableRoot",
                "#settings\\.ssh\\.enableSFTP",
                "#settings\\.ssh\\.enableLocalPortForwarding",
                "#settings\\.ssh\\.enableRemotePortForwarding"
            ];
            sshSubFields.forEach((selector) => {
                $(selector).closest("tr").toggleClass("hidden", !sshEnabled);
            });

            const netbirdMode = $("#settings\\.routing\\.trafficHandling").val() === "netbird";
            $("#settings\\.routing\\.accessLan").closest("tr").toggleClass("hidden", !netbirdMode);

            const unboundEnabled = $("#settings\\.dns\\.unboundForward").is(":checked");
            $("#settings\\.dns\\.unboundDomain").closest("tr").toggleClass("hidden", !unboundEnabled);

            const rosenpassEnabled = $("#settings\\.postquantum\\.enableRosenpass").is(":checked");
            $("#settings\\.postquantum\\.rosenpassPermissive").closest("tr").toggleClass("hidden", !rosenpassEnabled);
        }

        mapDataToFormUI({'frmSettings': '/api/netbird/settings/get'}).done(() => {
            $('.selectpicker').selectpicker('refresh');
            updateConditionalFields();
            updateServiceControlUI('netbird');
        });

        $("#settings\\.ssh\\.enable, #settings\\.routing\\.trafficHandling, #settings\\.dns\\.unboundForward, #settings\\.postquantum\\.enableRosenpass")
            .on("change", updateConditionalFields);

        $("#reconfigureAct").SimpleActionButton({
            onPreAction: () => {
                const dfObj = new $.Deferred();
                saveFormToEndpoint("/api/netbird/settings/set", 'frmSettings', () => {
                    dfObj.resolve();
                }, true, () => {
                    dfObj.reject();
                });
                return dfObj;
            },
            onAction: () => {
                mapDataToFormUI({'frmSettings': '/api/netbird/settings/get'}).done(() => {
                    $('.selectpicker').selectpicker('refresh');
                    updateConditionalFields();
                    updateServiceControlUI('netbird');
                });
            }
        });
    });
</script>
<div class="content-box">
    {{ partial("layout_partials/base_form",['fields':settingsForm,'id':'frmSettings']) }}
</div>
{{ partial('layout_partials/base_apply_button', {'data_endpoint': '/api/netbird/service/reconfigure', 'data_service_widget': 'netbird'}) }}
