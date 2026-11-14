# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2026 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

# Register the package and load its dependencies.
set dir [file dirname [info script]]

package ifneeded tsession 2.0.1 [list source [file join $dir tcl init.tcl]]

package ifneeded tsession::sql 2.0.1 [list source [file join $dir tcl sql.tcl]]
