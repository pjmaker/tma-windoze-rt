
source [file join [file dir [info script]] common.tcl]

# One way to generate a cube.
proc cube {sidelength tag} {
  set p [expr $sidelength / 2.0]
  set m [expr $sidelength / -2.0]

  .win create polygon [list $p $p $p  $m $p $p  $m $m $p  $p $m $p] -tags $tag
  .win create polygon [list $p $p $m  $m $p $m  $m $m $m  $p $m $m] -tags $tag

  .win create polygon [list $p $p $p  $m $p $p  $m $p $m  $p $p $m] -tags $tag
  .win create polygon [list $p $m $p  $m $m $p  $m $m $m  $p $m $m] -tags $tag

  .win create polygon [list $p $p $p  $p $m $p  $p $m $m  $p $p $m] -tags $tag
  .win create polygon [list $m $p $p  $m $m $p  $m $m $m  $m $p $m] -tags $tag
}

cube 1.0 c1
.win trans c1 {move 1.5 0 0}
foreach i [.win find c1] j {red green blue pink orange brown purple} {
  .win itemconf $i -ambient $j
}

# Another way.
.win create polygon [::canvas3d::cube] -tags c2

.win create light {5 7 -8}
.win create light {-8 7 8}
.win conf -cameralocation {-1 2 -3}


