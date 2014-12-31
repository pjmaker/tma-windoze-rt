#!/usr/bin/env wize

# Edit a tree in a dual-treeview display.
# This is used by Mod utils [*tree view].
#
# BSD copyright 2009 - Peter MacDonald - http://pdqi.com
# RCS: @(#) $Id: edittree.tcl,v 1.3 2010/04/30 16:42:30 pcmacdon Exp $

package require Gui

namespace eval ::app::edittree {
    
    variable Opts {
        { -tree     {}  "Tree to display" }
    }
    
    proc SelTree {_ id} {
        # Handle tree node selection.
        upvar $_ {}
        set w $(w,tv)
        set d $(w,td)
        set t [TreeView cget $w -tree]
        set id [TreeView index $w $id]
        if {$id == {}} return
        TreeView delete $d all
        set sc {blt::tv::SortColumn %W %C}
        if {![TreeView tag exists $w _array $id]} {
            # Non-array.
            TreeView column conf $d #0 -hide 1
            eval $d column delete [$d column names]
            foreach i {Name Value} {
                TreeView column insert $d end $i -justify left -relief raised -bd 1 -command $sc
            }
            TreeView column conf $d Value -edit 1
            foreach {i j} [$t get $id] {
                TreeView insert $d end #auto -data [list Name $i Value $j]
            }
            return
        }
        # An array.
        TreeView column conf $d #0 -hide 0
        eval $d column delete [$d column names]
        set keys [lsort -dictionary [$t names $id]]
        if {$keys == {}} return
        foreach k $keys {
            set did [TreeView insert $d end $k]
            set dd [$t get $id $k]
            if {![catch { TreeView entry conf $d $did -data $dd }]} continue
            foreach i [lsort -dictionary [$t names $id $k]] {
                catch { TreeView column insert $d end $i -justify left -relief raised -bd 1 -edit 1 -command $sc}
            }
            TreeView entry conf $d $did -data $dd 
        }

    }
    
    proc EditOpt {_ cind ind} {
        # Handle edit completion.
        upvar $_ {}
        set d $(w,td)
        set w $(w,tv)
        set t [TreeView cget $w -tree]
        #set ind [TreeView index $d focus]
        set tind [TreeView index $w focus]
        if {![TreeView tag exists $w _array $tind]} {
            set val [TreeView entry set $d $ind Value]
            set nam [TreeView entry set $d $ind Name]
            $t update $tind $nam $val
            return
        }
        set nam [TreeView get $d $ind]
        set cnam [lindex [TreeView column names $d] $cind]
        set val [TreeView entry set $d $ind $cnam]
        $t update $tind ${nam}($cnam) $val
        
    }
    
    proc Main {_ args} {
        upvar $_ {}
        set w $(w,tv)
        set d $(w,td)
        if {[set t $(-tree)] == {}} {
            set t [tree create]
        }
        TreeView conf $w -tree $t -hideroot 0
        TreeView column conf $w #0 -title Node
        $t tag add _array root
        #$t label root ROOT
        TreeView entry conf $w 0 -label ROOT
        TreeView open $w all
        set sc {blt::tv::SortColumn %W %C}
        TreeView column conf $d #0 -hide 1 -relief raised -bd 1 -title Element -command $sc
        TreeView conf $d -flat 1
        set gb [images lookup $(w,.) arr]
        foreach i [TreeView tag nodes $w _array] {
            $w entry conf $i -icon $gb
        }
        bind $w <<TreeViewFocusEvent>> [list $_ SelTree focus]
        bind $d <<TreeViewEditEnd>> [list $_ EditOpt %x %y]
    }
    
    Tk::gui create {
        
        {style} {
            Toplevel {
                @defimages {
                    grnb greenball
                    arr  viewtree
                }
            }
            Panedwindow { -showhandle 0 }
            TreeView {
                -bg white -underline 1 @eval {
                    %W style create textbox alt -bg LightBlue
                }
                -altstyle alt
                -icon ^grnb
                -selectbackground #085d8c    -selectforeground White
                -nofocusselectbackground #085d8c   -nofocusselectforeground White
            }
            .td {
                -icon ^arr
            }
            TreeView::column { -relief raised -bd 1 }
        }
        
        {Toplevel +} {
            {Panedwindow + -pos *} {
                {pane +} {
                    {TreeView - -id tv -scroll * -pos *l} {}
                }
                {pane +} {
                    {TreeView - -id td -scroll * -pos *l} {}
                }
            }
        }
    }
    
}
 


