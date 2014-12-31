#!/usr/bin/env wize

# A file manager.
#
# BSD copyright 2008 - Peter MacDonald - http://pdqi.com
# RCS: @(#) $Id: gexplore.tcl,v 1.17 2010/05/10 18:28:31 pcmacdon Exp $

package require Gui

namespace eval ::app::gexplore {

    #Mod export
    #Mod ndebug
    
    variable _
    variable pc
    variable pd
    set pd(script) [file normalize [info script]]
    set pd(dirname) [file dirname $pd(script)]
    variable icons
    variable iconmap { .zip archive .tcl program .htcl source_h [a-zA-Z].3 {contents contents2} .n {contents contents2}  .txt file .c source_c .h source_h .o source_o .so source_l .a source_l }
    set pc(exts:photo) {.gif .jpg .jpeg .png  pnm .pgm .ppm .xpm .xbm .tif .tiff}
    foreach pc(i) $pc(exts:photo) {
        lappend iconmap $pc(i) icons
    }
    variable iconmapa
    array set iconmapa $iconmap
    
    array set _ {
        guiobj {} findpos 1.0 curwin {} curfile {} wrap True iconside top
        widx 0  -root {} cur {} inupdir 0 status {} subdir {}
        locbar 1 butpath 0 statusline 1 viewmode Icon-View
        iconsview 1 iconcols 4 dirtype {}
        w1:userid doorknob w1:password frick after:busy {}
        wraplen 12
    }

    array set pc { widx 0}
    set pc(icondir) /zvfs/img/misc16
    set pc(icdir) /usr/share/icons/slick/32x32/filesystems
    set pc(timefmt) {%y-%m-%d %T}
    
    if {$::tcl_platform(platform) == "unix"} {
        set pc(cols) {Size Modified Owner Group Perm Type}
    } else {
        set pc(cols) {Size Modified Type}
    }

    #if {[info commands ::app::edit::new] == {}} {
    #    source /zvfs/wiz/edit.tcl
    #}
    set pc(filetypes:zip) {
        {WizPak  {.zip .wiz .ZIP .WIZ}}
    }
    
    set pc(filetypes:tcl) {
        {Tcl {.tcl .tk}}
        {All *}
    }
    
    set pc(filetypes:all) {
        {All *}
        {Tcl {.tcl .tk}}
        {WizPak  {.zip .wiz .ZIP .WIZ}}
    }
    set pc(filetypes:zall) {
        {WizPak  {.zip .wiz .ZIP .WIZ}}
        {All *}
    }
    
    ################# Start of Code ####################
    
    extern new {args} {} "A ::New [namespace current]"

    proc subgui {_ args} {
        # Return gui obj, or eval gui subcommand.
        upvar $_ {}
        if {![llength $args]} { return $(guiobj) }
        eval $(guiobj) $args
    }
    
    proc Reload {_} {
        upvar $_ {}
    }
    proc Back {_} {
        # Go back to previous node.
        upvar $_ {}
    }
    proc Forward {_} {
        upvar $_ {}
    }
    proc Up {_} {
        upvar $_ {}
    }
    proc Props {_} {
        upvar $_ {}
    }
    
    proc Msg {_ msg args} {
        upvar $_ {}
        return [eval [list tk_messageBox -message $msg -parent $(w,.)] $args]
    }

    namespace eval Help {
        
        proc Ok {_} {
            # Handle dialog Ok button.
            upvar $_ {}
            Tk::gui dialogclose $_
        }
    }

    namespace eval Option {
        
        Mod upvars _ pc

        proc Ok {_} {
            # Handle dialog Ok button.
            upvar $_ {}
            Tk::gui dialogclose $_
        }
        
        proc Cancel {_} {
            # Handle dialog Ok button.
            upvar $_ {}
            Tk::gui dialogclose $_
        }
        
        proc Location-Bar {_} {
            # Toggle visibility of the location bar.
            upvar $_ {}
            gui win [expr {$(locbar)?"show":"hide"}] $(guiobj) locframes
        }
        
        proc Status-Line {_} {
            # Toggle visibility of the status line.
            upvar $_ {}
            gui win [expr {$(statusline)?"show":"hide"}] $(guiobj) statusbar
        }
        
        proc Button-Path {_} {
            # Toggle visibility of the button path.
            upvar $_ {}
            gui win [expr {$(butpath)?"show":"hide"}] $(guiobj) butframe
        }
        
        proc List-View {_} {
            # Set view to list mode.
            upvar $_ {}
            set t $(w,dirview)
            if {!$(iconsview)} return
            set (iconsview) 0
            $_ Reload
        }
        
        proc Icon-View {_} {
            # Set view to icons mode.
            upvar $_ {}
            if {$(iconsview)} return
            set (iconsview) 1
            $_ Reload
        }
        
    }
    
    
    namespace eval File {
        
        Mod upvars _ pc
                
        proc GetSels {_} {
            # Return list of selected values.
            upvar $_ {}
            set t $(w,dirview)
            set rc {}
            set smod [TreeView cget $t -selectmode]
            switch -- $smod {
                single - multiple {
                    set sels [TreeView curselection $t]
                    foreach i $sels {
                        set nam [TreeView get $t $i]
                        set f [file join $(subdir) $nam]
                        lappend rc $f
                    }
                    return $rc
                }
                cell - multicell {
                    set sels [TreeView selection cells $t]
                    foreach {r c} $sels {
                        set nam [TreeView entry set $t $r $c]
                        set f [file join $(subdir) $nam]
                        lappend rc $f
                    }
                    return $rc
                }
            }
        }

        proc Info {_} {
            upvar $_ {}
            set t $(w,dirview)
            foreach f [GetSels $_] {
                set (status) "[file tail $f] [file size $f] bytes"
            }
        }
        
        proc Code {_} {
            # Show source code.
            upvar $_ {}
            upvar [namespace parent]::pd pd
            ::Wiz::edit::new $pd(script)
        }

        proc Console {_} {
            upvar $_ {}
            console show
        }

        proc Rename {_} {
            upvar $_ {}
            set d $(subdir)
            foreach f [GetSels $_] {

                if {[set fn [tk_getSaveFile -initialdir $d -parent $(w,.) -title "New File Name"]] == {}} return
                file rename $f $fn
            }
            #set fe [string range $fn $l end]
            #if {$fe != {}} { TreeView insert $t end $fe -data [Data $_ $fe]}
            #TreeView delete $t $ind
        }
  
        proc Copy {_} {
            upvar $_ {}
            set d $(subdir)
            foreach f [GetSels $_] {
                if {[set fn [tk_getSaveFile -initialdir $d -parent $(w,.) -title "New File Name"]] == {}} return
                file copy $f $fn
            }
        }


        proc Delete {_} {
            upvar $_ {}
            foreach f [GetSels $_] {
                #file delete $f
            }
        }

        proc Open-With {_} {
            upvar $_ {}
        }
      
        proc Edit {_} {
            upvar $_ {}
            set t $(w,dirview)
            foreach f [GetSels $_] {
                if {[file size $f]>100000} {
                    $_ Msg "[mc {too large}]: $f"
                    continue
                }
                ::Wiz::edit::new $f
            }
        }

        proc Icons {_} {
            upvar $_ {}
            foreach f [GetSels $_] {
                set acmd Wiz::icons::new
                if {![file isdirectory $f]} { set f [file dirname $f]}
                $acmd $f
            }
        }

        proc Exec {_} {
            # Execute the file.
            upvar $_ {}
            set t $(w,dirview)
            foreach f [GetSels $_] {
                if {![file executable $f]} {
                    $_ Msg "[mc {File not executable}]: $f"
                    continue
                }
                set opts [Tk::getInput -text [mc Arguments] -title [mc "Run arguments"]]
                set cmd [concat [list exec $f] $opts &]
                eval $cmd
            }
        }
    

        proc Open {_} {
            upvar $_ {}
        }
      
        proc Quit {_} {
            # Quit the application.
            upvar $_ {}
            ::Delete $_
        }
        
    }
    
    proc Pathtop {_} {
        upvar $_ {}
    }
    
    proc Icon {mapname} {
        # Return image for name mapped from file extension to iconmap.
        variable pc
        variable icons
        set fs $mapname
        if {[info exists icons($fs)]} { return $icons($fs) }
        if {![file isdirectory $pc(icondir)]} return
        set icons($fs) {}
        foreach f $fs {
            if {[file exists [set ff $pc(icondir)/$f.gif]]} {
                set img [image create photo -file $ff]
            } else {
                set img {}
            }
            lappend icons($fs) $img
        }
        return $img
    }
    
    proc BusyWindow {_ {start 0}} {
        upvar $_ {}
        if {$start} {
            busy hold $(w,.)
            update
            set (after:busy) [after 60000 [list busy release $(w,.)]]
        } else {
            catch {after cancel $(after:busy)}
            busy release $(w,.)
        }
    }

    proc IconNamed {file} {
        # Return image for name mapped from file extension.
        variable pc
        variable icons
        variable iconmap
        variable iconmapa
        if {[file isdirectory $file]} { return blt::tv::normalOpenFolder }
        set ext [file extension $file]
        foreach i [array names iconmapa *$ext] {
            set fs $iconmapa($i)
        }
        if {![info exists fs]} {
            return
        }
        #.Msg "FS($file): $fs"
        if {[info exists icons($fs)]} { return [lindex $icons($fs) 0] }
        if {![file isdirectory $pc(icondir)]} return
        set icons($fs) {}
        foreach f $fs {
            if {[file exists [set ff $pc(icondir)/$f.gif]]} {
                set img [image create photo -file $ff]
                break
            } else {
                set img {}
            }
            lappend icons($fs) $img
        }
        return $img
    }
    
    proc Data {_ f {prefix {}}} {
        upvar $_ {}
        variable pc
        if {$prefix == {}} {
            set prefix $(-root)
        }
        if {[string match /* $f]} { set f [string range $f 1 end] }
        set fn [file join $prefix $f]
        if {[catch {file lstat $fn x} err] || [catch { file attributes $fn} attr]} {
            #tclLog "stat error: $fn" 
            return
        }
        set lst {}
        lappend lst Size $x(size)
        array set a $attr
        if {$::tcl_platform(platform) == "unix"} {
            lappend lst Owner $a(-owner)
            lappend lst Group $a(-group)
            lappend lst Perm $a(-permissions)
        }
        lappend lst Type [file type $fn]
        lappend lst Modified [clock format $x(mtime) -format $pc(timefmt)]
        return $lst
    }

    proc FmtStr {_ str {len {}}} {
        # Wrap long labels.
        upvar $_ {}
        if {$len == {}} {
            set len $(wraplen)
        }
        if {[string length $str]<=$len} {
            return $str
        }
        set lm [expr {$len-1}]
        set rc {}
        while {[string length $str]>0} {
            append rc [string range $str 0 $lm]
            set str [string range $str $len end]
            if {$str != {}} { append rc \n }
        }
        return $rc   
    }
        
    proc FmtString {_ str {len {}} {class alnum}} {
        # Wrap long string names at word boundries.
        upvar $_ {}
        if {$len == {}} {
            set len $(wraplen)
        }
        if {[string length $str]<=$len} {
            return $str
        }
        if {[string is $class $str]} {
            return [FmtStr $_ $str $len]
        }
        set rc {}
        set crc {}
        set lw 1
        foreach i [split $str {}] {
            set isw [string is $class $i]
            if {(($isw && $lw) || (!$isw && !$lw)) && [string length $crc]<$len} {
                append crc $i
            } else {
                lappend rc $crc
                set crc $i
            }
            set lw $isw
        }
        if {$crc != {}} {
            lappend rc $crc
        }
        set src {}
        set cln {}
        foreach i $rc {
            if {[string length $cln$i]<=$len} {
                append cln $i
            } else {
                if {$src != {}} { append src \n }
                append src $cln
                set cln $i
            }
        }
        append src \n $cln
        return $src   
    }
        
    proc LoadDirSub {_ path args} {
        # Load the tree with directory contents.
        upvar $_ {}
        variable icons
        variable iconmap
        Opts p $args {
            { -nav  0   "Navigation window" }
        }
        BusyWindow $_ 1
        if {!$p(-nav)} {
            set t $(w,dirview)
            set prefix $(subdir)
        } else {
            set t $(w,navview)
            set prefix $(-root)
        }
        #.Msg "LL($path): $left, $t "
        set l [string length $prefix]
        set lst [lsort -dictionary [glob -nocomplain -directory $path *]]
        set alst {}
        set dlst {}
        foreach i $lst {
            if {[file isdirectory $i]} {
                lappend dlst $i 1
            } else {
                lappend alst $i 0
            }
        }
        if {$p(-nav)} {
            set lst $dlst
        } else {
            set lst [concat $dlst $alst]
        }
        foreach {i isdir} $lst {
            #set it [file tail $i]
            set it [string range $i $l end]
            set d [Data $_ $it $prefix]
            TreeView insert $t end $it -forcetree $isdir -data $d
        }
        foreach {ext ic} $iconmap {
            set img [Icon $ic]
            if {$img == {}} continue
            # tclLog "IMG($prefix): $ic, $ext"
            foreach i [TreeView find $t -usepath -name *$ext -glob] {
                TreeView entry conf $t $i -icons $img -activeicons $img
            }
        }
        if {!$p(-nav)} {
            set (v,pathtop) [file tail $path]
        }
        BusyWindow $_
    }
    
    proc LoadIconView {_ path} {
        upvar $_ {}
        variable icons
        variable iconmap
        BusyWindow $_ 1
        set t $(w,dirview)
        foreach i [TreeView find $t] {
            TreeView delete $t $i
        }
        set prefix $(subdir)
        set l [string length $prefix]
        set lst [lsort -dictionary [glob -nocomplain -directory $path *]]
        set alst {}
        set dlst {}
        foreach i $lst {
            if {[file isdirectory $i]} {
                lappend dlst $i
            } else {
                lappend alst $i
            }
        }
        set lst [concat $dlst $alst]
        set ic $(iconcols)
        set m 0
        set n 0
        set d {}
        set stylst {}
        set stys [TreeView style names $t]
        foreach i $lst {
            #set it [string range $i $l end]
            set it [file tail $i]
            incr n
            if {([incr m]%2000) == 0} { update }
            set img [IconNamed $i]
            if {$img != {}} {
                if {[lsearch $stys $img]<0} {
                    TreeView style create textbox $t $img -icon $img -iconside $(iconside)  -formatcmd [list $_ FmtString %V]
                    lappend stys $img
                }
                lappend stylst c$n $img
            }
            lappend d c$n $it
            if {$n>=$ic} {
                TreeView insert $t end #auto -styles $stylst -data $d
                set n 0
                set d {}
                set stylst {}
            }
        }
        if {$d != {}} {
            TreeView insert $t end #auto -styles $stylst -data $d
        }
        set (v,location) [file normalize $path]
        BusyWindow $_
    }
    
    proc SetupTree {_ type} { #TYPES: . _ {choice icons list}
        # Setup columned view for files.
        upvar $_ {}
        variable pc
        set t $(w,dirview)
        if {$type == $(dirtype)} return
        set (dirtype) $type
        foreach i [TreeView column names $t] {
            TreeView column delete $t $i
        }
        switch -- $type {
            icons {
                set n 0
                while {[incr n]<=$(iconcols)} {
                    TreeView column insert $t end c$n -bd 0 -relief raised
                }
                TreeView style conf $t text -icon blt::tv::normalFile -side top -formatcmd [list $_ FmtString %V]
                TreeView column conf $t #0 -hide 1
                TreeView conf $t -underline 0 -fillnull 0 -showtitles 0 -selectmode multicell -altstyle {} -linespacing 5
            }
            list {
                TreeView conf $t -underline 1 -showtitles 1 -selectmode single -altstyle alt
                foreach i $pc(cols) {
                    TreeView column insert $t end $i -justify left -title [mc $i]
                    styles item $t column $i
                }
            }
        }
    }
        
    proc LoadDir {_ path {nav 0}} {
        # 
        upvar $_ {}
        set t $(w,dirview)
        if {!$nav} {
            SetupTree $_ [expr {$(iconsview)?"icons":"list"}]
        }
        if {$(iconsview) && !$nav} {
            LoadIconView $_ $path
        } else {
            LoadDirSub $_ $path -nav $nav
        }
    }
    
    proc LoadNav {_ path} {
        # 
        upvar $_ {}
        set t $(w,dirview)
        LoadDirSub $_ $path -nav 1
    }
    
    proc LocChg {_} {
        # Location of currently displayed path.
        # Handles return hit in location bar.
        upvar $_ {}
        set dir $(v,location)
        if {![file isdirectory $dir]} {
            $_ Msg "[mc {Unknown directory}]: $dir"
            return
        }
        set dir [file normalize $dir]
        LoadDir $_ $dir
        set (v,location) $dir
    }
    
    proc Edit {f} {
        # Edit the file.
        if {![file exists $f] || ![file isfile $f]} return
        ::Wiz::edit::new $f
    }

    proc Go {f} {
        variable pc
        switch -- [set fext [file extension $f]] {
            .3 - .n {
                if {![catch {::lib manview show $f} err]} return
                tclLog "BADL: $err"
            }
            .tht {
                if {![catch {::lib docview show -file $f} err]} return
                tclLog "BADL: $err"
            }
            .zip {
                set mnt [Wiz::zmount $f]
                new $mnt
                return
            }
            default {
                if {[lsearch $pc(exts:photo) $fext]>=0} {
                    ::app icons::new [file dirname $f]
                }
                return
            }
        }
        Edit $f

    }

    proc Updir {_} {
        # Go up and open the directory above.
        upvar $_ {}
        set t $(w,dirview)
        set newdir [file normalize [file join $(-root) ..]]
        if {[string equal $newdir $(-root)]} return
        set ui [TreeView index $t updir]
        foreach i [TreeView entry children $t root] {
            if {$i == $ui} continue
            TreeView move $t $i into updir
        }
        set old [lindex [file tail $(-root)] 0]
        set (-root) $newdir
        LoadDir $_ $newdir
        set dest [lindex [TreeView find $t -name $old] 0]
        wm title $(w,.) "Wiz File Manager: $(-root)"
        if {$dest == {}} return
        foreach i [TreeView entry children $t updir] {
            TreeView move $t $i into $dest
        }
        set (inupdir) 1
        TreeView open $t $dest
        set (inupdir) 0
    }
    
    proc OpenInd {_ ind} {
        # Handle tree selection.
        upvar $_ {}
        variable pc
    }
    
    proc OpenNavInd {_ ind} {
        # Handle tree selection in nav.
        upvar $_ {}
        variable pc
        if {$ind == 0} return
        if {$(inupdir)} return
        set t $(w,navview)
        set d $(w,dirview)
        TreeView entry activate $t $ind
        set path [TreeView get $t -full $ind]
        set arg [lindex [split $path /] 1]
        set lbl [TreeView entry cget $t $ind -label]
        set f [file join $(-root) $path]
        if {[file tail $f] == ".."} {
            Updir $_
            return
        }
        if {![file exists $f]} {
            # broken link
            return
        }
        LoadDir $_ $f
        set (status) "size=[file size $f] $f"
        if {[file isdirectory $f]} {
            if {[llength [set cl [TreeView entry children $t $ind]]] != 0} {
                # Reload of timestamp changed on directory.
                set mtime [file mtime $f]
                set otime [clock scan [TreeView entry set $t $ind Modified]]
                if {$otime == $mtime} {
                    return
                }
                TreeView entry set $t $ind Modified [clock format $mtime -format $pc(timefmt)]
                eval $t delete $cl
            }
            set (subdir) $f
            LoadNav $_ $f
            return
        }
        Go $f
    }
    
    proc MenuCmd {_ op} {
        upvar $_ {}
        variable pc
        set t $(w,dirview)
        set ind $(cur)
        if {$(iconsview)} {
            set p [TreeView get $t -full $ind]
        } else {
            set p [TreeView get $t -full $ind]
        }
        set f [file normalize [file join $(-root) $p]]
        set d [file dirname $f]
        set l [string length $(-root)]
        switch -- $op {
            Edit { Edit $f }
            Icons {
                set acmd app::icons::new
                if {![file isdirectory $f]} { set f [file dirname $f]}
                $acmd $f
            }
            Fileman {
                if {![file isdirectory $f]} { set f [file dirname $f]}
                new $f
            }
            Choose {
                if {![file isdirectory $f]} { set f [file dirname $f]}
                set f [tk_chooseDirectory -initialdir $f]
                if {$f == {}} return
                new $f
            }
            Exec {
                exec $f
            }
            Info {
                file lstat $f x
                set msg "$f\n"
                foreach i {size type uid gid dev nlink ino} {
                    append msg "[string totitle $i]:\t$x($i)\n"
                }
                append msg "Mode:\t[format %o $x(mode)]\n"
                foreach i {atime ctime mtime} {
                    append msg "[string totitle $i]:\t[ clock format $x($i) -format $pc(timefmt) ]\n"
                }
                Msg $_ $msg
            }
            Rename {
                if {[set fn [tk_getSaveFile -initialdir $d -parent $(w,.) -title "New File Name"]] == {}} return
                file rename $f $fn
                set fe [string range $fn $l end]
                if {$fe != {}} { TreeView insert $t end $fe -data [Data $_ $fe]}
                TreeView delete $t $ind
            }
            Copy {
                if {[set fn [tk_getSaveFile -initialdir $d -parent $(w,.) -title "New File Name"]] == {}} return
                file rename $f $fn
                set fe [string range $fn $l end]
                if {$fe != {}} { TreeView insert $t end $fe -data [Data $_ $fe]}
            }
            Delete {
                set s [Msg $_ "Ok to delete: $f" -type okcancel]
                if {$s != "ok"} return
                if {[catch {file delete $f} err]} {
                    if {[file normalize /] == $f} {error "invalid /"}
                    set s [Msg $_ "Ok to use delete -force: $f" -type okcancel -default cancel]
                    if {$s != "ok"} return
                    file delete $f
                }
                TreeView delete $t $ind
            }
            Code {
                # Show source code.
                variable pd
                ::Wiz::edit::new $pd(script)
            }
        }
    }
            
    proc Main {_ args} {
        # Instantiate file manager.
        upvar $_ {}
        variable pc

        set dt $(w,dirview)
        set alltbls [Tk::find $(w,.) * TreeView]
        foreach mwid $alltbls {
            TreeView style create textbox $mwid alt
            TreeView conf $mwid -altstyle alt
            styles item $mwid alt style::alt {style conf}
        }

        
        if {[set (-root) [lindex $args 0]] == {}} {
            set (-root) [pwd]
        }
        set w $(w,.)
        set t $(w,dirview)
        set l $(w,navview)
        set nics [list blt::tv::normalFile blt::tv::openFile]
        TreeView conf $t -leaficons $nics
        TreeView conf $l -leaficons $nics
        TreeView conf $t -separator / -autocreate 1 -opencommand [list $_ OpenInd %#]
        TreeView style conf $t text -iconside $(iconside)
        TreeView column conf $l #0 -title [mc File]
        styles item $l column #0
        styles item $t column #0
        foreach i $pc(cols) {
            TreeView column insert $l end $i -justify left -title [mc $i]
            styles item $l column $i
        }
        eval TreeView column conf $t [TreeView column names $t] {-command {blt::tv::SortColumn %W %C}}
        TreeView conf $t -flat 1
        TreeView conf $l -separator / -autocreate 1 -opencommand [list $_ OpenNavInd %#]

        set ind [TreeView insert $l end ..]
        TreeView tag add $t updir $ind
        wm title $w "gexplore: $(-root)"
        focus $t
        bind $(w,.) <Control-Alt-Insert> "console show"

        LoadNav $_ $(-root)
        #set (subdir) [TreeView get $l -full 2]
        #LoadDir $_ $(subdir)
    }
    
    Tk::gui create {
        style {
            Toplevel  {
                *Menu.compound left
                *Menu.imagePad 3
                *Menu.tearOff 0
                @defimages {
                    selimg chalk
                    plasma {blueplasma -gamma 5}
                    wallpap {blueweave -gamma 2}
                }
                @deffonts {
                    mainfnt {Verdana,Courier -12 bold}
                    dirfnt  {Verdana,Courier -12 bold underline}
                }
                @guiattrsmap {
                    -img {
                        back {back playrew}
                        forward {forward playfwd}
                        up {up goup}
                    }
                }
            }
            TreeView { -bg White -underline 1 -selectrelief raised -font ^mainfnt -selecttile ^selimg -selectborder 0}
            TreeView::column { -relief raised -borderwidth 1 -pad 5 -bd 1}
            TreeView::column::Size -
            TreeView::column::Perm { -justify right }
            TreeView::style::alt {
                -bg LightBlue
                #@style { .navview { -bg Aquamarine } }
            }
            Button { -pady 0 -padx 0 }
            Menu { -bd 2 -relief raised  -font ^mainfnt @style {
                .submen {
                    -tile ^plasma
                    @guiattrsmap {
                        -icon { Edit filenew }
                        -key { Edit <Alt-e> }
                    }
                }
                .file {
                    @guiattrsmap {
                        -icon { New {filenew fileopen} Save filesave Quit exit }
                        -key { Open <Alt-o> Quit <Alt-w> Save <Alt-s> } 
                    }
                }
                .option {
                    @guiattrsmap {
                        -icon { Location-Bar kfm_home View-Mode kpresenter Settings configure Button-Path koncd Status-Line checkbutton }
                        -key { Settings <Alt-c> } 
                    }
                }
            }}

            .dirview {
                -underline 1 -selectborder 1
                -font ^dirfnt 
                -tile ^wallpap -scrolltile 1
                @bind {  <3> !submen  <Control-s> Find }
            }
            .locframe { @pack {-padx 5} -bd 1 -relief ridge }
            .locimg { -bg White -bd 0 }
            .location { -bd 0 -font ^mainfnt }
            .locimg { @image foldernew }
            .xxback { @image back }
            .xxforward { @image forward }
            .xxup { @image up }
            .props { @image configure }

        }
    
        # "About help"
        {Toplevel + -id aboutdlg -ns Help -title "About Gexplore"} {
            style {
                Toplevel {
                    *background SteelBlue
                }
                Button {
                    -bg LightBlue -padx 5
                    @bind { <Return> <space> }
                }
                Label  { -font {Courier -20 bold italic} -fg White}
                .abpad { -pady 5 -bg White }
                .frame* { -bg White }
            }
            
            {Frame + -matte 10} {
                {Frame + -matte 10} {
                    Label "BSD Copyright 2008\nPeter MacDonald"
                }
                {Frame + -id abpad} {
                    {Button - -focus 1} Ok
                }
            }
        }
        
        {Toplevel + -id optdlg -ns Option -title "Gexplore Options"} {
            
            style {
            }
            {Tabset + -pos * -slant right } {
                {tab + -label Main -pos *} {
                    {Frame + -pos *l} {
                        {inputs - -prefix w1: -label Login2 -pos *} {
                            { userid     ""   "User ID" }
                            { password   ""   "User password" -opts {-bg lightblue -show *}}
                        }
                    }
                    {Frame + -pos *l} {
                        {inputs - -prefix w2: -label Login1 -pos *} {
                            { user     ""   "User ID" }
                            { password ""   "User password" -opts {-bg lightblue -show *}}
                        }
                        {inputs - -prefix w3: -label Login2 -pos *} {
                            { user     ""   "User ID" }
                            { password ""   "User password" -opts {-bg lightblue -show *}}
                        }
                    }
                }
                {tab + -label Colors -pos *} {
                    {Frame + -pos *l} {
                        {inputs - -prefix w4: -label Login2 -pos *} {
                            { user     ""   "User ID" }
                            { password ""   "User password" -opts {-bg lightblue -show *}}
                        }
                    }
                }
            }
            {Frame + -matte 2 -pos _ -subpos -l*/} {
                Button Ok Button Cancel
            }
        }
        
        {#Menu +  -id submen1  -ns File  -pos ^} {
            x Rename
        }
        
        {Menu +  -id submen  -label Gexp-Ops -ns File  -pos ^} {
            x Edit
            x Icons
            x Info
            x Exec
            sep {}
            x Rename 
            x Copy
            x Delete
        }
        
        {Toplevel + -title "Gexplore" -geom 800x600} {
            {Menu + -label Gexplore} {
                {menu + -label File -ns File } {
                    x Save
                    sep {}
                    x Quit
                }
            
                {menu + -label Option -ns Option} {
                    {c - -var (locbar)}    Location-Bar
                    {c - -var (butpath)}   Button-Path
                    {c - -var (statusline)}   Status-Line
                    {menu + -label View-Mode} {
                        {r - -var (viewmode)}    List-View
                        {r - -var (viewmode)}    Icon-View
                    
                    }
                    {x - -msg !optdlg} Settings
                }
            
                {menu +  -label Help -ns File } {
                    {x - -msg !aboutdlg} About
                    x Console
                    x Code
                }
            }

            # ########################################
            # "The main application window"
            {Frame + -pos *} {

                {Frame + -id locframes -subpos l -pos _} {
                    {Frame + -id navbuts -subpos *l -pos _l} {
                        {Button - -id back} Back
                        {Button - -id forward} Forward
                        {Button - -id up} Up
                        {hsep - -id sep1} {}
                        {Button - -id props} Props
                    }
                    {Frame + -id locframe -pos l*} {
                        {Label - -id locimg -pos l} {}
                        {Spinbox - -id location -msg LocChg -pos l*} {}
                    }
                }
                {Panedwindow + -pos *} {
                    {pane + -pos *} {
                        {Tabset + -id listts -pos *l} {
                            {tab + -id listtab} { 
                                {TreeView - -id navview -pos * -scroll *} {}
                            }

                        }
                    }
                    {pane + -pos *} {
                        {Frame + -id butframe -pos _ -hide 1} {
                            {Button - -id pathtop -msg Pathtop -pos l} /
                        }
                        {Frame + -id treeframe -pos *} {
                            {TreeView - -id dirview -pos * -scroll *} {}
                        }
                        {Frame + -id textframe -hide 1} {
                            {Text - -id textview -pos * -scroll *} {}
                        }
                        {Frame + -id canvframe -hide 1} {
                            {Text - -id canview -pos * -scroll *} {}
                        }
                    }
                }
                {statusbar - -id statusbar -ids {statusln status} -widths {8}} {}
            }
        }
    }
    
}

