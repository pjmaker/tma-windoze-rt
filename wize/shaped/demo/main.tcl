#!/usr/bin/env wize

# Demo illustrating use of the shaped window extension.
# Implements a unified shaped window feature for unix and windows.
# Win32 differs from Unix in using the more cumbersome overrideredirect.

namespace eval ::app::shapedemo {

    variable pc
    set pc(script) [info script]
    set pc(dirname) [file dirname [info script]]
    set pc(iswin) [expr {$::tcl_platform(platform) == "windows"}]
    if {[catch {package require Shaped}]} {
        load $pc(dirname)/../shaped.so
    }

    proc Deiconify {t} {
        # Handle deiconify in Win32 by turning overrideredirect on again.
        variable pc
        bind $t <Map> {}
        wm withdraw $t
        wm overrideredirect $t 1
        ::tk::shaped $t $pc(bgimg)
        wm deiconify $t

    }

    proc Iconify {t} {
        # Iconify window. Disable overrideredirect for Win32 allowing
        # iconify and letting window appear in taskbar.
        # We then set up handler for the deiconify.
        variable pc
        if {!$pc(iswin)} {
            wm iconify $t
            return
        }
        wm withdraw $t
        wm overrideredirect $t 0
        wm iconify $t
        bind $t <Map> [list [namespace current]::Deiconify $t]
        return
    }

    proc MoveStart {t x y} {
        # Mark start of move.
        variable pc
        set pc(x) [expr {[winfo rootx .t]-$x}]
        set pc(y) [expr {[winfo rooty .t]-$y}]
    }

    proc MoveDo {t x y} {
        # Move window.
        variable pc
        wm geometry .t +[expr {$x+$pc(x)}]+[expr {$y+$pc(y)}]
    }

    proc SkinChg {t} {
        # Change to next skin.
        variable pc
        set cf [$pc(bgimg) cget -file]
        set ci [lsearch -exact $pc(skinfiles) $cf]
        if {[incr ci] >= [llength $pc(skinfiles)]} {
            set ci 0
        }
        set imgfile [lindex $pc(skinfiles) $ci]
        $pc(bgimg) conf -file $imgfile
        if {$imgfile == {}} {
            $pc(bgimg) blank
            tk::shaped $t
            return
        }
        wm geometry $t [image width $pc(bgimg)]x[image height $pc(bgimg)]
        tk::shaped $t $pc(bgimg)
    }

    proc Source {} {
        variable pc
        if {[catch { eval [list ::app::edit::new $pc(script)] }]} {
            toplevel .s
            wm title .s "Source for $pc(script)"
            pack [text .s.t]
            set data [read [open $pc(script)]]
            .s.t insert end $data
        }
    }

    proc Main {} {
        variable pc
        wm withdraw .

        toplevel .t -width 1 -height 1
        wm title .t "Shaped Demo"

        if {$pc(iswin)} {
            wm overrideredirect .t 1
        }
        tkwait visibility .t

        set pc(skinfiles) [lsort -dictionary [glob [file join $pc(dirname) skin*.gif]]]
        lappend pc(skinfiles) {}
        set pc(bgimg) [image create photo -file [lindex $pc(skinfiles) 0]]
        tk::shaped .t $pc(bgimg)

        set fw [winfo id .t]
        set c .t.c
        canvas $c -bd 0 -takefocus 1  -width [winfo screenwidth .] -height [winfo screenheight .]
        $c create image {0 0} -image $pc(bgimg) -anchor nw
        .t config -width [image width $pc(bgimg)] -height [image height $pc(bgimg)]

        # Create a hotspot over the "X" in skin2.
        $c create rectangle {310 120 320 130} -width 0 -tags {hotspot quit}
        $c bind quit <1> exit
    
        # Place image as another hotspot for changing skin.
        set newimg [image create photo -file [file join $pc(dirname) burst.gif]]
        set id [$c create image {258 170} -image $newimg -tags {hotspot skin}]
        
        if {[file exists [set zfile /zvfs/img/misc16/licq.gif]]} {
            set actimg [image create photo -file $zfile]
            $c itemconf $id -activeimage $actimg
        }
        $c bind hotspot <Enter> "$c conf -cursor hand2"
        $c bind hotspot <Leave> "$c conf -cursor {}"
        $c bind skin <1> [list [namespace current]::Source]

        button .t.b -text Exit -command exit
        text .t.t -width 40 -height 5
        button .t.b1 -text Iconify -command [list [namespace current]::Iconify .t]
        button .t.b2 -text NextSkin -command [list [namespace current]::SkinChg .t]
        place $c -x 0 -y 0 -anchor nw
        pack propagate .t 0
        pack [frame .t.f] -pady 12
        pack .t.t
        foreach i {.t.b .t.b1 .t.b2} { pack $i }
        .t.t insert end "\tClipped text widget\nUse <B3-Motion> to move window\nTo show Source, click on burst"

        #bind .t <1> {tclLog "XX: %x %y"}
        bind .t <3> [list [namespace current]::MoveStart .t %X %Y]
        bind .t <B3-Motion> [list [namespace current]::MoveDo .t %X %Y]
        bind all <Control-c> exit
        bind .t <Control-Alt-Insert> "console show"

    }


    Main
}
