# Copyright Jerily LTD. All Rights Reserved.
# SPDX-FileCopyrightText: 2023 Neofytos Dimitriou (neo@jerily.cy)
# SPDX-License-Identifier: MIT.

package provide tsession 1.0.3

set dir [file dirname [info script]]

source [file join ${dir} tsession.tcl]
source [file join ${dir} signature.tcl]
source [file join ${dir} memorystore.tcl]