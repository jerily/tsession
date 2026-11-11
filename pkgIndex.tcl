set dir [file dirname [info script]]

package ifneeded tsession 1.1.0 [list source [file join $dir tcl init.tcl]]

package ifneeded tsession::sql 1.1.0 [list source [file join $dir tcl sql.tcl]]
