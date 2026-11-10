# tsession

Simple session middleware for [twebserver](https://github.com/jerily/twebserver).

## Prerequisites

- [twebserver](https://github.com/jerily/twebserver) (version 1.47.53 and above)
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

## Compatible Session Stores

- [tsession-dynamodb](https://github.com/jerily/tsession-dynamodb)
- [tsession-valkey](https://github.com/jerily/tsession-valkey)

## Cookies for an application-owned session store

`tsession::cookie` provides per-mount signed cookies without initializing the
legacy middleware or its global MemoryStore. The application keeps its session
records, expiry, rotation and revocation in its own store. Cookie values are
opaque session identifiers, never user details.

```tcl
set cookies [::tsession::cookie::create -name SID -mac $macHandle -secure true]
set sessionId [::tsession::cookie::read $cookies $request]
set response [::tsession::cookie::issue $cookies $response $sessionId]
# To expire the browser cookie with the same scope:
set response [::tsession::cookie::clear $cookies $response]
```

`-mac` is a registered Tink MAC keyset handle owned by the caller. Other options
are `-path /`, `-domain {}`, `-httponly true`, and `-samesite Lax`. Secure defaults
to true; use `-secure false` only for local HTTP. Host/Secure cookie prefixes and
SameSite=None enforce their required secure attributes. Issued cookies have a
browser-session lifetime; the backing store must enforce server-side expiry.
Identifiers contain 1–512 ASCII letters, digits, underscores or hyphens. Read
returns an empty string for missing, duplicate, malformed or tampered cookies.
Signatures bind the identifier to the cookie name, path and domain. Response
headers and other cookies are preserved through `twebserver::add_cookie`.
The legacy `init`/`enter`/`leave` middleware API is unchanged.

Run the independent cookie suite with `tclsh tests/cookie.test`.
