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
