{#

OPNsense® is Copyright © 2025 by OPNsense Community
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2.  Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

#}

<script>
    $( document ).ready(function() {
        mapDataToFormUI({'frm_GeneralSettings':"/api/beepbeep/settings/get"}).done(function(data){
            // Toggle visibility of custom file fields based on dropdown selection
            function toggleCustomFields() {
                var startVal = $("#beepbeep\\.general\\.StartBeep").val();
                var stopVal = $("#beepbeep\\.general\\.StopBeep").val();
                if (startVal === "custom") {
                    $("tr[id='row_beepbeep.general.StartBeepCustom']").show();
                } else {
                    $("tr[id='row_beepbeep.general.StartBeepCustom']").hide();
                }
                if (stopVal === "custom") {
                    $("tr[id='row_beepbeep.general.StopBeepCustom']").show();
                } else {
                    $("tr[id='row_beepbeep.general.StopBeepCustom']").hide();
                }
            }
            toggleCustomFields();
            $("#beepbeep\\.general\\.StartBeep").change(toggleCustomFields);
            $("#beepbeep\\.general\\.StopBeep").change(toggleCustomFields);
        });

        // link save button to API set action
        $("#saveAct").click(function(){
            saveFormToEndpoint("/api/beepbeep/settings/set", 'frm_GeneralSettings', function(){
                // after save, reload templates and apply configuration
                ajaxCall("/api/beepbeep/service/reload", {}, function(data, status) {
                    ajaxCall("/api/beepbeep/service/apply", {}, function(data, status) {
                        if (data && data['status'] === 'ok') {
                            $("#responseMsg").removeClass("hidden").removeClass("alert-danger").addClass("alert-info").html("{{ lang._('Beep configuration saved and applied successfully.') }}");
                        } else {
                            var msg = (data && data['message']) ? data['message'] : "{{ lang._('Failed to apply beep configuration.') }}";
                            $("#responseMsg").removeClass("hidden").removeClass("alert-info").addClass("alert-danger").html(msg);
                        }
                    });
                });
            });
        });

        // test button to play start beep
        $("#testAct").SimpleActionButton({
            onAction: function(data) {
                if (data && data['message']) {
                    $("#responseMsg").removeClass("hidden").html(data['message']);
                }
            }
        });
    });
</script>

<div class="alert alert-info hidden" role="alert" id="responseMsg">
</div>

<div class="col-md-12">
    {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_GeneralSettings'])}}
</div>

<div class="col-md-12">
    <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save & Apply') }}</b></button>
    <button class="btn btn-default" id="testAct" data-endpoint="/api/beepbeep/service/test" data-label="{{ lang._('Test Start Beep') }}"></button>
</div>
