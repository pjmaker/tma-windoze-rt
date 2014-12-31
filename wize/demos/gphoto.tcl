#!/usr/bin/env wize
# A photo viewer.
#TODO: Preload next image to speed sequential viewing (like gqview).
#
# BSD copyright 2008 - Peter MacDonald - http://pdqi.com
# RCS: @(#) $Id: gphoto.tcl,v 1.16 2010/04/30 16:42:30 pcmacdon Exp $

package require Gui

namespace eval ::app::gphoto {

    Mod export
    
    variable _
    declare pc Array
    set pc(exts:photo) {.gif .jpg .jpeg .png  pnm .pgm .ppm .xpm .xbm .tif .tiff}
    
    array set _ {
        guiobj {} findpos 1.0 curwin {} curfile {} wrap True
        widx 0  -dir {} cur {} inupdir 0 status {} subdir {}
        locbar True butpath True statusline True viewmode Detail-List
        iconsview 1 iconcols 4 iwidth 48 iheight 48 cimgind {}
        sel:x {} sel:y {} sel:id {} sel:area {}
        cur:file {} cur:image {} menu:top {}
        after:selchg {}
        mkthumb {} thumbexternal False filter none
        imgfileexts {*.jpg *.jpeg *.JPG *.JPEG} imgextraexts {}
        usefullimage 0 usethumbnails 0
        
    }
    set _(thumbdirs) { .thumb .thumbnails }

    array set pc { widx 0}
    set pc(timefmt) {%y-%m-%d %T}

    set pc(icols) {Size Modified}
    if {$::tcl_platform(platform) == "unix"} {
        set pc(cols) {Size Modified Owner Group Perms Type}
    } else {
        set pc(cols) {Size Modified Type}
    }

    namespace eval Help {
        
        proc Ok {_} {
            # Handle dialog Ok button.
            upvar $_ {}
            Tk::gui dialogclose $_
        }
    }
    
    proc LoadThumbSub {_} {
        # Load the tree with directory contents.
        upvar $_ {}
        variable pc
        set md $(-dir)
        set t $(w,listview)
        set exts [concat $(imgfileexts) $(imgextraexts)]
        set lst [eval [list glob -nocomplain -directory $(-dir)] $exts]
        set lst [lsort -dictionary $lst]
        foreach i $lst {
            if {[file isdirectory $i]} continue
            set ext [string tolower [file extension $i]]
            if {[lsearch $pc(exts:photo) $ext]<0} continue
            set it [file tail $i]
            set img {}
            foreach sub $(thumbdirs) {
                set tfile [file join $(-dir) $sub $it.png]
                if {[file exists $tfile]} {
                    if {![catch {image create photo -file $tfile} img]} break
                }
            }
            set ee {}
            if {$img == {} || [catch {image width $img} ee]} {
                set img [image create photo -width $(iwidth) -height $(iheight)]
            }
            set d [list Size [file size $i] Modified [clock format [file mtime $i] -format $pc(timefmt)]]
            TreeView insert $t end $it -icons [list $img] -data $d
        }
    }
    
    proc MakeThumb {_ file outfile} {
        upvar $_ {}
        if {$(thumbexternal)} {
            set var ${_}(mkthumb)
            bgexec $var convert -scale $(iwidth)x$(iheight) $file $outfile
        } else {
            set img [image create photo -file $file]
            set nimg [image create photo -width $(iwidth) -height $(iheight)]
            winop image resample $img $nimg
            photos write $nimg $outfile -format gif
            image delete $img
            image delete $nimg
        }
    }
    
    proc LoadThumb {_} {
        upvar $_ {}
        busy hold $(w,.)
        after idle [list busy release $(w,.)]
        update
        set t $(w,listview)
        foreach i [TreeView find $t] {
            if {$i == 0} continue
            set imgs [TreeView entry cget $t $i -icons]
            foreach img $imgs {
                if {[catch {image delete $img} err]} {
                    .Warn "img delete: $err"
                }
                break
            }
            TreeView delete $t $i
        }
        LoadThumbSub $_
        if {[TreeView entry children $t 0] != {}} {
            after idle [list TreeView selection set $t top]
        }
    }
    
    proc Edit {f} {
        # Show file in editor.
        if {![file exists $f] || ![file isfile $f]} return
        ::Wiz::edit::new $f
    }
    
    proc LoadFile {_ fn {force 0}} {
        # Load image file into viewable area.
        upvar $_ {}
        variable pc
        if {$fn == $(cur:file) && !$force} return
        set c $(w,canview)
        set ci $(cimgind)
        set oldimg [Canvas itemcget $c $ci -image]
        busy hold $(w,.)
        update
        after idle [list busy release $(w,.)]
        set nimg [image create photo -file $fn]
        set (cur:file) $fn
        catch {image delete $(cur:image)}
        if {$oldimg != $(cur:image)} { image delete $oldimg }
        set (cur:image) $nimg
        set ow [image width $nimg]
        set oh [image height $nimg]
        set sw [winfo width $c]
        set sh [winfo height $c]
        Canvas yview moveto $c 0
        Canvas xview moveto $c 0
        Canvas conf $c -scrollregion {}
        if {($ow <= $sw && $oh <= $sh)} {
            # Image fits window.
            Canvas itemconf $c $ci -image $nimg
        } elseif {$(usefullimage)} {
            Canvas itemconf $c $ci -image $nimg
            Canvas conf $c -scrollregion [list 0 0 $ow $oh]
        } else {
            # Scale image to canvas.
            set ssw [expr {1.0*$sw/$ow}]
            set ssh [expr {1.0*$sh/$oh}]
            if {$ssw<$ssh} {
                set sh [expr {int($ssw*$oh)}]
            } else {
                set sw [expr {int($ssh*$ow)}]
            }
            set nimg2 [image create photo -width $sw -height $sh]
            winop image resample $nimg $nimg2 $(filter)
            Canvas itemconf $c $ci -image $nimg2
        }
        set tim "modified=[clock format [file mtime $fn] -format  $pc(timefmt)]"
        set siz "size=[file size $fn] bytes"
        set (v,status) "file=[file tail $fn], geom=${ow}x$oh, $siz, $tim"
    }
    
    proc Reload {_} {
        upvar $_ {}
        LoadFile $_ $(cur:file) 1
    }
    
    proc MenuHide {_} {
        upvar $_ {}
        set w $(w,.)
        if {[set m [Toplevel cget $w -menu]] == {}} {
            set m $(menu:top)
        } else {
            set (menu:top) $m
            set m {}
        }
        Toplevel conf $w -menu $m
    }
    
    proc CanvOp {_ op} {
        # Handle scrolling if required.
        upvar $_ {}
        set c $(w,canview)
        if {[Canvas cget $c -scrollregion] == {}} return
        switch -- $op {
            Down { Canvas yview scroll $c 1 unit }
            Up { Canvas yview scroll $c -1 unit }
            Right { Canvas xview scroll $c 1 unit }
            Left { Canvas xview scroll $c -1 unit }
            Next { Canvas yview scroll $c 1 page }
            Prior { Canvas yview scroll $c -1 page }
        }
    }
    
    proc Select {_ id} {
        # Handler for double-click selection.
        upvar $_ {}
        set t $(w,listview)
        set idx [TreeView index $t $id]
        if {$idx == {}} return
        set f [TreeView get $t -full $idx]
        set fn [file join $(-dir) $f]
        LoadFile $_ $fn 1
        TreeView toggle $t $idx
        #$t toggle $idx
        TreeView selection clearall $t
        TreeView selection set $t $idx
    }

    proc SelArea {_ c op x y args} {
        # Show rubberband area selection.
        upvar $_ {}
        switch -- $op {
            begin {
                set (sel:x) $x
                set (sel:y) $y
                bind $c <B1-Motion> [list $_ SelArea $c move %x %y]
                if {$(sel:id) != {}} {
                    Canvas delete $c $(sel:id)
                    set (sel:id) {}
                }
                focus $c
            }
            end {
                bind $c <B1-Motion> {}
            }
            move {
                if {$(sel:id) == {}} {
                    set (sel:id) [Canvas create rectangle $c {0 0 0 0}]
                }
                set cc [list [$c canvasx $(sel:x)] [$c canvasy $(sel:y)] [$c canvasx $x] [$c canvasy $y]]
                set (sel:area) $cc; #[list $(sel:x) $(sel:y) $x $y]
                Canvas coords $c $(sel:id)  $cc
            }
        }
    }
    
    proc SelectChg {_} {
        # Handle a selection change
        upvar $_ {}
        set t $(w,listview)
        set cur [TreeView curselection $t]
        if {$cur == {}} return
        set val [TreeView get $t [lindex $cur 0]]
        set fn [file join $(-dir) $val]
        $_ LoadFile $fn
    }
    
    proc SchedSelChg {_} {
        # Eventually handle selection change.
        upvar $_ {}
        catch {after cancel $(after:selchg)}
        set (after:selchg) [after 70 [list $_ SelectChg]]
    }

    namespace eval File {
        
        Mod upvars _
        namespace path [namespace parent]
        
        proc Code {_} {
            upvar $_ {}
            upvar [namespace parent]::pd pd
            Wiz::edit::new $pd(script)
        }

        proc Console {_} {
            upvar $_ {}
            console show
        }
        
        proc Quit {_} {
            Delete $_
        }
        
        proc Open {_} {
            # Open a new directory.
            upvar $_ {}
            set dir [tk_chooseDirectory -initialdir $(-dir)]
            if {$dir == {}} return
            set (-dir) $dir
            $_ LoadThumb
        }

        proc New {_} {
            # Start a new manager.
            upvar $_ {}
            ::New [namespace parent] -dir $(-dir)
        }
        
        proc Save {_} {
            upvar $_ {}
            set fn [tk_getSaveFile -initialdir $(-dir) -initialfile [file tail $(cur:file)]]
            if {$fn == {}} return
            set img [Canvas itemcget $(w,canview) $(cimgind) -image]
            
            set fmt [string trim [file extension $fn] .]
            photos write $img $fn -format $fmt
        }
    }


    namespace eval Image {
        
        Mod upvars _
        
        proc Rotate {_ {angle {}} {inplace 0}} {
            # Rotate the image.
            upvar $_ {}
            set c $(w,canview)
            if {$angle == {}} {
                set angle [Tk::getInput -title "Rotation" -text "Angle to rotate"]
                if {$angle == {}} return
            }
            set angle [expr {int(-$angle)}]
            set img [Canvas itemcget $c $(cimgind) -image]
            if {($angle%90) == 0 || $inplace} {
                winop image rotate $img $img $angle
                set nimg $img
            } else {
                set nimg [image create photo]
                winop image rotate $img $nimg $angle
                Canvas itemconf $c $(cimgind) -image $nimg
                image delete $img
            }
            set nw [image width $nimg]
            set nh [image height $nimg]
            Canvas conf $c -scrollregion [list 0 0 $nw $nh]
        }
        
        proc Rotate-90 {_} { Rotate $_ 90 }
        proc Rotate-180 {_} { Rotate $_ 180 }
        proc Rotate-270 {_} { Rotate $_ 270 }

        proc Flip-XY {_} {
            # Flip image on X and Y axis.
            upvar $_ {}
            set img [Canvas itemcget $(w,canview) $(cimgind) -image]
            winop image mirror $img $img
        }

        proc Flip-X {_} {
            # Flip image on X axis.
            upvar $_ {}
            set img [Canvas itemcget $(w,canview) $(cimgind) -image]
            winop image mirror $img $img x
        }

        proc Flip-Y {_} {
            # Flip image on Y axis.
            upvar $_ {}
            set img [Canvas itemcget $(w,canview) $(cimgind) -image]
            winop image mirror $img $img y
        }

        proc Crop {_} {
            # Crop image to selected area.
            upvar $_ {}
            if {$(sel:area) == {}} {
                return [tk_messageBox -message [mc "must select area"]]
            }
            foreach {cx1 cy1 cx2 cy2} $(sel:area) break
            set c $(w,canview)
            set cind $(cimgind)
            set img [Canvas itemcget $(w,canview) $cind -image]
            set sx [expr {1.0*[image width $(cur:image)]/[image width $img]}]
            set sy [expr {1.0*[image height $(cur:image)]/[image height $img]}]
            set x [expr {int($cx1*$sx)}]
            set y [expr {int($cy1*$sy)}]
            set width [expr {int(abs($cx2-$cx1+1)*$sx)}]
            set height [expr {int(abs($cy2-$cy1+1)*$sy)}]
            if {$width<5 || $height <5} return
            set img2 [image create photo]
            winop image subsample $(cur:image) $img2 $x $y $width $height
            Canvas itemconf $c $cind -image $img2
            if {$(sel:id) != {}} {
                Canvas delete $c $(sel:id)
                set (sel:id) {}
            }
            image delete $img
            Canvas yview moveto $c 0
            Canvas xview moveto $c 0
            Canvas conf $c -scrollregion [list 0 0 $width $height]
        }
        
        proc Reload {_} {
            # Reload image.
            $_ Reload
        }
        
        proc Filter {_} {
            # Set filter used for scaled images.
            Reload $_
        }
        
        proc Full-Image {_} {
            # Display image in 1:1 scale.
            Reload $_
        }
        
        proc Thumbnails {_} {
            # Display thumbnail images.
            upvar $_ {}
            TreeView conf $(w,listview) -hideicons [expr {!$(usethumbnails)}]
        }
            
    }
    
    proc Main {_ args} {
        # Instantiate file manager.
        upvar $_ {}
        variable pc

        #set dt $(w,dirtree)
        set (-dir) [lindex $args 0]
        if {$(-dir) == {}} {
            set (-dir) [pwd]
        }
        set (subdir) {}
        set w $(w,.)
        set (w,canview) $(w,canview) 
        set (w,listview) $(w,listview)
        set c $(w,canview) 
        set l $(w,listview)
        set app [namespace tail [namespace current]]
        wm title $w "$app: $(-dir)"
        TreeView column conf $l 0 -title [mc File]
        styles item $l column 0
        foreach i $pc(icols) {
            TreeView column insert $l end $i -justify left -title [mc $i]
            styles item $l column $i
        }
        
        eval TreeView column conf $l [TreeView column names $l] {-command {blt::tv::SortColumn %W %C}}
        TreeView conf $l -selectcommand [list $_ SchedSelChg] -opencommand [list $_ Select %#]

        set img [image create photo]
        set (cur:image) [image create photo]
        set (cimgind) [Canvas create image $c "0 0" -anchor nw -image $img]
        if {!$(usethumbnails)} {
            TreeView conf $l -hideicons 1
        }
        LoadThumb $_
        bind $l <3> {%W nearest %x %y xx; tclLog $::xx}
    }
    

    Tk::gui create {
        style {
            Toplevel  { *Scrollbar.width 10 }
            TreeView {
                -bg White -nofocusselectbackground #085D8B
                -selectbackground #085D8B -selectrelief raised
                -selectborder 1 -selectforeground White
                -nofocusselectforeground White
            }
            TreeView::column { -relief raised -bd 1 }
            TreeView::column::Size -
            TreeView::column::Perms { -justify right }
            .canview {
                @bind {
                    <3> !submen1
                    <ButtonPress-1>   {%_ SelArea %W begin %x %y}
                    <ButtonRelease-1> {%_ SelArea %W end   %x %y}
                    <Alt-m> {%_ MenuHide}
                    {<Down> <Up> <Left> <Right> <Prior> <Next>} {%_ CanvOp %K}
                }
                @relay {
                    .listview {<Control-n> <Control-p> {<space> <Down>} {<BackSpace> <Up>}}
                }
            }
            .listview {
                -linespacing 2 -width 65 -flat 1
                @eval {
                    %W style create textbox alt -bg LightBlue
                }
                -altstyle alt

            }
        }
    
        {Toplevel + -id about -ns Help -title "About Gphoto"} {
            
            style {
                Toplevel { *background SteelBlue }
                Button { -bg LightBlue }
                Label  { -font {Courier -20 bold italic underline}}
                .frame* { -bg Purple }
            }
            {Frame + -matte 10} {
                {Frame + -matte 10} {
                    Label "BSD Copyright 2008\nPeter MacDonald"
                }
                {Button - -id ok -focus 1} Ok
            }
        }
        
        {Toplevel + -title "GPhoto" -geom 800x600} {
            # "The main Menu."
            {Menu + -label Main} {
                {menu + -label File -ns File} {
                    x Open
                    x New
                    x Save
                    sep {}
                    x Quit
                }
                        
                {menu +  -label Help -ns File } {
                    {x - -msg !about} About
                    x Console
                    x Code
                }
            }
            
            {Menu +  -id submen1  -ns Image  -pos ^} {
                {menu + -label Rotate} {
                    x Rotate-90
                    x Rotate-180
                    x Rotate-270
                    x Rotate
                }
                {menu + -label Flip} {
                    x Flip-X
                    x Flip-Y
                    x Flip-XY
                }
                {menu + -label Filter -subattr {-msg Filter -var (filter)}} {
                    r none
                    r bell
                    r bessel
                    r box
                    r bspline
                    r catrom
                    r default
                    r dummy
                    r gauss8
                    r gaussian
                    r gi
                    r lanczos3
                    r mitchell
                    r sinc
                    r triangle
                }
                x Crop
                {c - -var (usefullimage)} Full-Image
                {c - -var (usethumbnails)} Thumbnails
                x Reload
            }
                
            {statusbar - -id statusbar -ids {statusln status} -widths {8}} {}
            {Frame + -pos *} {
                {Panedwindow + -pos *} {
                    {pane + -pos * -width 4c} {
                        {TreeView - -id listview -pos * -scroll * -focus 1} {}
                    }
                    {pane + -pos *} {
                        {Canvas - -id canview -pos l* -scroll *} {}
                    }
                }
            }
        }
    }
    
}



