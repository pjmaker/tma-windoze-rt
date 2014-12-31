#!/usr/bin/env wize

# Nice buttons.  Call with 0-2 args for variety.

set img [image create photo]
winop image gradient $img LightBlue Ivory -width 1000 -height 10
option add *tile $img
. conf -tile $img


if {[llength $argv] == 2} {
    set bg Gray
    set B [Tk::rnd::create -grad DarkGray -bg $bg]
} elseif {[llength $argv]} {
    set bg MediumAquamarine
    set B [Tk::rnd::create -grad DarkGreen -bg $bg -both 1]
} else {
    set bg LightBlue
    set B [Tk::rnd::create]
}

if {$argv0 == [info script]} {
    set bimg [image create photo -file /zvfs/img/icon16/wcspeedtouch.gif]

    pack [frame .f2 -bg $bg] -fill both -expand y
    foreach i {1 2 3 4 5 6 7} {
        set sz [expr {10+$i*4}]
        pack [Tk::rnd::setup $B .f2.b$i -image $bimg -text Test$sz -font "Verdana $sz bold italic" -compound right] -side left
    }
    .f2.b2 conf -state disabled

    pack [frame .f3 -bg $bg] -fill x
    pack [Tk::rnd::setup $B .f3.b -image $bimg -text Test99 -font "Verdana 99 bold italic" -compound right]
}

