# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2023 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

namespace eval ::tsession::signature {
    variable hmac_keyset_handle {}

    proc init {hmac_keyset} {
        variable hmac_keyset_handle
        package require tink
        set hmac_keyset_handle [::tink::register_keyset $hmac_keyset]
    }

    proc sign {content} {
        variable hmac_keyset_handle
        set bytes [::tink::mac::compute ${hmac_keyset_handle} ${content}]
        set tag [::twebserver::base64_encode $bytes]
        set signed_cookie_value "${content}.${tag}"
        return ${signed_cookie_value}
    }

    proc unsign {signed_cookie_value} {
        variable hmac_keyset_handle
        lassign [split ${signed_cookie_value} "."] content tag_b64

        set tag [::twebserver::base64_decode ${tag_b64}]
        set verified [::tink::mac::verify ${hmac_keyset_handle} ${tag} ${content}]
        if { !${verified} } {
            return {}
        }

        return ${content}
    }
}
