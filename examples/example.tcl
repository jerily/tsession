package require twebserver

set init_script {
    lappend auto_path [file dirname [info script]]/..

    package require twebserver
    package require tink
    package require tsession

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

