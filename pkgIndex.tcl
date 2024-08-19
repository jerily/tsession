set dir [file dirname [info script]]

package ifneeded tsession 1.0.1 [list source [file join $dir tcl init.tcl]]
