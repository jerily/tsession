package require twebserver

set init_script {
    package require twebserver
    package require tink

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
    set hmac_keyset_handle [::tink::register_keyset $hmac_keyset]

    namespace eval ::tsession {
        variable secret "keyboard cat"
        variable resave false
        variable save_uninitialized false
        variable cookie [dict create maxAge 3600000]
        variable session_id_cookie_name "SID"

        proc random_chars {len} {
            set chars "0123456789abcdef"
            set result ""
            for {set i 0} {$i < $len} {incr i} {
                append result [string index $chars [expr {int(rand() * 16)}]]
            }
            return $result
        }

        proc gen_id {} {
            set content [random_chars 64]
            return ${content}
        }

        proc get_cookie_session_id {req} {
            global hmac_keyset_handle
            variable session_id_cookie_name

            if { ![dict exists ${req} headers cookie] } {
                return {}
            }

            set cookie_header [dict get ${req} headers cookie]
            if { ${cookie_header} eq {} } {
                return {}
            }

            set cookie_session_id [dict get [::twebserver::parse_cookie ${cookie_header}] ${session_id_cookie_name}]
            if { ${cookie_session_id} eq {} } {
                return {}
            }

            lassign [split ${cookie_session_id} "."] session_id tag_b64

            set tag [::twebserver::base64_decode ${tag_b64}]
            set verified [::tink::mac::verify ${hmac_keyset_handle} ${tag} ${session_id}]
            if { !${verified} } {
                return {}
            }

            return ${session_id}
        }

        proc enter {ctx req} {

            # self-awareness
            if { [dict exists ${req} session] } {
                return ${req}
            }

            #
            if { ![dict exists ${req} cookies] } {
                if { [dict exists ${req} headers cookie] } {
                    set cookie_header [dict get ${req} headers cookie]
                    dict set req cookies [::twebserver::parse_cookie ${cookie_header}]
                }
            }

            # get the session id from the cookie
            set cookie_session_id [get_cookie_session_id $req]

            if { ${cookie_session_id} eq {} } {
                puts "creating new session"
                dict set req session_id [gen_id]
            } else {
                puts "using existing session: ${cookie_session_id}"
                dict set req session_id ${cookie_session_id}
            }
            return $req
        }
        proc leave {ctx req res} {
            global hmac_keyset_handle
            variable session_id_cookie_name

            set session_id [dict get ${req} session_id]
            set bytes [::tink::mac::compute ${hmac_keyset_handle} ${session_id}]
            set tag [::twebserver::base64_encode $bytes]
            set session_id_cookie_value "${session_id}.${tag}"
            return [::twebserver::add_cookie -httponly ${res} ${session_id_cookie_name} ${session_id_cookie_value}]
        }
    }

    set router [::twebserver::create_router]

    ::twebserver::add_middleware \
        -enter_proc ::tsession::enter \
        -leave_proc ::tsession::leave \
        $router

    ::twebserver::add_route -prefix $router GET /asdf get_asdf_handler
    ::twebserver::add_route -strict $router GET /qwerty/:user_id/sayhi get_qwerty_handler
    ::twebserver::add_route -strict $router POST /example post_example_handler
    ::twebserver::add_route $router GET "*" get_catchall_handler

    interp alias {} process_conn {} $router

    proc get_catchall_handler {ctx req} {
        dict set res statusCode 404
        dict set res headers {content-type text/plain}
        dict set res body "not found"
        return $res
    }

    proc post_example_handler {ctx req} {
        dict set res statusCode 200
        dict set res headers {content-type text/plain}
        dict set res body "test message POST [dict get $req headers]"
        return $res
    }

    proc get_asdf_handler {ctx req} {
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

