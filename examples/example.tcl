package require twebserver

set init_script {
    package require twebserver
    package require tink

    namespace eval ::tsession::memstore {
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

    namespace eval ::tsession::signature {
        variable hmac_keyset_handle {}

        proc init {hmac_keyset} {
            variable hmac_keyset_handle
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

    namespace eval ::tsession {
        variable cookie_domain ""
        variable cookie_httponly "true"
        variable cookie_maxage 3600000
        variable cookie_path "/"
        variable cookie_samesite "Lax"
        variable cookie_name "SID"
        variable rolling "false"
        variable save_uninitialized "false"
        variable store "::tsession::memstore"

        proc init {option_dict} {
            variable cookie_domain
            variable cookie_httponly
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

            ::tsession::signature::init [dict get ${option_dict} hmac_keyset]

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

            if { [dict exists ${option_dict} store] } {
                set store [dict get ${option_dict} store]
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
                puts "creating new session: ${req_session_id}"
                set now [clock seconds]
                set expires [expr { ${now} + ${cookie_maxage} }]
                set req_session_dict [dict create \
                    expires ${expires}]

            } else {

                # see if we can use existing session
                set req_session_dict [${store}::retrieve_session ${cookie_session_id}]
                if { ${req_session_dict} ne {} } {

                    # use existing session
                    puts "using existing session: ${cookie_session_id}"
                    set req_session_id ${cookie_session_id}

                } else {

                    # create new session (old one expired)
                    set req_session_id [gen_id]
                    puts "creating new session after expiration: ${req_session_id}"
                    set now [clock seconds]
                    set expires [expr { ${now} + ${cookie_maxage} }]
                    set req_session_dict [dict create \
                        expires ${expires}]

                }

            }
            dict set req cookieSessionId ${cookie_session_id}
            dict set req sessionId ${req_session_id}
            dict set req session ${req_session_dict}

            return $req
        }

        proc should_destroy_session {req res} {
            return [expr {
             [dict exists ${req} session_id]
              && [dict exists ${req} sessionChanges]
              && [dict get ${req} sessionChanges] eq {}
            }]
        }

        proc should_save_session {req res} {
            variable save_uninitialized

            set cookie_session_id [dict get ${req} cookieSessionId]
            set req_session_id [dict get ${req} sessionId]

            if { !${save_uninitialized} && ${cookie_session_id} ne ${req_session_id} } {
                # return true if session was modified
                return [dict exists ${res} sessionChanges]
            }

            # todo: check if session was already saved
            return 1
        }

        proc should_touch_session {req} {
            # todo
            return 0
        }

        proc leave {ctx req res} {
            variable cookie_name
            variable cookie_maxage
            variable cookie_samesite
            variable cookie_domain
            variable cookie_httponly
            variable cookie_path
            variable store

            puts session=[dict get $req session]

            set session_id [dict get ${req} sessionId]

            if { [should_destroy_session ${req} ${res}] } {
                ${store}::destroy_session ${session_id}
                return ${res}
            }

            if { [should_save_session ${req} ${res}] } {

                set session_dict [dict get ${req} session]
                if { [dict exists ${res} sessionChanges] } {
                    set session_dict [dict merge ${session_dict} [dict get ${res} sessionChanges]]
                }
                
                ${store}::save_session ${session_id} ${session_dict}

                set cookie_value [::tsession::signature::sign ${session_id}]

                set cookie_options [list]

                if { ${cookie_maxage} ne {} } {
                    lappend cookie_options -maxage ${cookie_maxage}
                }

                if { ${cookie_samesite} ne {} } {
                    lappend cookie_options -samesite ${cookie_samesite}
                }

                if { ${cookie_domain} ne {} } {
                    lappend cookie_options -domain ${cookie_domain}
                }

                if { ${cookie_path} ne {} } {
                    lappend cookie_options -path ${cookie_path}
                }

                if { ${cookie_httponly} ne {} } {
                    lappend cookie_options -httponly
                }

                return [::twebserver::add_cookie {*}${cookie_options} ${cookie_name} ${cookie_value}]

            } elseif { [should_touch_session ${req}] } {
                ${store}::touch_session ${session_id} ${session_dict}
            }

            return ${res}
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
    }


    set hmac_keyset {{
        "primaryKeyId": 691856985,
        "key": [
          {
            "keyData": {
              "typeUrl": "type.googleapis.com/google.crypto.tink.HmacKey",
              "keyMaterialType": "SYMMETRIC",
              "value": "EgQIAxAgGiDZsmkTufMG/XlKlk9m7bqxustjUPT2YULEVm8mOp2mSA=="
            },
            "outputPrefixType": "TINK",
            "keyId": 691856985,
            "status": "ENABLED"
          }
        ]
    }}

    ::tsession::init [dict create hmac_keyset $hmac_keyset save_uninitialized 0]

    set router [::twebserver::create_router]

    ::twebserver::add_middleware \
        -enter_proc ::tsession::enter \
        -leave_proc ::tsession::leave \
        $router

    ::twebserver::add_route -strict $router GET /blog/:user_id/sayhi get_blog_post_handler
    ::twebserver::add_route -strict $router POST /login post_login_handler
    ::twebserver::add_route -strict $router GET /logout get_logout_handler
    ::twebserver::add_route $router GET "*" get_catchall_handler

    interp alias {} process_conn {} $router

    proc get_catchall_handler {ctx req} {
        dict set res statusCode 404
        dict set res headers {content-type text/plain}
        dict set res body "not found"
        return $res
    }

    proc post_login_handler {ctx req} {
        ::tsession::amend_session_with_changes res loggedin true

        dict set res statusCode 200
        dict set res headers {content-type text/plain}
        dict set res body "test message POST [dict get $req headers]"
        return $res
    }

    proc get_logout_handler {ctx req} {
        ::tsession::mark_session_to_be_destroyed res

        dict set res statusCode 200
        dict set res headers {content-type text/plain}
        dict set res body "test message GET asdf"
        return $res
    }

    proc get_qwerty_handler {ctx req} {
        #puts ctx=[dict get $ctx]
        #puts req=[dict get $req]

        set addr [dict get $ctx addr]
        set user_id [dict get $req pathParameters user_id]

        dict set res statusCode 200
        dict set res headers {content-type text/plain}
        dict set res body "test message GET user_id=$user_id addr=$addr"

        return $res
    }

}

set dir [file dirname [info script]]

set config_dict [dict create \
    num_threads 10 \
    gzip on \
    gzip_types [list text/plain application/json] \
    gzip_min_length 20]
set server_handle [::twebserver::create_server $config_dict process_conn $init_script]
::twebserver::add_context $server_handle localhost [file join $dir "../certs/host1/key.pem"] [file join $dir "../certs/host1/cert.pem"]
::twebserver::listen_server $server_handle 4433
vwait forever
::twebserver::destroy_server $server_handle

