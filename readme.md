# tsession

Simple session middleware for [twebserver](https://github.com/jerily/twebserver).

## Prerequisites

- [twebserver](https://github.com/jerily/twebserver) (version 1.47.4 and above)
- [tink-tcl](https://github.com/jerily/tink-tcl) (version 2.0.0 and above)

## Installation

```bash
# It installs to /usr/local/lib
# To install elsewhere, change the prefix
# e.g. make install prefix=/path/to/install
make install
```

## Usage

See full example [here](examples/example.tcl).

```tcl
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

    ::twebserver::add_route -strict $router GET /blog/:view_user_id/sayhi get_blog_post_handler
    ::twebserver::add_route -strict $router POST /login post_login_handler
    ::twebserver::add_route -strict $router POST /logout post_logout_handler
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
        dict set res body "you are now logged in"
        return $res
    }

    proc post_logout_handler {ctx req} {
        ::tsession::mark_session_to_be_destroyed res

        dict set res statusCode 200
        dict set res headers {content-type text/plain}
        dict set res body "you are now logged out"
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
```