# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2026 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

# Shared SQL persistence for tsession-sqlite and tsession-postgres. A store is a
# value, not a global singleton; its caller owns the tpersist connection.
package require tpersist 0.1.4
namespace eval ::tsession::sql {
    variable root [file normalize [file join [file dirname [info script]] ..]]
    namespace import ::tpersist::db_*
}

proc ::tsession::sql::create {dialect args} {
    set config [dict create connection {} tenant {} dialect $dialect]
    if {[llength $args] % 2} {error "expected option/value pairs"}
    foreach {key value} $args {
        if {$key ni {-connection -tenant}} {error "unknown store option: $key"}
        dict set config [string range $key 1 end] $value
    }
    foreach key {connection tenant} {
        if {[dict get $config $key] eq {}} {error "-$key is required"}
    }
    check_connection [dict get $config connection] $dialect
    return $config
}

proc ::tsession::sql::check_connection {connection dialect} {
    if {[db_dialect $connection] ne $dialect} {error "session store requires a $dialect connection"}
}

# Validate the backend and apply the shared session schema.
proc ::tsession::sql::initdb {connection dialect} {
    variable root
    check_connection $connection $dialect
    db_apply_schema $connection [file join $root sql schema.json] -additive true
}

proc ::tsession::sql::predicate {store {id {}}} {
    set terms [list [db_eq [db_col tenant] [db_value [dict get $store tenant] -type text]]]
    if {$id ne {}} {lappend terms [db_eq [db_col id] [db_value $id -type text]]}
    return [db_and {*}$terms]
}

proc ::tsession::sql::validate_id {id} {
    if {$id eq {}} {error "session id must not be empty"}
}

proc ::tsession::sql::validate_data {data} {
    if {![dict exists $data expires] || ![string is wideinteger -strict [dict get $data expires]]} {
        error "session data requires an integer expires timestamp"
    }
}

proc ::tsession::sql::typed {values} {
    set result {}
    dict for {key value} $values {
        set type [expr {$key in {expires revision} ? "bigint" : "text"}]
        dict set result $key [db_value $value -type $type]
    }
    return $result
}

proc ::tsession::sql::row {store id} {
    validate_id $id
    set query [db_where [db_select tsession_sessions] [db_and [predicate $store $id] \
        [db_gt [db_col expires] [db_value [clock seconds] -type bigint]]]]
    return [lindex [dict get [db_execute [dict get $store connection] $query] rows] 0]
}

proc ::tsession::sql::get {store id} {
    set row [row $store $id]
    if {$row eq {}} {return {}}
    # Tcl dictionaries are data. Never evaluate a serialized session as code.
    return [dict replace [dict get $row data] id $id expires [dict get $row expires]]
}

proc ::tsession::sql::insert {store id data {subject {}}} {
    validate_id $id
    validate_data $data
    set data [dict replace $data id $id]
    set values [dict create tenant [dict get $store tenant] id $id subject $subject \
        expires [dict get $data expires] data $data revision 0]
    db_execute [dict get $store connection] [db_values [db_insert tsession_sessions] [typed $values] -expressions]
    return
}

proc ::tsession::sql::update {store id changes} {
    if {[dict exists $changes id]} {error "session id cannot be updated"}
    set row [row $store $id]
    if {$row eq {}} {return 0}
    set data [dict merge [dict get $row data] $changes]
    validate_data $data
    set values [dict create data $data expires [dict get $data expires] revision [expr {[dict get $row revision] + 1}]]
    # CAS prevents overwriting another worker's update or reviving a revoked row.
    set where [db_and [predicate $store $id] \
        [db_eq [db_col revision] [db_value [dict get $row revision] -type bigint]] \
        [db_gt [db_col expires] [db_value [clock seconds] -type bigint]]]
    return [dict get [db_execute [dict get $store connection] \
        [db_where [db_values [db_update tsession_sessions] [typed $values] -expressions] $where]] rowcount]
}

proc ::tsession::sql::delete {store id} {
    validate_id $id
    return [dict get [db_execute [dict get $store connection] \
        [db_where [db_delete tsession_sessions] [predicate $store $id]]] rowcount]
}

proc ::tsession::sql::revoke {store subject} {
    if {$subject eq {}} {error "subject must not be empty"}
    return [dict get [db_execute [dict get $store connection] [db_where [db_delete tsession_sessions] \
        [db_and [predicate $store] [db_eq [db_col subject] [db_value $subject -type text]]]]] rowcount]
}

proc ::tsession::sql::prune {store} {
    return [dict get [db_execute [dict get $store connection] [db_where [db_delete tsession_sessions] \
        [db_and [predicate $store] [db_le [db_col expires] [db_value [clock seconds] -type bigint]]]]] rowcount]
}

package provide tsession::sql 2.0.1
