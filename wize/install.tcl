#!/usr/bin/env wize

# Installation script.
# On unix invoke with "sudo"

set iswin [expr {$tcl_platform(platform)=="windows"}]

set p(-dist) {}
set p(-dest) /usr/bin

array set p $argv
if {$p(-dist) == {}} {
    set p(-dist) [file dirname [file normalize [info script]]]
}


set srcs {
    ted/ted.tcl
    tdb/tdb.tcl
    demos/guild.gui
    demos/slider.tcl
    demos/ledger.tcl 
}

set desktop {#!/usr/bin/env xdg-open

[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Icon[en_CA]=$p(-dist)/wize.png
Name[en_CA]=Wize
Exec=$dir/wize /
Name=Wize
Icon=$p(-dist)/wize.png
}

proc Link {dest src} {
    catch { file delete $dest }
    file link -symbolic $dest $src
}

if {!$iswin} {
    Link $p(-dest)/wize $p(-dist)/wize
    foreach src $srcs {
        set dest $p(-dest)/[file rootname [file tail $src]]
        Link $dest $p(-dist)/$src
    }
    if {[file isdirectory ~/Desktop]} {
       set fn ~/Desktop/Wize.desktop
       set fp [open $fn w+]
       set dir $p(-dest)
       set dat [subst -nocommands $desktop]
       puts $fp $dat
       close $fp
       file attribute $fn -permissions a+rx
       if {[info exists ::env(SUDO_USER)]} {
           file attribute $fn -owner $::env(SUDO_USER)
       }
    }
} else {
    set lfn [file nativename ~/Desktop/wize.lnk]
    win32::link set $lfn -path [info nameofexecutable] -args /
}

exit 0
