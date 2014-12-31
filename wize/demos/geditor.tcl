#!/home/pcmacdon/bin/wize
# A simple editor implemented using Gui.
# Supports syntax and search, but little else.

# BSD copyright 2008 - Peter MacDonald - http://pdqi.com
# RCS: @(#) $Id: geditor.tcl,v 1.20 2010/04/30 16:42:30 pcmacdon Exp $

package require Gui

namespace eval ::app::geditor {
    
    Mod export

    variable _
    array set _ {
        guiobj {} findpos 1.0 curwin {} curfile {} wrap True
    }
    
    variable Opts {
        { -find  {}  "Search forward in file for pattern" }
    }
    
    namespace eval Help {
        
        proc Ok {_} {
            # Button for the about dialog.
            upvar $_ {}
            Tk::gui dialogclose $_
        }
    }
    
    
    proc UpdateLn {_ w} {
        upvar $_ {}
        set (v,statusln) [Text index $w insert]
    }
    
    proc Focus {_ {tab {}}} {
        # Set focus.
        upvar $_ {}
        set ts $(w,tabset)
        if {$tab == {}} {
            set tab [Tabset get $ts [Tabset index $ts focus]]
            if {$tab == {}} return
        }
        set ww $(tab,win,$tab)
        focus $ww
        set (curwin) $ww
        if {[info exists (tab,file,$tab)] && $(tab,file,$tab) != {}} {
            set (curfile) $(tab,file,$tab)
        }
        UpdateLn $_ $ww
    }
    
    proc Setup {_ tab} {
        # Set focus handler and bindings to tab.
        upvar $_ {}
        set ts $(w,tabset)
        set ww $(tab,win,$tab)
        Tabset select $ts end
        Tabset focus $ts end
        #Tabset tab conf $ts $tab -command [list $_ Focus $tab]
        bind $ww <Control-Next>  [list Tabset tab select $ts right]
        bind $ww <Control-Prior> [list Tabset tab select $ts left]
        bind $ww <ButtonRelease-1> +[list $_ UpdateLn $ww]
        bind $ww <KeyRelease> +[list $_ UpdateLn $ww]
        Focus $_ $tab
        ::Newv (tab,findobj,$tab) ::Tk::gui::Find $ww
    }
    
    namespace eval Config {
        
        Mod upvars _

        proc Wrap {_} {
            upvar $_ {}
            foreach tab [Tabset tab names $(w,tabset)] {
                set f $(tab,win,$tab)
                Text conf $f -wrap [expr {$(wrap)?"char":"none"}]
            }
        }
        
        proc Fontsize {_ size} {
            upvar $_ {}
            switch -- $size {
                Tiny { set s 8 }
                Small { set s 10 }
                Normal { set s 12 }
                Medium { set s 15 }
                Large { set s 20 }
                Huge { set s 30 }
            }
            font configure TkFixedFont -size $s
            font configure TkDefaultFont -size $s
        }
        
        proc Tabs {_ val} {
            upvar $_ {}
            set ts $(w,tabset)
            switch -- $val {
                left { set rot 90 }
                right { set rot 270 }
                default { set rot 0 }
            }
            Tabset conf $ts -side $val -rotate $rot
        }
    }
    
    # File menu.
    namespace eval File {
        
        Mod upvars _ pd
        
        proc Copy {_} {
            upvar $_ {}
            event generate $(curwin) <<Copy>>
        }
        
        proc Cut {_} {
            upvar $_ {}
            event generate $(curwin) <<Cut>>
        }
        
        proc Paste {_} {
            upvar $_ {}
            event generate $(curwin) <<Paste>>
        }
        
        proc Undo {_} {
            upvar $_ {}
            event generate $(curwin) <<Undo>>
        }
        
        proc Redo {_} {
            upvar $_ {}
            event generate $(curwin) <<Redo>>
        }
        
        proc Open {_  {f {}}} {
            # Open new file.
            upvar $_ {}
            set line 0
            if {![file exists $f] && [set ssf [string first : $f]]>0} {
                set line [string range $f [expr {$ssf+1}] end]
                set f [string range $f 0 [expr {$ssf-1}]]
                if {![string is integer $line] || $line<0} {
                    set line 0
                }
            }
            if {$f == {}} {
                set dir [file dirname $(curfile)]
                set f [tk_getOpenFile -parent $(w,.) -initialdir $dir]
            }
            if {$f == {}} return
            set (curfile) $f
            set f [file normalize $f]
            set ts $(w,tabset)
            # If already open, switch to that tab.
            foreach {i j} [array get {} tab,file,*] {
                if {[string equal $j $f]} {
                    Tabset tab select $ts [string range $i 9 end]
                    return
                }
            }
            if {[catch {*fread $f} d]} {
                tk_messageBox -message $d -parent $(w,.)
                return
            }
            set tab [Tabset get $ts focus]
            set t $(tab,win,$tab)
            Text replace $t 1.0 end $d
            if {$line <= 0} {
                Text mark set $t insert 1.0
            } else {
                Text mark set $t insert $line.end
            }
            Text see $t insert-1l
            if {$::tk_version>8.4} {
                Text edit reset $t
            }
            set (tab,file,$tab) $f
            #set (v,statusbar1_2) "Loaded $f"
            set ft [file tail $f]
            Tabset tab conf $ts $tab -text $ft
            Tk::syntax setup $t $f
            Text edit modified $t 0
            after 30 [list focus $t]
        }
    
        proc SaveAs {_} {
            # Save the file.
            upvar $_ {}
            set tab [Tabset get $(w,tabset) focus]
            set f [tk_getSaveFile -parent $(w,.)]
            if {$f == {}} return
            set txt $(tab,win,$tab)
            set d [Text get $txt 1.0 end]
            set fp [open $f w+]
            puts -nonewline $fp $d
            close $fp
            Text edit modified $txt 0
        }
        
    
        proc Save {_} {
            # Save the file.
            upvar $_ {}
            set tab [Tabset get $(w,tabset) focus]
            if {[set f $(tab,file,$tab)] == {}} {
                if {$f == {}} {
                    set f [tk_getSaveFile -parent $(w,.)]
                }
                if {$f == {}} return
                set (tab,file,$tab) $f
            }
            set txt $(tab,win,$tab)
            set d [Text get $txt 1.0 end]
            *fwrite $f $d
            Text edit modified $txt 0
        }
        
        proc New {_} {
            ::New [namespace parent]
        }
        
        proc Tab {_ {file {}}} {
            # Open a new tab replicated from the GUI 'edtab' element of 'tabset'.
            upvar $_ {}
            set ts $(w,tabset) 
            set g $(guiobj)
            
            # Clone a new tab item then get the edtxt%d element in tab.
            set tw [::Tk::gui element itemadd $g "tabset" -useid "edtab"]
            set ww [::Tk::find $tw edtxt*]
            if {$ww == {}} { error "no window: edtxt" }
            
            set tab [Tabset get $ts end]
            set (tab,win,$tab) $ww
            set (curwin) $ww
            $_ Setup $tab
            Open $_ $file
        }

        proc Close {_} {
            # Close current tab.
            upvar $_ {}
            set ts $(w,tabset) 
            set tns [Tabset tab names $ts]
            #if {[llength $tns] <= 1 } return
            set tab [Tabset get $ts focus]
            set tn [Tabset index $ts focus]
            set txt $(tab,win,$tab)
            if {[Text edit modified $txt]} {
               set resp [tk_messageBox -message "Save changes" -type yesnocancel -default yes -parent $(w,.)]
               switch -- $resp {
                   yes { Save $_ }
                   no {}
                   cancel return
               }
           } 
            if {[set ntab [lindex $tns [incr tn]]] == {}} {
                set ntab [lindex $tns [incr tn -2]]
            }
            if {$ntab != {}} {
                Tabset select $ts $ntab
                Tabset focus $ts $ntab
            }
            set w [Tabset tab cget $ts $tab -window]
            destroy $w
            Tabset delete $ts $tab
            foreach i [array names {} tab,*,$tab] {
                unset ($i)
            }
            if {[Tabset tab names $ts] =={}} {
                ::Delete
            }
        }
        
        proc Quit {_} {
            # Quit editor.
            upvar $_ {}
            if {![tk_messageBox -message "Ok to quit" -type yesno -default no -parent $(w,.)]} return
            set ts $(w,tabset)
            foreach i [Tabset tab names $ts] {
                Tabset tab select $ts $i
                Close $_
            }
        }
        
        proc Info {_} {
            # Display file info.
            upvar $_ {}
            set ts $(w,tabset) 
            set tab [Tabset get $ts focus]
            set ww $(curwin)
            if {![info exists (tab,file,$tab)]} return
            set rc "File $(tab,file,$tab)"
            append rc " at [Text index $ww insert] size [string length [Text get $ww 1.0 end]] chars"
            set (v,status) $rc
        }

        proc Icons {_} {
            # Icon selections.
            upvar $_ {}
            set icmd ::app::icons::new
            if {[info commands $icmd] == {}} {
                source [file join $::Mod::pd(dirname) wiz icons.tcl]
            }
            if {[file exists /zvfs/img/icon22]} {
                $icmd /zvfs/img/icon22
            } else {
                $icmd
            }
        }

        proc Code {_} {
            upvar $_ {}
            upvar [namespace parent]::script script
            variable pd
            Tab $_ $pd(script)
        }

        proc Console {_} {
            upvar $_ {}
            console show
        }

    }

    proc delete {_} {
        # Deletion handler.
        ::Delete $_
    }

    proc Main {_ args} {
        # Instantiate new editor.
        upvar $_ {}
        set ts $(w,tabset)
        set tab [Tabset get $ts end]
        set ww $(w,edtxt)
        set (tab,win,$tab) $ww
        Setup $_ $tab
        busy hold $(w,.)
        bind $ts <<TabsetSelect>> [list $_ Focus]
        update
        after idle [list busy release $(w,.)]
        set lst {}
        foreach i $args {
            if {[file isdirectory $i]} continue
            if {0 && ![file readable $i]} {
                tclLog "skip non-existant file: $i"
                continue
            }
            lappend lst $i
            if {[llength $lst]>60} break
        }
        if {[llength $lst]>0} {
            File::Open  $_ [lindex $lst 0]
            if {$(-find) != {}} {
                set w $(curwin)
                set ind [Text search $w $(-find) 1.0]
                if {$ind != {}} {
                    Text mark set $w insert $ind
                    Text see $w insert
                }
            }
        }
        set n 0
        foreach i [lrange $lst 1 end] {
            File::Tab $_ $i
            if {([incr n]%7) == 0} update
        }
        Tabset see $ts focus
        set (v,status) "Loaded [llength $args] files: $args"
    }
    
    Tk::gui create { include geditor.gui }
    
}

