namespace eval ::tsession::MemoryStore {
    array set sessions {}

    proc retrieve_session {session_id} {
        variable sessions

        if { [info exists sessions(${session_id})] } {

            set session $sessions(${session_id})

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
        variable sessions
        set sessions(${session_id}) $session_dict
    }

    proc destroy_session {session_id} {
        variable sessions
        if { [info exists sessions(${session_id})] } {
            unset sessions(${session_id})
        }
    }

    proc touch_session {session_id session_dict} {
        variable sessions

        set current_session_dict [retrieve_session ${session_id}]
        if { ${current_session_dict} ne {} } {
            dict set current_session_dict expires [dict get ${session_dict} expires]
            save_session ${session_id} ${current_session_dict}
        }

    }
}

