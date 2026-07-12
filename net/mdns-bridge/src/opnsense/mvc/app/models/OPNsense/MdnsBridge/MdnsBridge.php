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

namespace OPNsense\MdnsBridge;

use OPNsense\Base\BaseModel;
use OPNsense\Base\Messages\Message;

class MdnsBridge extends BaseModel
{
    private function checkConfiguration($messages)
    {
        if ($this->general->enabled->isEqual('1')) {
            $interfaces = array_filter(explode(',', $this->general->interfaces->getValue()));
            if (count($interfaces) < 2) {
                $messages->appendMessage(new Message(
                    gettext('At least two interfaces must be selected.'),
                    'general.interfaces'
                ));
            } elseif (count($interfaces) > 32) {
                $messages->appendMessage(new Message(
                    gettext('At most 32 interfaces are supported.'),
                    'general.interfaces'
                ));
            }

            if ($this->general->disable_ipv4->isEqual('1') && $this->general->disable_ipv6->isEqual('1')) {
                $messages->appendMessage(new Message(
                    gettext('IPv4 and IPv6 cannot both be disabled.'),
                    'general.disable_ipv6'
                ));
            }

            if (!$this->general->filtermode->isEqual('none') && $this->general->filters->isEmpty()) {
                $messages->appendMessage(new Message(
                    gettext('At least one service filter must be provided when a filter mode is selected.'),
                    'general.filters'
                ));
            }
        }
    }

    public function performValidation($validateFullModel = false)
    {
        $messages = parent::performValidation($validateFullModel);
        $this->checkConfiguration($messages);
        return $messages;
    }
}
