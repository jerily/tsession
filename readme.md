# tsession

Simple session middleware for [twebserver](https://github.com/jerily/twebserver).

## Prerequisites

- [twebserver](https://github.com/jerily/twebserver) (version 1.47.51 and above)
- [tink-tcl](https://github.com/jerily/tink-tcl) (version 20240704.0 and above)

## Installation

```bash
# It installs to /usr/local/lib
# To install elsewhere, change the prefix
# e.g. make install PREFIX=/path/to/install
make install
```

## Usage

The following are supported configuration options:

* **hmac_keyset** - Cleartext keyset to use for HMAC.
* **cookie_domain** - The domain to set the cookie on.
* **cookie_httponly** - Whether to set the HttpOnly flag on the cookie. Default is true.
* **cookie_maxage** - The max age of the cookie in seconds. Default is 86400 (1 day).
* **cookie_path** - The path to set the cookie on. Default is "/".
* **cookie_samesite** - The SameSite attribute of the cookie. Default is "Lax".
* **cookie_name** - The name of the cookie. Default is "SID".
* **rolling** - Whether to roll the session on each request. Default is false.
* **save_uninitialized** - Forces a session that is "uninitialized" to be saved to the store. A session is uninitialized when it is new but not modified.
* **store** - The store to use. Default is "MemoryStore".

## Examples

See full example [here](examples/app.tcl).

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

    ::twebserver::create_router -command_name process_conn router

    ::twebserver::add_middleware \
        -enter_proc ::tsession::enter \
        -leave_proc ::tsession::leave \
        $router

    ::twebserver::add_route -strict $router GET /blog/:view_user_id/sayhi get_blog_post_handler
    ::twebserver::add_route -strict $router POST /login post_login_handler
    ::twebserver::add_route -strict $router POST /logout post_logout_handler
    ::twebserver::add_route $router GET "*" get_catchall_handler

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