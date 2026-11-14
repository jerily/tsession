# tsession

Per-mount signed cookies and tenant-scoped SQL session persistence for Tcl.
Requires `tink-tcl` and `twebserver`. SQL stores additionally use `tpersist`.
There is no process-wide session state or default memory store.

## Cookies

```tcl
package require tsession 2.0.0
set cookies [::tsession::cookie::create -name SID -mac $macHandle -secure true]
set sessionId [::tsession::cookie::read $cookies $request]
set response [::tsession::cookie::issue $cookies $response $sessionId]
set response [::tsession::cookie::clear $cookies $response]
```

The caller owns the registered Tink MAC handle. Options are `-name SID`, `-mac`
(required), `-path /`, `-domain {}`, `-secure true`, `-httponly true`, and
`-samesite Lax`. Use `-secure false` for local HTTP. Host/Secure cookie prefixes
and SameSite=None enforce their required secure attributes.

Identifiers contain 1–512 ASCII letters, digits, underscores or hyphens. Read
returns empty for missing, duplicate, malformed or tampered cookies. Signatures
bind the identifier to the cookie name, path and domain. Response headers and
other cookies are preserved. Cookies have a browser-session lifetime; the store
enforces server-side expiry. Applications own authentication, CSRF and rotation.

## SQL stores

- `tsession-sqlite` selects a borrowed SQLite connection.
- `tsession-postgres` selects a borrowed PostgreSQL connection.

Both factories require a tenant and reject the wrong connection dialect. Each
worker owns its connection. Factories never initialize schema; call the store's
`initdb` procedure explicitly before serving requests.

```tcl
package require tsession-sqlite 1.0.1
set db [::tpersist::db_connect -database ./sessions.sqlite3 -autobegin 0]
::tsession::sqlite::initdb $db
set store [::tsession::sqlite::create -connection $db -tenant my-site]
::tsession::sql::insert $store opaque-id [dict create expires [expr {[clock seconds]+3600}]] user-1
set data [::tsession::sql::get $store opaque-id]
::tsession::sql::update $store opaque-id {preference dark}
::tsession::sql::revoke $store user-1
::tsession::sql::prune $store
::tpersist::db_disconnect $db
```

`tsession::sql` 2.0.0 is bundled here and requires tpersist 0.1.4+. Its `insert`,
`get`, `update`, `delete`, `revoke`, and `prune` operations use only `tpersist`.
Writes share the caller's transactions. Updates use revision checks and cannot
revive expired or revoked sessions. Expiry is absolute. Dictionaries are data,
never evaluated as scripts; applications encrypt sensitive fields before saving.
For authentication, use a MAC of the browser token as the database ID, as shown
in [examples/sqlite.tcl](examples/sqlite.tcl).

The `tsession_sessions` primary key `(tenant, id)` supports reads/updates/deletes.
Indexes on `(tenant, subject)` and `(tenant, expires)` support revocation and
pruning. `web-user` uses these stores for LOCAL/PROD respectively. The community
integration suite verifies their query plans on SQLite and PostgreSQL.

Version 2 removes the global middleware, MemoryStore and standalone signature
API. Use the APIs above; no compatibility wrappers are provided.

## Install and test

```sh
make install PREFIX=/path/to/prefix
# With native dependencies on TCLLIBPATH:
tclsh tests/all.tcl
# Also install tsession-sqlite to run the complete cookie/store example:
tclsh examples/sqlite.tcl
```

Store package suites cover persistence, expiry, tenant isolation, revocation
and transaction rollback. Generated cookie jars are ignored and must not be
committed.
