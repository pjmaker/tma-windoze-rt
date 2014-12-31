#!/usr/bin/env wize
# Basic Tk version of xv.

package require Gui

namespace eval ::app::xv {
    
    *array _ {
        img {}   fn {}   scale 1   find -1   files {}
    }
    
    proc Constrain {_} {
        upvar $_ {}
        set img $(img)
        $(w,canv) conf -scrollregion [list 0 0 [image width $img] [image height $img]]
        set wm [image width $img]
        set hm [image height $img]
        wm maxsize . [incr wm 20] [incr hm 20]
    }

    proc Scale {_} {
        # Scale image.
        #set scale [expr {2*$scale}]
        upvar $_ {}
        set (scale) 2
        set nimg [image create photo]
        set img $(img)
        $nimg copy $img -subsample $(scale) $(scale)
        $img copy $nimg
        $img conf -width [image width $nimg] -height [image height $nimg]
        image delete $nimg
        Constrain $_
    }

    proc Next {_ {dir 1}} {
        # Show next image.
        upvar $_ {}
        set ll [llength $(files)]
        while {1} {
            incr (find) $dir
            if {$(find) <0} { set (find) 0 } elseif {$(find)>=$ll} { set (find) [incr ll -1] }
            set (fn) [lindex $(files) $(find)]
            if {$(fn) == {}} {
                return
            }
            if {![catch { $(img) conf -file $(fn) }]} break
        }
        set w  [image width $(img)]
        set h [image height $(img)]
        wm title $(w,.) "$(fn) ${w}x$h [file size $(fn)] bytes"
        set mw [expr {[winfo screenwidth .]-20}]
        set mh [expr {[winfo screenheight .]-50}]
        if {$w > $mw} { set w $mw }
        if {$h > $mh} { set h $mh }
        $(w,canv) conf -width $w -height $h
        Constrain $_
    }

    proc Main {_ args} {
        upvar $_ {}
        set c $(w,canv)
        set (img) [image create photo]
        set (fn) [lindex $args 0]
        set (files) $args
        $c create image {0 0} -image $(img) -anchor nw
        bind $c <s> [list $_ Scale]
        bind $c <q> [list Delete $_]
        bind $c <Escape> [list Delete $_]
        bind $c <space> [list $_ Next]
        bind $c <BackSpace> [list $_ Next -1]
        bind $c <Down> "%W yview scroll 50 units"
        bind $c <Up> "%W yview scroll -50 units"
        bind $c <Next> "%W yview scroll 1 pages"
        bind $c <Prior> "%W yview scroll -1 pages"
        bind $c <Left> "%W xview scroll -50 units"
        bind $c <Right> "%W xview scroll 50 units"
        bind $c <Control-Next> "%W xview scroll 1 pages"
        bind $c <Control-Prior> "%W xview scroll -1 pages"
        focus $c
        Next $_
    }

    Tk::gui create {
        {Canvas - -id canv -scroll * -pos *} {}
    }
}


