#!/usr/bin/env wize

# Slider: A presentation application.

# BSD Copyright 2010 - PDQ Interfaces Inc.   (See http://pdqi.com/)
# RCS: @(#) $Id: slider.tcl,v 1.37 2010/05/17 00:14:00 pcmacdon Exp $

namespace eval slider {

    variable pc
    set pc(version) 1.0
    set pc(style) {}
    set pc(fontsave) {}
    set pc(icondirs) {/zvfs/img}
    set pc(fexts) {spf}

    set pc(ftypes) {
        {{Slider Files}       {.spf}        }
        {{All Files}        *             }
    }
    variable _
    array set _ {
        pages {} bimg {} bbimg {} bimgs {} npage -1 opage -1 tl {} file {} init 0
        after.fadein {}  after.fadeout {} widx 0   tidx 0   imglist {}   pages.text {}
        after.auto {}   after.unhide {}  fade.delay 200   fade.stop 0.2   fade.incr 0.2
        allopts {} lastgrad {} hdrright {} hdrimgright {} hdrleft {} hdrimgleft {}
        alleval {} gamma 1.0   dirname {}   zfile {}   zarc {}
        lasttile {}   hiding {} hidelvl 0
        unhide.delay 10

    }
    
    set Opts {
        { -auto         0       "Automatically flip slides every N seconds" }
        { -bulletfiles  {}      "Files for the 4 bullets" }
        { -fade         1       "Enable fading effect 1=in, 2=out, 3=out+in" }
        { -fontscale    0       "Scale fonts" }
        { -fontstk      False   "Scale Tk fonts as well" }
        { -full         False   "Start in fullscreen mode" }
        { -geom         {}      "Geometry to start with" }
        { -gradient {Steelblue White 1500 5} "Default inside gradient tile" }
        { -icondirs     {} "Directories containing images" }
        { -nosel        False "Disable selecton" }
        { -notcl        False "Ignore embedded Tcl scripts" }
        { -number       False "Number pages" }
        { -padx         20    "Pad x in text widget" }
        { -stop         False "Stop at end with -auto" }
    }
    
    set _(linemarkup) {^^ '' .t@@ %%}
    set _(mup) {{} n i b bi}
    set _(bullets) "+ * - ="
    set _(sizes) { 34 28 22 16 12}
    set pc(fonts) {
        title {Times 34}
        h1 {Times 34} h2 {Times 28} h3 {Times 22} h4 {Times 16}
        h5 {Times 12} pre {Courier 18 bold} body {Times 28}
        H1 {Times 34} H2 {Times 28} H3 {Times 22} H4 {Times 16}
        H5 {Times 12}
        header {Times 28} base {Courier 14} spc10 {Courier -6}}
    
    set _(tags) {}
    
    set _(alltags) {
        hr    { -font {Courier -2} -background Red }
        spc10 {  }
        title {-foreground DodgerBlue -justify center}
        h1    {}
        h2    {-lmargin1 20 -lmargin2 60}
        h3    {-lmargin1 60 -lmargin2 100}
        h4    {-lmargin1 100 -lmargin2 140}
        h5    {-lmargin1 140 -lmargin2 180}
        h2_i  { }
        body_i  {}
        body  {}
        pre   {-lmargin1 80 -lmargin2 80 -foreground Black }
        img   {-justify center}
        win   {-justify center}
        center { -justify center }
        header { -foreground Red }
        headtabs { -tabs " 500 center 1000 right" }
        
    }
    set pc(defimgs) {
        misc16/greenball.gif
        misc16/blueball.gif
        misc16/purpleball.gif
        misc16/redball.gif
    }
    
    
    proc Init {} {
        # Generate the tags with fonts.
        variable _
        variable pc
        array set A $_(alltags)
        foreach {i j} $pc(fonts) {
            #eval font create Slider-$i [font actual $j]
            foreach {fam siz} $j break
            font create Slider-$i -family $fam -size $siz
            foreach k [lrange $j 2 end] {
                switch -- $k {
                    bold { font conf Slider-$i -weight bold }
                    italic { font conf Slider-$i -slant italic }
                }
            }
            if {![info exists A($i)]} { set A($i) {} }
            lappend A($i) -font Slider-$i
            foreach l {b i bi} m {{-weight bold} {-slant italic} {-weight bold -slant italic}} {
                set tag ${i}_$l
                eval font create Slider-$tag [font actual $j] $m
                if {![info exists A($tag)]} { set A($tag) {} }
                lappend A($tag) -font Slider-$tag

            }
        }
        set rc {}
        foreach i [lsort [array names A]] {
            lappend rc $i $A($i)
        }
        set _(tags) $rc
    }
    eval Init
    
    proc resolve {_ file} {
        # Resolve file name in archive for external use.
        upvar $_ {}
        if {$(zarc) == {}} {
            set fn [file join $(dirname) $file]
        } else {
            set fn $(zarc):$file
        }
    }
    
    proc example {_ w file args} {
        # Create an example button to exec a tcl/gui file.
        upvar $_ {}
        set title "Example: [file tail $file]"
        set fn [resolve $_ $file]
        set exe [info nameofexecutable]
        set cmd [concat [list exec $exe $fn] $args &]
        pack [blt::tile::button $w.b -text $title -command $cmd -takefocus 0]
        Button conf $w.b -font Slider-h4 -highlightthickness 0 -activebackground DodgerBlue -activeforeground White   -tile [$w cget -tile]
        update idletasks
    }

    proc bullet {_ {level 0}} {
        upvar $_ {}
        set w $(w,main)
        set img [lindex $(bimgs) $level]
        if {$img == {}} {
            tclLog "No bullet image for $level"
            return
        }
        set nimg [Text image create $w end -image $img]
        Text tag add $w bullet_$level $nimg
        Text insert $w end " "
    }
    
    proc ImageFile {_ file} {
        variable pc
        upvar $_ {}
        set path {}
        set fd [file dirname $(file)]
        lappend path $fd $(dirname)
        lappend path [file join $fd icons]
        set path [concat $path $(-icondirs) $pc(icondirs)]
        foreach i $path {
            set fn [file join $i $file]
            if {[file exists $fn]} {
                return $fn
            }
        }
    }
    
    proc img {_ str {inline 0}} {
        # Load an image file:
        upvar $_ {}
        set w $(w,main)
        set str [string trim $str]
        set fn [ImageFile $_ [lindex $str 0]]
        if {$fn == {}} {
            tclLog "File not found: $str"
            return
        }
        set opts [lrange $str 1 end]
        if {[catch { image create photo -file $fn } img]} {
            tclLog "bad image: $fn"
            return
        }
        if {$opts != {}} {
            *catch { eval $img conf $opts }
        }
        lappend (imglist) $img
        if {$inline} {
            Text image create $w end -image $img
        } else {
            Text insert $w end " "
            Text image create $w end -image $img
            Text tag add $w img "insert linestart" "insert lineend"
            Text insert $w end "\n"
        }
    }
    
    proc imgset {_ img file} {
        upvar $_ {}
        if {$file == {}} {
            $img conf -file {}
            return
        }
        set fn [ImageFile $_ $file]
        if {$fn == {}} {
            tclLog "image file not found: $file"
            return
        }
        if {![string equal [$img cget -file] $fn]} {
            $img conf -file $fn
        }
    }
    
    
    proc hline {_} {
        upvar $_ {}
        set w $(w,main)
        Text insert $w end "\n" hr
    }

    proc handletcl {_ rest {iswin 1}} {
        upvar $_ {}
        variable pc
        set w $(w,main)
        if {$(-notcl)} continue
        if {$iswin>=0 && [string match "\{*\}" $rest]} {
            set rest [string range $rest 1 end-1]
        }
        if {[string first %W $rest]<0} {
            if {[catch { namespace eval :: $rest } erc]} {
                tclLog "script error: $erc"
            }
        } else {
            set mkwin 0
            set ww {}
            if {$iswin<0} {
                set ww $w
            } elseif {$iswin>=0} {
                set mkwin 1
                set ww $w.f[incr (widx)]
                frame $ww -tile [$w cget -tile]
                Text window create $w end -window $ww -align baseline
            }
            if {$iswin==1} {
                Text tag add $w win "insert linestart" "insert lineend"
            }
            set mrest [string map [list %% % %W $ww %_ $_ %D $(dirname)] $rest]
            if {[catch { namespace eval :: $mrest } erc]} {
                tclLog "script error: $erc"
                return
            }
            if {$mkwin && [winfo children $ww]=={}} {
                destroy $ww
            }
            if {$iswin} {
                Text insert $w end \n
            }
        }
    }

    proc insert {_ line tag} {
        upvar $_ {}
        set w $(w,main)
        set lst [split $line {}]
        set tags $tag
        Text tag add $w $tag "insert linestart" insert
        for {set j 0} {$j<[llength $lst]} {incr j} {
            set ch [set ch0 [lindex $lst $j]]
            switch -- $ch {
                ` - @ - ' - ^ - % - ! {
                    set m 0
                    while {[lindex $lst [expr {$j+[incr m]}]] == "$ch0"} {
                        append ch $ch0
                    }
                    if {[set sl [string length $ch]]<=1} {
                        Text insert $w end $ch $tags
                        continue
                    }
                    set j [expr {$j+$m-1}]
                    if {$ch0 == "`"} {
                        if {$sl != 2 || [set se [string first $ch $line $j]]<0} {
                            Text insert $w end $ch $tags
                            continue
                        }
                        set data [string range $line $j+1 $se-1]
                        set j [expr {$se+1}]
                        Text insert $w end $data $tags
                        continue
                        
                    }
                    if {$ch0 == "^"} {
                        # Image.
                        if {$sl != 2 || [set se [string first $ch $line $j]]<0} {
                            Text insert $w end $ch $tags
                            continue
                        }
                        set file [string range $line $j+1 $se-1]
                        set j [expr {$se+1}]
                        img $_ $file 1
                        continue

                    } elseif {$ch0 == "!"} {
                        # Image.
                        if {$sl != 2 || [set se [string first $ch $line $j]]<0} {
                            Text insert $w end $ch $tags
                            continue
                        }
                        set script [string range $line $j+1 $se-1]
                        set j [expr {$se+1}]
                        handletcl $_ $script 0
                        continue
                        
                    } elseif {$ch0 == "%"} {
                        # User tags.
                        if {$sl == 4} {
                            set tags [lrange $tags 0 end-1]
                            continue
                        } else {
                            set istag 0
                            if {$sl != 2 || [set se [string first $ch $line $j]]<0} {
                                Text insert $w end $ch $tags
                                continue
                            }
                            set attr [string range $line $j+1 $se-1]
                            set j [expr {$se+1}]
                            set ntag utag_[incr (tidx)]
                            if {[llength $attr]==1} {
                                if {[lsearch [Text tag names $w] $attr]>=0} {
                                    set istag 1
                                    set ntag $attr
                                    Text tag raise $w $ntag
                                } else {
                                    set attr [concat -foreground $attr]
                                }
                            }
                            if {!$istag && [catch { eval $w tag conf $ntag $attr } erc]} {
                                tclLog "markup error '$ntag $attr': $erc"
                                continue
                            }
                        }
                        
                    } elseif {$ch0 == "@"} {
                        set ntag ${tag}_m
                    } else {
                        set ntag ${tag}_[lindex $(mup) [string length $ch]]
                    }
                    if {[set nn [lsearch $tags $ntag]]>=0} {
                        set tags [lreplace $tags $nn $nn]
                    } else {
                        lappend tags $ntag
                    }
                    continue
                }
            }
            $w insert end $ch $tags
        }
        $w tag add $tag "insert linestart" "insert lineend"
    }
    
    proc hastags {_ line} {
        upvar $_ {}
        foreach i $(linemarkup) {
            if {[string first $i $line]>=0} { return 1 }
        }
        return 0
    }
    
    proc setgradient {_ img grad} {
        upvar $_ {}
        foreach {c1 c2 wid hig} $grad break  
        set opts [lrange $grad 4 end]      
        eval winop image gradient $img [list $c1 $c2 -width $wid -height $hig] $opts
        set (lastgrad) $grad
    }
    
    proc sethiding {_ opt} {
        # Hide sections so they can be revealed one bullet at a time.
        upvar $_ {}
        set w $(w,main)
        if {$opt == "1" || $opt == "2"} {
            set lst {}
            foreach {i j} [$w tag ranges bullet_0] {
                lappend lst $i
            }
            lappend lst end
            set n -1
            foreach i $lst {
                if {[incr n] == 0} {
                    set s $i; continue
                }
                $w tag add hide_$n $s "$i-1c"
                $w tag conf hide_$n -elide 1
                set s $i
            }
            
        }
    }
    
    proc setopts {_ opts} {
        upvar $_ {}
        variable pc
        set w $(w,main)
        set hastile 0
        foreach {i j} $opts {
            if {[string match #* $i]} continue
            switch -- $i {
                -tile {
                    set img [$w cget -tile]
                    $img conf -width 0 -height 0
                    set fn [ImageFile $_ $j]
                    if {![string equal [$img cget -file] $fn] &&
                    [catch { $img conf -file $fn }  erc]} {
                        tclLog "bad -tile '$fn': $erc"
                    } else {
                        set hastile 1
                        set (lasttile) $fn
                    }
                }
                -gradient {
                    if {$j == "-"} {
                        if {$hastile} continue
                        set j $(-gradient)
                    }
                    if {$j == $(lastgrad)} continue
                    set img [$w cget -tile]
                    if {[catch { setgradient $_ $img $j } erc]} {
                        tclLog "bad gradient '$j': $erc"
                    }
                }
                -outertile {
                    set img [$(w,.) cget -tile]
                    $img conf -file [ImageFile $_ $j]

                }
                -bullets {
                    *catch { setbullets $_ $j }
                }
                -hdrright {
                    set (hdrright) [string map [list "\n" " " "\r" " " "\t" " "] $j]
                }
                -hdrleft {
                    set (hdrleft) [string map [list "\n" " " "\r" " " "\t" " "] $j]
                }
                -hdrimgright {
                    *catch {
                        if {$(hdrimgright) == {}} {
                            set (hdrimgright) [image create photo]
                        }
                        imgset $_ $(hdrimgright) $j
                    }
                }
                -hdrimgleft {
                    *catch {
                        if {$(hdrimgleft) == {}} {
                            set (hdrimgleft) [image create photo]
                        } 
                        imgset $_ $(hdrimgleft) $j
                    }
                }
                -hide {
                    set (hiding) $j
                }
                -fontscale {
                    fontresize $_ $j
                }
                default {
                    tclLog "unknown option '$i' not one of: -gradient -outertile -bullets"
                }
            }
        }
    }
    
    proc fontresize {_ dir {adj 0.2}} {
        # Rescale fonts or restore them.
        upvar $_ {}
        variable pc
        set flst {}
        foreach i [font names] {
            if {![string match Slider-* $i] && (!$(-fontstk) || ![string match Tk* $i])} continue
            lappend flst $i
        }
        if {$dir == 0} {
            if {$pc(fontsave) == {}} return
            foreach {i j} $pc(fontsave) {
                font conf $i -size $j
            }
            return
        }
        set adj [expr {1.0 + ($dir * $adj)}]
        set osizes {}
        foreach i $flst {
            #NOWARN: 1
            set size [font conf $i -size]
            lappend osizes $i $size
            set nsz [expr {int($size*$adj)}]
            if {$nsz == $size} {
                incr nsz [expr {$adj>0?1:-1}]
            }
            font conf $i -size $nsz
        }
        if {$pc(fontsave) == {}} { set pc(fontsave) $osizes }
    }

    proc header {_ title} {
        upvar $_ {}
        variable pc
        set w $(w,main)
        if {$(hdrimgleft) != {} && [$(hdrimgleft) cget -file] != {}} {
            Text image create $w end -image $(hdrimgleft)
            Text tag add $w header end
        } elseif {$(hdrleft) != {}} {
            $w insert end $(hdrleft) header
        }
        if {$(-number)} {
            set title "$title ([expr {$(npage)+1}]) "
        }
        Text insert $w end \t {} $title {h1 title} \t
        if {$(hdrimgright) != {} && [$(hdrimgright) cget -file] != {}} {
            Text image create $w end -image $(hdrimgright)
            Text tag add $w header end
        } elseif {$(hdrright) != {}} {
            $w insert end $(hdrright) header
        }
        Text insert $w end \n
        Text tag add $w headtabs 1.0 2.0
    }

    proc setbullets {_ files} {
        upvar $_ {}
        variable pc
        set n 0
        foreach j $files {
            set i [lindex $(bimgs) $n]
            if {$i=={}} return
            if {$j == {}} {
                set j [lindex $pc(defimgs) $n]
            }
            incr n
            set f [ImageFile $_ $j]
            if {$f == {}} { error "ignored bullet file: $j" }
            if {![string equal $f [$i cget -file]]} {
                $i conf -file $f
            }
        }
    }
    
    proc fread {_ file} {
        upvar $_ {}
        set fn [file join $(dirname) $file]
        if {[catch { *fread $fn } erc]} {
            tclLog "file read error: $erc"
        } else {
            return $erc
        }
    }

    proc display {_} {
        # Display the current page, if different than last displayed page in (opage).
        upvar $_ {}
        variable pc
        set w $(w,main)
        focus $w
        set pages $(pages)
        set opage $(opage)
        set maxpages [llength $pages]
        set npage $(npage)
        set (npage) [expr {$npage<0? 0: ($npage>=$maxpages? $maxpages-1: $npage)}]
        if {$opage == $(npage)} return
        set (opage) $(npage)
        Text conf $w -state normal
        Text delete $w 1.0 end
        foreach i [Text image names $w] { image delete $i }
        foreach i [Text window names $w] { destroy $i }
        set curp [lindex $pages $(npage)] 
        set lcp [llength $curp]
        set maxp [expr {$(npage)==0?4:3}]
        if {$lcp<2} {
            tclLog "length < 2: '$curp'"
        }
        set title [lindex $curp 0]
        set body [lindex $curp 1]
        set aopts [lrange $curp 2 end]
        set opts {}
        set eval {}
        set (hiding) {}
        set (hidelvl) 1
        if {$lcp%2} {
            tclLog "odd length options: '$title'"
        }
        foreach {pnam pval} $aopts {
            switch -- $pnam {
                init {
                    if {!$(init)} {
                        set (init) 1
                        setopts $_ $pval
                    }

                }
                options {
                    set opts $pval
                }
                allopts {
                    if {$(npage) != 0} {
                        tclLog "alloptions not on first page: $title"
                    }
                    set (allopts) $pval
                }
                alleval {
                    if {$(npage) != 0} {
                        tclLog "alleval not on first page: $title"
                    }
                    set (alleval) $pval
                }
                eval {
                    set eval $pval
                }
                default {
                    tclLog "unexpected option section '$pnam': $title"
                }
            }
        }
        if {$(allopts) != {}} {
            setopts $_ $(allopts)
        }
        if {$opts != {}} {
            setopts $_ $opts
        }
        if {$(alleval) != {}} {
            handletcl $_ $(alleval) -1
        }
        if {$eval != {}} {
            handletcl $_ $eval -1
        }
        header $_ $title
        hline $_
        Text insert $w end \n spc10
        set sbody [*split $body]
        set sawbod 0
        for {set j 0} {$j<[llength $sbody]} {incr j} {
            set line [string trim [set rline [lindex $sbody $j]]]
            if {$line == {}} {
                Text insert $w end \n spc10
                continue
            }
            set spc " "
            set tag {}
            set ch0 [string index $line 0]
            set ch01 [string range $line 0 1]
            set rest [string range $line 2 end]
            set blev -1
            set isbul 0
            if {[string index $line 0] == "*" && [regexp {^(\*)+ } $line]} {
                set blev [string first " " $line]
                set spf [expr {$blev-1}]
                set rest [string range $line $blev end]
                set tag h$blev
                if {$sawbod} { Text insert $w end \n $tag; set sawbod 0}
                bullet $_ $spf
                set isbul 1
            } else {
                if {0 && [set blev [lsearch $(bullets) $ch0]]>=0 && $sawbod} {
                    Text insert $w end \n $tag
                    set sawbod 0
                }
                if {$ch0 == $ch01 && $ch0 == ">"} {
                    set idx [Text index $w insert]
                    #if {![string match *.0 $idx]} { Text insert $w end \n }
                    Text insert $w end \n spc10
                    continue
                    #append ch01 " "
                }
                # {+ }      {set tag h2;bullet $_}
                # {* }      {set tag h3;bullet $_ 1}
                # {- }      {set tag h4;bullet $_ 2}
                # {= }      {set tag h5;bullet $_ 3}
                switch  -- $ch01 {
                    {# }       { continue }
                    {^ }      { img $_ $rest; continue }
                    {< }      {
                        set tag pre
                        append spc \t
                        set rest \n[fread $_ $rest]
                    }
                    {> }      {
                        set tag pre
                        append spc \t
                        if {[string match "\{*\}" $rest]} {
                            set mrest [string range $rest 1 end-1]
                            set srest [split $mrest \n\r]
                            if {[llength $srest]>1} {
                                set l1 [lindex $srest 1]
                                set prespc {}
                                foreach nn [split $l1 {}] {
                                    if {$nn != " "} break
                                    append prespc " "
                                }
                                set rest [string map [list "\n$prespc" \n] $mrest]
                            }
                        }
                    }
                    {! } {
                        handletcl $_ $rest
                        continue
                    }
                    {| } -
                    default {
                        set sawbod 1
                        if {[set iscent [string match "| *" $line]]} {
                            set rline [string range $line 2 end]
                        } else {
                            set rest [string trimleft $rline]
                        }
                        if {$rest == {}} continue
                        if {![string match *.0 [Text index $w insert]]} {
                            Text insert $w end " "
                        }
                        insert $_ $rest body
                        if {$iscent} {
                            Text tag add $w center "insert -1l linestart" insert
                        }
                        #Text insert $w end $rest
                        continue
                    }
                }
            }
            if {!$isbul && [string index $line 1] != " " && [string length $line]>1} {
                tclLog "missing space at: '$line'"
            }
            Text insert $w end $spc $tag
            if {$blev<0} {
                Text insert $w end $rest $tag
            } else {
                insert $_ $rest $tag

            }
            Text insert $w end \n $tag
        }
        Text tag add $w doc 1.0 end
        Text conf $w -state disabled
        set max [llength $(pages)]
        wm title [winfo toplevel $w] "$title ([expr {$(npage)+1}] of $max)"
        sethiding $_ $(hiding)
        update idletasks
        Text mark set $w insert 1.0
        Text see $w 1.0
        set data [Text get $w 1.0 end]
        set (pages.text) [lreplace $(pages.text) $npage $npage $data]
    }
    
    proc fadein {_ {orig {}}} {
        upvar $_ {}
        if {$orig == {}} { set orig $(gamma) }
        catch {after cancel $(after.fadein)}
        set img [Text cget $(w,main) -tile]
        if {$img == {}} return
        set g [expr {$(fade.incr)+[$img cget -gamma]}]
        $img conf -gamma $g
        if {$g < $orig} {
            set (after.fadein) [after $(fade.delay) [list [namespace current]::fadein $_ $orig]]
        }
    }
    
    proc fadefinish {_} {
        upvar $_ {}
        catch {after cancel $(after.fadein)}
        display $_
        set img [Text cget $(w,main) -tile]
        if {$img == {}} return
        if {$(-fade)&1} {
            $img conf -gamma $(fade.stop)
            set (after.fadein) [after $(fade.delay) [list [namespace current]::fadein $_]]
        } else {
            $img conf -gamma $(gamma)
        }
    }

    proc fadeout {_ cmd} {
        upvar $_ {}
        catch {after cancel $(after.fadeout)}
        set img [Text cget $(w,main) -tile]
        if {$img == {}} return
        set g [expr {[$img cget -gamma]-$(fade.incr)}]
        $img conf -gamma $g
        if {$g > $(fade.stop)} {
            set (after.fadeout) [after $(fade.delay) [list [namespace current]::fadeout $_ $cmd]]
        } else {
            set (after.fadeout) [after $(fade.delay) $cmd]
        }
    }
    
    proc unhide {_ tag i j} {
        upvar $_ {}
        set w $(w,main)
        if {$(hiding) != "2"} {
            Text tag remove $w $tag $i $j
            return
        }
        set i2 [Text index $w "$i+1c"]
        Text tag remove $w $tag $i $i2
        if {[string equal $i2 $j]} {return}
        set (after.unhide) [after $(unhide.delay) [list $_ unhide $tag $i2 $j]]
    }
    
    proc move {_ amt args} {
        upvar $_ {}
        Opts p $args {
            { -fade 0 "Use fade-in effect" }
            { -nohide 0 "Ignore unhiding of bullets" }
        }
        set w $(w,main)
        if {$p(-nohide)} {
            set (hiding) {}
        }
        if {$amt == "1" && $(hiding) != {}} {
            set tlst [Text tag ranges $w hide_$(hidelvl)]
            foreach {i j} $tlst {
                unhide $_ hide_$(hidelvl) $i $j
                incr (hidelvl)
                return
            }
        }
        switch -- $amt {
            End { set (npage) [expr {[llength $(pages)]-1}] }
            Home {set (npage) 0 }
            default {
                if {![string is integer -strict $amt]} {
                    tclLog "bad amount in display: $amt"
                    return
                }
                incr (npage) $amt
            }
        }
        set npage $(npage)
        set maxpages [llength $(pages)]
        set (npage) [expr {$npage<0? 0: ($npage>=$maxpages? $maxpages-1: $npage)}]
        if {$(opage) == $(npage)} return

        if {$p(-fade) && ($(-fade)&2) } {
            fadeout $_ [list [namespace current]::fadefinish $_]
            return
        }
        if {$p(-fade) && $(-fade)} {
            set img [Text cget $w -tile]
            if {$img == {}} return
            $img conf -gamma .2
            set (after.fadein) [after $(fade.delay) [list [namespace current]::fadein $_]]
        }
        display $_

    }
    
    proc refresh {_} {
        # Work around bug in polygon -innertile???
        upvar $_ {}
        $(w,label) conf -tile [$(w,label) cget -tile]
    }
    
    proc toggle {_} {
        upvar $_ {}
        #NOWARN:
        wm attributes $(tl) -fullscreen [expr {![wm attributes $(tl) -fullscreen]}]
        #after 100 [list $_ refresh]
    }
    
    proc loadpages {_ file} {
        upvar $_ {}
        variable pc
        set file [file normalize $file]
        if {[string match "*.zip:*" $file] || [file extension $file] == ".zip"} {
            update idletasks
            set nfile [Wiz::mountzip $file {} $pc(fexts)]
            if {$nfile == {}} { tclLog "failed to find file in: $file"; return }
            set (dirname) [file dirname $nfile]
            set file [string trimright $file :]
            if {[string first : $file]>0} {
                set (zfile) $file
                set (zarc) [*strhead : $file]
            } else {
                set (zarc) $file
                set zf [string first / $nfile 1]
                set (zfile) ${file}:[string range $nfile [incr zf] end]
            }
            set file $nfile
        }
        set (pages) [read [set fp [open $file]]]
        if {[catch { llength $(pages) } rc]} {
            tclLog "pages are not a list: [string range $(pages) 0 50]..."
            set (pages) {}
        }
        set (pages.text) {}
        foreach i $(pages) {
            lappend (pages.text) {}
        }
        close $fp
        set (file) $file
    }
    
    proc reload {_} {
        upvar $_ {}
        loadpages $_ $(file)
        set (opage) -1
        if {$(npage)>=[llength $(pages)]} {
            set (npage) 0
        }
        display $_
    }
    
    proc edit {_} {
        upvar $_ {}
        variable pc
        Wiz::edit::new -filetypes $pc(ftypes) $(file)
    }
    
    proc save {_} {
        upvar $_ {}
        variable pc
        Wiz::edit::new -filetypes $pc(ftypes) -data [join $(pages.text) \n\n-------------------------------------------\n\n]
    }
    
    proc run {_} {
        upvar $_ {}
        variable pc
        set fn [tk_getOpenFile -filetypes $pc(ftypes) -parent $(w,.) -initialdir [file dirname $(file)]]
        if {$fn != {}} {
            #NOWARN:
            new $fn
        }
    }
    
    proc auto {_} {
        upvar $_ {}
        set npage [expr {($(npage)+1)%[llength $(pages)]}]
        if {$(-stop) && $npage == 0} return
        set (npage) $npage
        display $_
        set (after.auto) [after [expr {$(-auto)*1000}] [list $_ auto]]
    }
    
    proc help {_} {
        upvar $_ {}
        variable pd
        #NOWARN:
        new [file join $pd(dirname) sliderhelp.spf]
    }
    
    proc config {_} {
        upvar $_ {}
        set w $(w,main)
        set wid [expr {[winfo width $w]-[$w cget -padx]*2}]
        if {$wid<=1} return
        $w tag conf headtabs -tabs "[expr {$wid/2}] center $wid right"

    }
    
    proc gamma {_ {amt 0.1}} {
        upvar $_ {}
        set img [$(w,main) cget -tile]
        set (gamma) [expr {[$img cget -gamma] + $amt}]
        $img conf -gamma $(gamma)
    }
    
    proc listsel {_ w} {
        upvar $_ {}
        set id [TreeView index $w focus]
        if {$id == {}} return
        set page [TreeView entry get $w $id Page]
        set (npage) [incr page -1]
        display $_
        wm withdraw [winfo toplevel $w]
    }
    
    proc listing {_} {
        upvar $_ {}
        set ntl $(w,.).listing
        set w $ntl.tree
        if {[winfo exists $ntl]} {
            TreeView delete $w all
            wm deiconify $ntl
        } else {
            set sv ${w}_sv
            Toplevel new $ntl
            wm title $ntl "Pages list"
            pack [Scrollbar new $sv -command "$w yview"] -fill y -side right
            pack [TreeView new $w -yscrollcommand "$sv set"] -fill both -expand y -side right
            TreeView column insert $w end Page
            TreeView column insert $w end Title
            TreeView column conf $w #0 -hide 1
            bind $w <Double-1> [list $_ listsel $w]
            bind $w <Return> [list $_ listsel $w]
        }
        set n 0
        set cid {}
        foreach i $(pages) {
            incr n
            set id [TreeView insert $w end {} -data [list Page $n Title [lindex $i 0]]]
            if {$n == ($(npage)+1)} {
                TreeView entry select $w $id
            }
        }
    }

    proc Main {_ {file {}}} {
        upvar $_ {}
        variable pc
        variable pd
        #Toplevel style $tl $pc(style)
        set tl $(w,.)
        if {$file == {}} {
            set file [file join $pd(dirname) sliderhelp.spf]
        } else {
            set file [file normalize $file]
        }
        set (dirname) [file dirname $file]
        set img [image create photo]
        set img2 [image create photo -file [ImageFile $_ tile/jaggedblue.gif]]
        setgradient $_ $img $(-gradient)
        Toplevel conf $tl -tile $img2
        set (bimgs) {}
        foreach j $pc(defimgs) {
            lappend (bimgs) [image create photo -file [ImageFile $_ $j]]
        }
        if {$(-bulletfiles) != {}} {
            *catch { setbullets $_ $(-bulletfiles) }
        }
        set (w,label) $tl.l
        pack [blt::tile::label $tl.l -tile $img2]  -padx 12 -pady 12  -fill both -expand y
        pack [Frame new $tl.l.f -tile $img]  -padx 6 -pady 6 -fill both -expand y
        set w $tl.l.f.c
        pack [Text new $w -bg white -height 50 -width 100 -padx 0 -pady 0 -bd 0 -highlightthickness 0 -bg LightBlue] -fill both -expand y
        set (w,main) $w
        Text conf $w -tile $img -wrap word -padx $(-padx)
        foreach {i j} $(tags) {
            eval Text tag conf $w $i $j
        }
       # Text conf $w -font [Text tag cget $w body -font]
        #Text tag conf $w h1 -foreground Blue -justify center
        Text tag conf $w nowrap -wrap none
        focus $w
        set cns [namespace current]
        bind $w <Return>     "$_ move 1 -nohide 1; break"
        bind $w <space>     "$_ move 1; break"
        if {$(-nosel)} {
            bind $w <B1-Motion> break
            bind $w <1>         "focus $w; break"
        } else {
            bind $w <1>         "focus $w"
        }
        bind $w <Shift-3>         "$_ move 1 -fade 1; break"
        bind $w <3>         "$_ move 1"
        bind $w <Control-1>     "$_ move -1; break"
        bind $w <Control-3>     "$_ move 1; break"
        bind $w <Control-l>     "$_ listing; break"
        bind $w <Control-Up>        "$_ move -1; break"
        bind $w <Control-Down>      "$_ move 1; break"
        bind $w <Control-End>       "$_ move End; break"
        bind $w <Control-Home>      "$_ move Home; break"
        bind $w <Control-Prior>     "$_ move -10; break"
        bind $w <Control-Next>      "$_ move  10; break"
        #bind $w <Left>      "$_ move  -1; break"
        #bind $w <Right>     "$_ move   1; break"
        bind $w <Down>      "$w yview scroll 1 units; break"
        bind $w <Up>        "$w yview scroll -1 units; break"
        bind $w <Control-Shift-Down>  "$_ gamma -0.1; break"
        bind $w <Control-Shift-Up>    "$_ gamma .1; break"
        bind $w <Left>      "$w xview scroll -1 units; break"
        bind $w <Right>     "$w xview scroll 1 units; break"
        bind $w <KeyRelease-q> "Delete $_; break"
        bind $w <BackSpace> "$_ move -1; break"
        bind $w <Alt-Up>    "$_ move -1; break"
        bind $w <Alt-Down>  "$_ move  1; break"
        bind $w <Escape>    "Delete $_"
        bind $w <Tab>       "$_ toggle"
        bind $w <Control-r> "$_ reload"
        bind $w <Control-e> "$_ edit"
        bind $w <Control-s> "$_ save"
        bind $w <Control-o> "$_ run"
        bind $w <plus>      "$_ fontresize 1"
        bind $w <equal>     "$_ fontresize 0"
        bind $w <minus>     "$_ fontresize -1"
        bind $w <F1> "$_ help"
        set (tl) [winfo toplevel $w]
        if {$(-full)} {
            wm attributes $(tl) -fullscreen 1
        }
        if {$(-geom) != {}} {
            *catch { wm geometry $(w,.) $(-geom) }
        }
        if {$(-fontscale)} {
            fontresize $_ $(-fontscale)

        }
        Text conf $w -font [Text tag cget $w base -font]
        bind $w <Configure> [list $_ config]
        loadpages $_ $file
        display $_
        if {$(-auto)>0} {
            after [expr {$(-auto)*1000}] [list $_ auto]
        }
    }
    
    proc Cleanup {_} {
        upvar $_ {}
        foreach i [array names $_ after.*] {
            catch {after cancel $($i)}
        }
        *catch { foreach i $(bimgs) { image delete $i } }
        foreach i $(imglist) {
            catch {image delete $i}
        }
        if {$(hdrimgright) != {}} {
            catch {image delete (hdrimgright)}
        }
    }
    
    Tk::create
    
}



