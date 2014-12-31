package require Canvas3d

wm title . "Canvas3d Demos"
pack [label .t -text "Pick a Demo Below"] -fill x
pack [listbox .l]
foreach i {animate cube duodecahedron quads rectangle shapes shape textures triangles} {
  .l insert end $i
}
.l activate 0
.l selection set 0
focus .l

proc RunDemo {x y dir} {
  set i [.l get @$x,$y]
  cd $dir
  destroy .l
  uplevel #0 [list source [set ::argv0 [file join $dir $i.tcl]]]
}

proc RunCur {dir} {
  set i [.l get active]
  cd $dir
  destroy .l
  uplevel #0 [list source [set ::argv0 [file join $dir $i.tcl]]]
}

bind .l <1> [list RunDemo %x %y [file join [pwd] [file dirname [info script]]]]
bind .l <Return> [list RunCur [file join [pwd] [file dirname [info script]]]]
