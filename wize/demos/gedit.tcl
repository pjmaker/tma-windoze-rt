#!/usr/bin/env wize
# A minimalistic editor using GUI.

# BSD copyright 2008 - Peter MacDonald - http://pdqi.com
# RCS: @(#) $Id: gedit.tcl,v 1.7 2010/04/30 16:42:30 pcmacdon Exp $

package require Gui

namespace eval ::app::gedit {
        
    *array _ {
        file {}
    }

    proc Open {_ {fn {}}} {
        # Open a new file.
        upvar $_ {}
        if {$fn == {}} {
            set fn [tk_getOpenFile]
        }
        if {$fn == {}} return
        set (file) $fn
        set data [*fread $fn]
        set w $(w,txt)
        Text delete $w 1.0 end
        Text insert $w end $data
        wm title $(w,.) "gedit: $fn"
    }
    
    proc Save {_} {
        # Save the file.
        upvar $_ {}
        if {[set file [tk_getSaveFile -initialfile $(file)]] == {}} return
        if {$file == {}} return

        set (file) $file
        set w $(w,txt)
        *fwrite $(file) [Text get $w 1.0 end]
    }
    
    proc Code {_} {
        # Show source code.
        variable pd
        if {[info exists pd(script)]} {
            Open $_ $pd(script)
        }
    }
    
    proc Quit {_} {
        # Destroy gui.
        ::Delete $_
    }
    
    proc Main {_ {file {}}} {
        # Main is the application entry point.
        if {$file != {}} {
            Open $_ $file
        }
    }

    Tk::gui create {
        {Toplevel +} {
            style {
                Text { -bg white -bd 4 }
                # "An item style: Class.winname"
                Menu::x.qq { -background Red }
            }
            {Menu +} {
                x Open
                x Save
                x Code
                {x - -id qq} Quit
            }
            {Text - -id txt -scroll * -pos *} {}
            {Entry - -pos _} {}
        }
    }
    
}

