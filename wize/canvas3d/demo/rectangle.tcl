# Draw a 3d item, then some 2d items as overlays, then rapidly
# update the 2d layers.

source [file join [file dir [info script]] common.tcl]

.win create polygon [::canvas3d::cube] -tags c3 -ambient red


.win create light {5 7 -8}
.win create light {-8 7 8}
.win conf -cameralocation {-1 2 -3}
.win create text {400 10} -tags Counter

variable coo {
  { 10 10 100 10 50 100 }
  { 10 100 100 100 50 10 }
}
  
.win create 2dpolygon [lindex $coo 0] -tags p2 -color red

proc updstr {{n 1} {s 0}} {
  variable coo
  set ns [clock seconds]
  if {$s == 0} { set s $ns }
  if {$ns == $s} { set sd 1 } else { set sd [expr {[incr n]/($ns-$s)}] }
  set id [.win find Counter]
  .win itemconf $id -text "Updates of text layer: $n = $sd/sec"
  .win coords p2 [lindex $coo [expr {$n%2}]]
  after 3 "updstr $n $s"
}

updstr


