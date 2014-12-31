# @configure_input@
#
namespace eval ::tkpath {
    proc load_package {dir} {
        foreach i {tkpathgdi024.dll  tkpathgdiplus028.dll tkpath031.dll} {
	   load [file join $dir $i]
        }
	# Allow optional redirect of library components.
	# Only necessary for testing, but could be used elsewhere.
	if {[info exists ::env(TKPATH_LIBRARY)]} {
	    set dir $::env(TKPATH_LIBRARY)
	}
	source $dir/tkpath.tcl
    };# load_package
}

package ifneeded tkpath 0.3.1 [list ::tkpath::load_package $dir]

#*EOF*
