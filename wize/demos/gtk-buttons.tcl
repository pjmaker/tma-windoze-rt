#!/usr/bin/env wize

# Demonstrate gtk style buttons (call with an arg for no-gtk)

namespace eval Tst {
    font conf TkDefaultFont -size 10 -family Verdana
    set nobd [llength $argv]

    if {!$nobd} {
        Tk::niceButtons 1
        namespace path ::blt::tile
    }

    pack [frame .f  ] -fill x -pady 2
    foreach i {File Edt Options Help} {
        pack [button .f.b$i -text $i] -side left -fill y
    }
    .f.bOptions conf -state disabled -takefocus 0
    pack [checkbutton .f.cb -text Chk -padx 9 ] -side left -fill y
    pack [radiobutton .f.rb -text Radio -padx 9 ] -side left -fill y
    set m .f.mb.m
    pack [menubutton .f.mb -text Menu -menu $m -indicatoron 1] -side left -fill y
    menu $m
    $m add command -label File
    pack [text .t -bd 1 -highlightth 0] -fill both -expand y

    if {!$nobd} {
        set pad 3
        foreach i [winfo children .f] { pack $i -padx $pad -pady $pad }
        pack .f -padx $pad
    }
}
