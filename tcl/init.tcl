# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2026 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

# Copyright Jerily LTD. All Rights Reserved.
# SPDX-License-Identifier: MIT
source [file join [file dirname [info script]] cookie.tcl]
# The host installs the session adapter for its tpersist configuration.
proc ::tsession::require_backend {config} {
    set dialect [dict get $config db_dialect]
    switch -- $dialect {
        sqlite {set backend sqlite}
        postgres - postgresql {set backend postgres}
        default {error "unsupported SQL session dialect: $dialect"}
    }
    package require tsession-$backend 1.0.1
    return ::tsession::$backend
}

proc ::tsession::initdb {connection config} {
    set backend [require_backend $config]
    ${backend}::initdb $connection
}

proc ::tsession::create {config args} {
    set backend [require_backend $config]
    ${backend}::create {*}$args
}

package provide tsession 2.0.2
