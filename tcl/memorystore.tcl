# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2023 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

package require Thread

namespace eval ::tsession::MemoryStore {
    tsv::array set sessions {}

    proc retrieve_session {session_id} {

        if { [tsv::exists sessions ${session_id}] } {

            set session [tsv::get sessions ${session_id}]

            # check if "session" expired
            set expires [dict get ${session} expires]
            set now [clock seconds]
            if { ${now} > ${expires} } {
                destroy_session ${session_id}
                return {}
            }

            return $session
        }
        return {}
    }

    proc save_session {session_id session_dict} {
        tsv::set sessions ${session_id} $session_dict
    }

    proc destroy_session {session_id} {
        if { [tsv::exists sessions ${session_id}] } {
            tsv::unset sessions ${session_id}
        }
    }

    proc touch_session {session_id session_dict} {
        set current_session_dict [retrieve_session ${session_id}]
        if { ${current_session_dict} ne {} } {
            dict set current_session_dict expires [dict get ${session_dict} expires]
            save_session ${session_id} ${current_session_dict}
        }

    }
}

