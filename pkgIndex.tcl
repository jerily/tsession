set dir [file dirname [info script]]

package ifneeded tsession 1.0.0 [list source [file join $dir tcl init.tcl]]
