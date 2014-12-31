# Display the all types of the builtin "shape" item.

source [file join [file dir [info script]] common.tcl]

proc square {args} {

}
proc cube {{sidelength 1.0}} {
  set p [expr $sidelength / 2.0]
  set m [expr $sidelength / -2.0]

  set rc {}
  lappend rc [list $p $p $p  $m $p $p  $m $m $p  $p $m $p]
  lappend rc [list $p $p $m  $m $p $m  $m $m $m  $p $m $m]

  lappend rc [list $p $p $p  $m $p $p  $m $p $m  $p $p $m]
  lappend rc [list $p $m $p  $m $m $p  $m $m $m  $p $m $m]

  lappend rc [list $p $p $p  $p $m $p  $p $m $m  $p $p $m]
  lappend rc [list $m $p $p  $m $m $p  $m $m $m  $m $p $m]
  return $rc
}

bind .win <Control-Alt-Insert> "console show"

catch {trace}

#puts ":XX [cube]"
set img [image create photo -file wood.gif]

set coords { 0 0 0  1 0 0  0 1 0  1 1 0  0 2 .5  1 2 .5  0 3 1.5  1 3 1.5}
.win create polygon $coords -teximage $img -style quadstrip -smooth 1 
.win trans all {move 1 1 0}
.win create polygon $coords -teximage $img -style quad -smooth 1
.win trans all {move 1 1 0}
set coords { 0 0 0  1 0 0  .7 .2 .5  .5 .5 0  .2 .7 .5   0 1 0}
.win create polygon $coords -teximage $img -style trianglefan -smooth 1

