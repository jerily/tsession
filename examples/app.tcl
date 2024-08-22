package require twebserver

set init_script {
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

    ::tsession::init [dict create store [list MemoryStore {}] hmac_keyset $hmac_keyset save_uninitialized 0]

    ::twebserver::create_router -command_name process_conn router

    ::twebserver::add_middleware \
        -enter_proc ::tsession::enter \
        -leave_proc ::tsession::leave \
        $router

    ::twebserver::add_route -strict $router GET / get_index_handler
    ::twebserver::add_route -strict $router GET /blog/:view_user_id/sayhi get_blog_post_handler
    ::twebserver::add_route -strict $router POST /login post_login_handler
    ::twebserver::add_route -strict $router POST /logout post_logout_handler
    ::twebserver::add_route $router GET "*" get_catchall_handler

    proc get_index_handler {ctx req} {
        set loggedin [dict exists $req session loggedin]

        set html [subst -nocommands -nobackslashes {
            <html><body>
                <p>Logged In: $loggedin</p>
                <p><a href=/blog/12345/sayhi>Say hi</a></p>
                <p><form method=post action=/login><button>Login</button></form></p>
                <p><form method=post action=/logout><button>Logout</button></form></p>
            </body></html>
        }]
        return [::twebserver::build_response 200 text/html $html]
    }

    proc get_catchall_handler {ctx req} {
        dict set res statusCode 404
        dict set res headers {content-type text/plain}
        dict set res body "not found"
        return $res
    }

    proc post_login_handler {ctx req} {
        set res [::twebserver::build_redirect 302 /]
        ::tsession::amend_session_with_changes res loggedin true
        return $res
    }

    proc post_logout_handler {ctx req} {
        set res [::twebserver::build_redirect 302 /]
        ::tsession::mark_session_to_be_destroyed res
        return $res
    }

    proc get_blog_post_handler {ctx req} {
        set addr [dict get $ctx addr]
        set view_user_id [dict get $req pathParameters view_user_id]
        set loggedin [dict exists $req session loggedin]

        dict set res statusCode 200
        dict set res headers {content-type text/plain}
        dict set res body "test message GET view_user_id=$view_user_id addr=$addr loggedin=$loggedin"

        return $res
    }

}

set dir [file dirname [info script]]

set config_dict [dict create \
    num_threads 10 \
    gzip on \
    gzip_types [list text/plain application/json] \
    gzip_min_length 20]
set server_handle [::twebserver::create_server -with_router $config_dict process_conn $init_script]
::twebserver::add_context $server_handle localhost [file join $dir "../certs/host1/key.pem"] [file join $dir "../certs/host1/cert.pem"]
::twebserver::listen_server $server_handle 4433
::twebserver::listen_server $server_handle -http 8080

puts "Server running on https://localhost:4433 and http://localhost:8080"

vwait forever
::twebserver::destroy_server $server_handle

