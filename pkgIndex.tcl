set dir [file dirname [info script]]

package ifneeded tsession 2.0.0 [list source [file join $dir tcl init.tcl]]

package ifneeded tsession::sql 2.0.0 [list source [file join $dir tcl sql.tcl]]
