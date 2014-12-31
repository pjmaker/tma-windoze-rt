# Display the all types of the builtin "shape" item.

source [set dir [file dir [info script]]]/common.tcl

bind .win <Control-Alt-Insert> "console show"

catch {trace}

set img [image create photo -file $dir/wood.gif]

set lst {"cube" "sphere"  "cylinder" "disk" "partialdisk" "cone" "torus"  "dodecahedron" "octahedron" "tetrahedron" "icosahedron" "teapot" }
set n 0
foreach i $lst {
  set x [expr {-3+$n*2}]
  .win create shape "$x 0 0" -type $i -teximage $img
  incr n
}
.win itemconf 2 -rot 45 -xrot 1
#.win trans 1 "scale 2 1 1"
#.win trans 2 "rotate 45 1 0 0"
#.win trans 2 "move 0 -1 0"
#.win create text "60 20" -text [join $lst {  }] -anchor nw
#.win trans  -camera type(dashboard) "move 4 0 10"
#.win create glut {0 0 0  1 0 0  0 1 0} -type torus -teximage $img
#.win create glut {0 0 0} -type sphere -teximage $img
#.win create gsphere {0 0 0} -teximage $img
.win create light {10 10 20}
.win create light {-10 -10 20}
.win create light {-10 -10 -20}
#.win trans all "lookat 0"

