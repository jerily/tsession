# A self-contained cookie/store round trip. No network listener or email.
package require tsession-sqlite 1.0.1
package require tink
package require twebserver
set mac [::tink::register_keyset [::tink::mac::create_keyset HMAC_SHA256]]
set db [::tpersist::db_connect -database :memory: -autobegin 0]
try {
    ::tsession::sqlite::initdb $db
    set store [::tsession::sqlite::create -connection $db -tenant example]
    set cookies [::tsession::cookie::create -name SID -mac $mac -secure false]
    set token [binary encode hex [::twebserver::random_bytes 32]]
    set id [binary encode hex [::tink::mac::compute $mac [list example session $token]]]
    ::tsession::sql::insert $store $id [dict create expires [expr {[clock seconds]+300}] message Hello] demo-user
    set response [::tsession::cookie::issue $cookies {statusCode 200 body ok} $token]
    set request [dict create headers [dict create Cookie [lindex [split [dict get $response headers Set-Cookie] {;}] 0]]]
    set received [::tsession::cookie::read $cookies $request]
    set key [binary encode hex [::tink::mac::compute $mac [list example session $received]]]
    puts [dict get [::tsession::sql::get $store $key] message]
    ::tsession::sql::delete $store $key
    if {[::tsession::sql::get $store $key] ne {}} {error "session was not revoked"}
} finally {
    ::tpersist::db_disconnect $db
    ::tink::unregister_keyset $mac
}
