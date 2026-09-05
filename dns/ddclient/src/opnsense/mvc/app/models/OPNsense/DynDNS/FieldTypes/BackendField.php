<?php

/*
 * Copyright (C) 2026 Deciso B.V.
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

namespace OPNsense\DynDNS\FieldTypes;

use OPNsense\Base\FieldTypes\OptionField;

class BackendField extends OptionField
{
    private static $is_ddclient = null;

    public static function isDdclient($reset = false)
    {
        if (self::$is_ddclient === null || $reset) {
            self::$is_ddclient = file_exists('/usr/local/opnsense/version/ddclient');
        }
        return self::$is_ddclient;
    }

    private static function autoSelect()
    {
        return self::isDdclient() ? 'ddclient' : 'opnsense';
    }

    protected function actionPostLoadingEvent()
    {
        $this->internalValue = self::autoSelect();
        return parent::actionPostLoadingEvent();
    }

    public function setValue($value)
    {
        $this->internalValue = self::autoSelect();
        parent::setValue(self::autoSelect());
    }

    public function getNodeData()
    {
        $this->internalValue = self::autoSelect();
        return parent::getNodeData();
    }

    public function getValue(): string
    {
        return self::autoSelect();
    }

    public function __toString()
    {
        return self::autoSelect();
    }
}
