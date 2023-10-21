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
        unset sessions(${session_id})
    }
}

