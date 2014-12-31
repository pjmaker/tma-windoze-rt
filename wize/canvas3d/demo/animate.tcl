# Animate some spinning cubes.

package require Canvas3d

source [file join [set dir [file dir [info script]]] common.tcl]

bind . <Control-Alt-Insert> "console show"

catch {trace}

set img [image create photo -file metalfloor.gif]

variable cnt 0

proc move {n} {
 .win trans myobj "rotate 10 1 0 0"
}

proc mkcube {tags} {
  variable img
  .win create polygon {0 0 0  0 1 0  1 0 0  1 1 0  1 0 1  1 1 1  0 0 1  0 1 1} -style quadstrip -color red -tags $tags -teximage $img
  .win create polygon {1 1 0  1 1 1  0 1 0  0 1 1  0 0 0  0 0 1  1 0 0  1 0 1} -style quadstrip -color blue -tags $tags -teximage $img
}

proc animate {} {
  variable start
  variable cnt
  if {![winfo exists .win]} return
 .win trans myobj "rotate 10 1 0 0"
  incr cnt
  if {($cnt%100) == 0} {
     set elapse [expr {[clock seconds]-$start}]
     if {$elapse} {
       .win itemconf perf -text "Updates: [expr {$cnt/$elapse}]/sec"
     }
  }
  after 3 [list animate]
}

variable tex 1
proc texture {} {
  variable tex
  variable img
  set tex [expr {!$tex}]
  .win itemconf myobj -teximage [expr {$tex ? $img : {}}]
  reset
}

variable bg 1
proc background {} {
  variable bg
  set bg [expr {!$bg}]
  .win itemconf L -teximage [expr {$bg ? $::img3 : {}}]
  reset
}

variable cull 0
proc cull {} {
  variable cull
  set cull [expr {!$cull}]
  .win conf -cull $cull
  puts "CULL: $cull"
  reset
}

proc reset {} {
    set ::start [clock seconds]; set ::cnt 0; .win itemconf perf -text {}
}
proc main {} {
  variable dir  
  variable start [clock seconds]
  incr start -1
  .win create text {0 10} -anchor nw -text {Frame rate:} -tags "dashboard perf" -font  {Arial 10}
  # Make translucent, but not pinned.
  .win conf -enablealpha 1 -texalpha 128
  set n -1
  while {[incr n]<5} {
   mkcube "myobj t$n"
   .win trans t$n "move [expr {3-$n*+1.2}] -.5 -.5"; #"   scale 200 200 200"
  }
  .win conf -texalpha 0
  .win conf -cameralocation {-2 0 -5}
  pack [frame .f ] -before .win -side bottom
  pack [button .f.r  -text Reset -command reset] -side left
  pack [button .f.c  -text Cull -command cull] -side left
  pack [button .f.b  -text Texture -command texture] -side left
  pack [button .f.l  -text Background -command background] -side left


  # Create mipmapped floor texture.
  .win conf -texmipmap 1
  set ::img3 [image create photo -file $dir/checkerboard.gif]
  set m 10; set p -10; set l 100
  .win create polygon {0 0 0  0 0 100  100 0 100  100 0 0}  -teximage $::img3 -texcoords [list 0 0   $l 0   $l $l   0 $l ] -tags L
  .win transform L "move -10 -.5 -6"
  .win create light {0 40 20}
  .win create light {0 40 100}
  .win conf -texmipmap 0


  animate
  
}

main

