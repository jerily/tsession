# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2023 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

namespace eval ::tsession {
    variable cookie_domain ""
    variable cookie_httponly "true"
    variable cookie_insecure "false"
    variable cookie_maxage 86400
    variable cookie_path "/"
    variable cookie_samesite "Lax"
    variable cookie_name "SID"
    variable rolling "false"
    variable save_uninitialized "false"
    variable store "MemoryStore"

    proc init {option_dict} {
        variable cookie_domain
        variable cookie_httponly
        variable cookie_insecure
        variable cookie_maxage
        variable cookie_path
        variable cookie_samesite
        variable cookie_name
        variable rolling
        variable save_uninitialized
        variable store

        if { ![dict exists ${option_dict} hmac_keyset] } {
            error "tsession::init: option_dict must contain hmac_keyset"
        }

        if { ![dict exists ${option_dict} store] || [dict size [dict get $option_dict store]] != 1 } {
            error "tsession::init: option_dict must contain exactly one store"
        }

        ::tsession::signature::init [dict get ${option_dict} hmac_keyset]

        dict for {store store_config} [dict get $option_dict store] {
            ${store}::init $store_config
        }

        if { [dict exists ${option_dict} cookie_domain] } {
            set cookie_domain [dict get ${option_dict} cookie_domain]
        }

        if { [dict exists ${option_dict} cookie_httponly] } {
            set cookie_httponly [dict get ${option_dict} cookie_httponly]
        }

        if { [dict exists ${option_dict} cookie_maxage] } {
            set cookie_maxage [dict get ${option_dict} cookie_maxage]
        }

        if { [dict exists ${option_dict} cookie_path] } {
            set cookie_path [dict get ${option_dict} cookie_path]
        }

        if { [dict exists ${option_dict} cookie_samesite] } {
            set cookie_samesite [dict get ${option_dict} cookie_samesite]
        }

        if { [dict exists ${option_dict} cookie_name] } {
            set cookie_name [dict get ${option_dict} cookie_name]
        }

        if { [dict exists ${option_dict} rolling] } {
            set rolling [dict get ${option_dict} rolling]
        }

        if { [dict exists ${option_dict} save_uninitialized] } {
            set save_uninitialized [dict get ${option_dict} save_uninitialized]
        }

        if { [dict exists ${option_dict} cookie_insecure] } {
            set cookie_insecure [dict get ${option_dict} cookie_insecure]
        }
    }

    proc gen_id {} {
        return [::twebserver::base64_encode [::twebserver::sha256 [::twebserver::random_bytes 256]]]
    }

    proc get_cookie_session_id {req} {
        variable cookie_name

        if { ![dict exists ${req} cookies ${cookie_name}] } {
            return {}
        }

        set cookie_session_id [dict get ${req} cookies ${cookie_name}]
        if { ${cookie_session_id} eq {} } {
            return {}
        }

        return [::tsession::signature::unsign ${cookie_session_id}]
    }

    proc enter {ctx req} {
        variable store
        variable cookie_maxage

        # self-awareness
        if { [dict exists ${req} session] } {
            return ${req}
        }

        # parse and populate cookies from headers
        if { ![dict exists ${req} cookies] } {
            if { [dict exists ${req} headers cookie] } {
                set cookie_header [dict get ${req} headers cookie]
                dict set req cookies [::twebserver::parse_cookie ${cookie_header}]
            }
        }

        # get the session id from the cookie
        set cookie_session_id [get_cookie_session_id $req]

        if { ${cookie_session_id} eq {} } {

            # create new session
            set req_session_id [gen_id]
            # puts "creating new session: ${req_session_id}"
            set now [clock seconds]
            set expires [expr { ${now} + ${cookie_maxage} }]
            set req_session_dict [dict create \
                id ${req_session_id} \
                expires ${expires}]

        } else {

            # see if we can use existing session
            set req_session_dict [${store}::retrieve_session ${cookie_session_id}]
            if { ${req_session_dict} ne {} } {

                # use existing session
                # puts "using existing session: ${cookie_session_id}"
                set req_session_id ${cookie_session_id}

            } else {

                # create new session (old one expired)
                set req_session_id [gen_id]
                # puts "creating new session after expiration: ${req_session_id}"
                set now [clock seconds]
                set expires [expr { ${now} + ${cookie_maxage} }]
                set req_session_dict [dict create \
                    id ${req_session_id} \
                    expires ${expires}]

            }

        }
        dict set req cookieSessionId ${cookie_session_id}
        dict set req sessionId ${req_session_id}
        dict set req session ${req_session_dict}

        return $req
    }

    proc amend_session_with_changes {resVar args} {
        if { ${args} eq {} } {
            error "amend_session_with_changes: args cannot be empty"
        }
        if { [llength ${args}] % 2 != 0 } {
            error "amend_session_with_changes: length of args must be even"
        }
        upvar ${resVar} res
        dict set res sessionChanges {*}${args}
    }

    proc mark_session_to_be_destroyed {resVar} {
        upvar ${resVar} res
        dict set res sessionChanges {}
    }

    proc set_cookie_to_delete_it {resVar cookie_name} {
        upvar ${resVar} res
        set res [::twebserver::add_cookie -maxage 0 ${res} ${cookie_name} {}]
    }

    proc session_has_changes {res} {
        return [expr { [dict exists ${res} sessionChanges] && [dict get ${res} sessionChanges] ne {} }]
    }

    proc session_marked_to_be_destroyed {res} {
        return [expr { [dict exists ${res} sessionChanges] && [dict get ${res} sessionChanges] eq {} }]
    }

    proc should_destroy_session {req res} {
        return [expr { [dict exists ${req} sessionId] && [session_marked_to_be_destroyed ${res}] }]
    }

    proc should_save_session {req res} {
        variable save_uninitialized

        set cookie_session_id [dict get ${req} cookieSessionId]
        set req_session_id [dict get ${req} sessionId]

        if { !${save_uninitialized} && ${cookie_session_id} ne ${req_session_id} } {
            return [session_has_changes ${res}]
        }

        # todo: check if session was already saved
        return 1
    }

    proc should_touch_session {req} {
        set cookie_session_id [dict get ${req} cookieSessionId]
        set req_session_id [dict get ${req} sessionId]
        return [expr { ${cookie_session_id} eq ${req_session_id} }]
    }

    proc should_set_cookie {req res} {
        variable save_uninitialized
        variable rolling

        # cannot set cookie without a session id
        if { ![dict exists ${req} sessionId] } {
            return 0
        }

        set cookie_session_id [dict get ${req} cookieSessionId]
        set req_session_id [dict get ${req} sessionId]
        set session_is_modified [session_has_changes ${res}]

        if { ${cookie_session_id} ne ${req_session_id} } {
            return [expr { ${save_uninitialized} || ${session_is_modified} }]
        }

        return [expr { ${rolling} || ${session_is_modified} }]
    }

    proc leave {ctx req res} {
        variable cookie_name
        variable cookie_maxage
        variable cookie_samesite
        variable cookie_domain
        variable cookie_httponly
        variable cookie_path
        variable cookie_insecure
        variable store

        # puts session=[dict get $req session]

        set session_id [dict get ${req} sessionId]

        if { [should_destroy_session ${req} ${res}] } {
            ${store}::destroy_session ${session_id}
            set_cookie_to_delete_it res ${cookie_name}
            return ${res}
        }

        if { [should_save_session ${req} ${res}] } {

            set session_dict [dict get ${req} session]
            if { [dict exists ${res} sessionChanges] } {
                set session_dict [dict merge ${session_dict} [dict get ${res} sessionChanges]]
            }

            ${store}::save_session ${session_id} ${session_dict}

            if { [should_set_cookie ${req} ${res}] } {

                set cookie_value [::tsession::signature::sign ${session_id}]

                set cookie_options [list]

                lappend cookie_options -expires [clock format [dict get ${session_dict} expires] -format "%a, %d %b %Y %H:%M:%S GMT"]

                #if { ${cookie_maxage} ne {} } {
                #    lappend cookie_options -maxage ${cookie_maxage}
                #}

                if { ${cookie_samesite} ne {} } {
                    lappend cookie_options -samesite ${cookie_samesite}
                }

                if { ${cookie_domain} ne {} } {
                    lappend cookie_options -domain ${cookie_domain}
                }

                if { ${cookie_path} ne {} } {
                    lappend cookie_options -path ${cookie_path}
                }

                if { ${cookie_httponly} } {
                    lappend cookie_options -httponly
                }

                if { ${cookie_insecure} } {
                    lappend cookie_options -insecure
                }

                set res [::twebserver::add_cookie {*}${cookie_options} ${res} ${cookie_name} ${cookie_value}]

                #puts res=$res

                return ${res}
            }

        } elseif { [should_touch_session ${req}] } {
            ${store}::touch_session ${session_id} ${session_dict}
        }

        return ${res}
    }

    proc is_logged_in {req} {
        return [dict exists ${req} session loggedin]
    }

    proc guard_is_logged_in {ctx req} {
        if { ![is_logged_in $req] } {
            return -code error -options [::twebserver::build_response 401 text/plain "unauthorized"]
        }
        return $req
    }

    proc login_user {resVar} {
        upvar ${resVar} res
        ::tsession::amend_session_with_changes res loggedin true
    }

    proc logout_user {resVar} {
        upvar ${resVar} res
        ::tsession::mark_session_to_be_destroyed res
    }
}
