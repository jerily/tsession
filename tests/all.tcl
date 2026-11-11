package require tcltest 2
lappend auto_path [file dirname [file dirname [file normalize [info script]]]]
::tcltest::configure -singleproc true -testdir [file dirname [info script]] {*}$argv
exit [::tcltest::runAllTests]
