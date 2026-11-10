# Signed session cookies with configuration owned by each caller, independent of
# the legacy middleware's process-wide store. The caller owns the Tink handle
# and the session's lifetime, rotation and revocation in its backing store.
namespace eval ::tsession::cookie {}

proc ::tsession::cookie::create {args} {
    package require tink
    package require twebserver
    set config {-name SID -mac {} -path / -domain {} -secure 1 -httponly 1 -samesite Lax}
    if {[llength $args] % 2} {error "expected option/value pairs"}
    foreach {key value} $args {
        if {![dict exists $config $key]} {error "unknown cookie option: $key"}
        dict set config $key $value
    }
    if {[dict get $config -mac] eq {}} {error "-mac requires a registered Tink MAC keyset handle"}
    if {![regexp {^[A-Za-z0-9_-]{1,128}$} [dict get $config -name]]} {error "invalid cookie name"}
    if {![regexp {^/[A-Za-z0-9_./~-]*$} [dict get $config -path]]} {error "invalid cookie path"}
    if {![regexp {^[A-Za-z0-9.-]*$} [dict get $config -domain]]} {error "invalid cookie domain"}
    foreach option {-secure -httponly} {
        if {![string is boolean -strict [dict get $config $option]]} {error "$option must be boolean"}
    }
    if {[dict get $config -samesite] ni {Strict Lax None}} {error "invalid SameSite policy"}
    set name [dict get $config -name]
    if {([string match __Secure-* $name] || [string match __Host-* $name] ||
        [dict get $config -samesite] eq "None") && ![dict get $config -secure]} {
        error "cookie policy requires Secure"
    }
    if {[string match __Host-* $name] &&
        ([dict get $config -path] ne "/" || [dict get $config -domain] ne {})} {
        error "__Host- cookies require Path=/ and no Domain"
    }
    return $config
}

# Bind a signature to its cookie scope as well as its opaque session identifier.
proc ::tsession::cookie::message {config value} {
    list tsession-cookie-v1 [dict get $config -name] [dict get $config -path] [dict get $config -domain] $value
}

proc ::tsession::cookie::read {config request} {
    set found 0
    set signed {}
    if {![dict exists $request headers]} {return {}}
    dict for {name header} [dict get $request headers] {
        if {![string equal -nocase $name cookie]} {continue}
        foreach pair [split $header {;}] {
            set pair [string trim $pair]
            set equals [string first = $pair]
            if {[string range $pair 0 [expr {$equals - 1}]] ne [dict get $config -name]} {continue}
            if {[incr found] != 1} {return {}}
            set signed [string range $pair [expr {$equals + 1}] end]
        }
    }
    # Hex MACs avoid URL/base64 decoding ambiguity. Reject duplicates and suffixes.
    if {[string length $signed] > 769 || ![regexp {^([A-Za-z0-9_-]+)\.([a-f0-9]+)$} $signed -> value tag] ||
        [string length $value] > 512 || [string length $tag] < 32 || [string length $tag] > 256 || [string length $tag] % 2} {return {}}
    if {![::tink::mac::verify [dict get $config -mac] [binary decode hex $tag] [message $config $value]]} {return {}}
    return $value
}

proc ::tsession::cookie::options {config} {
    set options [list -path [dict get $config -path] -samesite [dict get $config -samesite]]
    if {[dict get $config -domain] ne {}} {lappend options -domain [dict get $config -domain]}
    if {[dict get $config -httponly]} {lappend options -httponly}
    if {![dict get $config -secure]} {lappend options -insecure}
    return $options
}

proc ::tsession::cookie::issue {config response value} {
    if {[string length $value] > 512 || ![regexp {^[A-Za-z0-9_-]+$} $value]} {error "session identifier must contain 1–512 URL-safe characters"}
    set tag [binary encode hex [::tink::mac::compute [dict get $config -mac] [message $config $value]]]
    ::twebserver::add_cookie {*}[options $config] $response [dict get $config -name] $value.$tag
}

proc ::tsession::cookie::clear {config response} {
    ::twebserver::add_cookie {*}[options $config] -maxage 0 $response [dict get $config -name] {}
}
