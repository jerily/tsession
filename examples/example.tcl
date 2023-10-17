package require twebserver

set init_script {
    package require twebserver
    package require tink

    proc ::twebserver::set_cookie {res curr} {
        if { [dict exists $res multiValueHeaders Set-Cookie] } {
            set prev [dict get $res multiValueHeaders Set-Cookie]
            dict set res multiValuedHeaders Set-Cookie [list {*}$prev $curr]
        } elseif { [dict exists $res headers Set-Cookie] } {
            set prev [dict get $res headers Set-Cookie]
            dict set res multiValuedHeaders Set-Cookie [list $prev $curr]
        } else {
            dict set res headers Set-Cookie $curr
        }
        return $res
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
            global hmac_keyset_handle
            set content [random_chars 64]
            set tag [::twebserver::base64_encode [::tink::mac::compute $hmac_keyset_handle $content]]
            return ${content}.${tag}
        }
        proc enter {ctx req} {
            dict set req session [dict create id [gen_id]]
            return $req
        }
        proc leave {ctx req res} {
            variable session_id_cookie_name
            set curr "${session_id_cookie_name}=[dict get $req session id]; path=/;"
            set res [::twebserver::set_cookie $res $curr]
            return $res
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

