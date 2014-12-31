
set auto_path [concat . $auto_path]

package require Tk
package require Canvas3d

canvas3d .win
pack .win -expand yes -fill both
.win configure -width 800 -height 600 -background black
# .win configure -saveunder 3d

###########################################################################
# Camera control:
proc T {args} {.win transform -camera type(light) $args ; drawbox}

# Rotate around the scene center:
set K(Up)      {T orbitup    5.0}
set K(Down)    {T orbitdown  5.0}
set K(Right)   {T orbitright 5.0}
set K(Left)    {T orbitleft  5.0}

# Zoom in and out:
set K(s)       {T movein 0.9}
set K(x)       {T movein 1.1}

# Rotate camera around line of sight:
set K(c)       {T twistright 5.0}
set K(z)       {T twistleft 5.0 }

# Look to the left or right.
set K(d)       {T panright 5.0}
set K(a)       {T panleft 5.0 }

# Lookat!
set K(l) lookat

foreach k [array names K] {
  bind .win <KeyPress-$k> $K($k)
  if {[string length $k] == 1} {
    bind .win <KeyPress-[string toupper $k]> $K($k)
  }
}

set HELP {

Space - Start and stop animation.
Up, Down, Left, Right - Rotate camera around center point.
S - Zoom toward center point.
X - Zoom away from center point.
Z - Rotate camera counter-clockwise around line of sight.
C - Rotate camera counter-clockwise around line of sight.
A - Rotate camera to look to the left (moves center point).
D - Rotate camera to look to the right (moves center point).
*** L - Invoke "lookat" command. ***

}
# End camera control setup.
###########################################################################


bind .win <KeyPress-Q> exit
bind .win <KeyPress-q> exit
bind .win <KeyPress-space> press_space
bind .win <ButtonPress> "click %x %y"
focus .win

# $::STATE may be either RUNNING or PAUSED
set ::STATE RUNNING

proc triangle {top height count} {
  if {$count == 0} {
    set y [expr [lindex $top 1] - $height]
    set h2 [expr $height/2]
    foreach {tx ty tz} $top {}

    set nw [list [expr $tx-$h2] $y [expr $tz-$h2]]
    set ne [list [expr $tx+$h2] $y [expr $tz-$h2]]
    set sw [list [expr $tx-$h2] $y [expr $tz+$h2]]
    set se [list [expr $tx+$h2] $y [expr $tz+$h2]]

   
    set p1 [concat $top $nw $ne]
    set p2 [concat $top $sw $nw]
    set p3 [concat $top $se $sw]
    set p4 [concat $top $ne $se]

    set id [.win create polygon $p1 $p2 $p3 $p4]
  } else {
    set c [expr $count - 1]
    set h2 [expr $height/2]
    set h4 [expr $height/4]
    foreach {tx ty tz} $top {}

    triangle $top $h2 $c
    triangle [list [expr $tx-$h4] [expr $ty-$h2] [expr $tz-$h4]] $h2 $c
    triangle [list [expr $tx+$h4] [expr $ty-$h2] [expr $tz-$h4]] $h2 $c
    triangle [list [expr $tx+$h4] [expr $ty-$h2] [expr $tz+$h4]] $h2 $c
    triangle [list [expr $tx-$h4] [expr $ty-$h2] [expr $tz+$h4]] $h2 $c
  }
}

proc rotate {} {
  .win transform triangles {
    move 1.0 1.0 1.0
    rotate 1.0 0.0 1.0 0.0
    move -1.0 -1.0 -1.0
  }
  drawbox
  after 30 rotate
}

proc press_space {} {
  if {$::STATE == "RUNNING"} {
    set ::STATE PAUSED
    after cancel rotate
  } else {
    set ::STATE RUNNING
    after idle rotate
  }
}

proc click {x y} {
    set items [.win find -sortbydepth viewport($x,$y)]
    if {[llength $items] > 0} {
       catch {.win itemconfigure [lindex $items 0] -diffuse purple}
       .win itemconfigure [lindex $items 0] -color purple
    }
}

proc lookat {} {
    .win transform -camera type(light) {lookat triangles}
    drawbox
}

proc drawbox {} {
  .win delete box
  set c [.win bbox triangles]
  set color {1.0 0.0 0.0 0.5}
  set width 4


  # Top
  set x1 [expr [lindex $c 0] - $width]
  set x2 [expr [lindex $c 2] + $width]
  set y1 [lindex $c 1]
  set y2 [expr $y1 - $width]
  .win create 2dline [list $x1 $y1 $x2 $y2] -color $color -tags box
  
  # Left
  set x1 [lindex $c 0]
  set x2 [expr $x1 - $width]
  set y1 [lindex $c 1]
  set y2 [lindex $c 3]
  .win create 2dline [list $x1 $y1 $x2 $y2] -color $color -tags box
  
  # Bottom
  set x1 [expr [lindex $c 0] - $width]
  set x2 [expr [lindex $c 2] + $width]
  set y1 [lindex $c 3]
  set y2 [expr $y1 + $width]
  .win create 2dline [list $x1 $y1 $x2 $y2] -color $color -tags box
  
  # Right
  set x1 [lindex $c 2]
  set x2 [expr $x1 + $width]
  set y1 [lindex $c 1]
  set y2 [lindex $c 3]
  .win create 2dline [list $x1 $y1 $x2 $y2] -color $color -tags box
}

proc drawaxis {} {
  set color {1.0 1.0 1.0 1.0}

  set yaxis {0.0 -10.0 0.0 0.0 10.0 0.0} 
  set xaxis {-10.0 0.0 0.0 10.0 0.0 0.0}
  set zaxis {0.0 0.0 -10.0 0.0 0.0 10.0} 
  .win create line $xaxis $yaxis $zaxis -color $color

  set radius 0.2
  set points [list]

  for {set i 0.0} {$i < 360.0} {set i [expr $i+0.5]} {
    set angle [expr $i * 3.14159 / 180.0]
    set x [expr $radius * cos($angle)]
    set y [expr $radius * sin($angle)]
    lappend points $x $y 0.0
    lappend points 0.0 $x $y
    lappend points $x 0.0 $y
  }
  .win create point $points -color $color
}

triangle {1.0 0.8 0.0} 1.6 2
triangle {-1.0 0.8 0.0} 1.6 2
.win addtag all triangles

set color {0.8 0.5 0.5 1.0}
.win itemconfigure triangles -ambient $color -diffuse $color
.win configure -enablealpha 1


set t {<Space> to pause/restart     Q to quit} 
set font {-weight normal}
set linespace [font metrics $font -linespace]
set y 50
foreach t [split [string trim $::HELP] "\n"] {
  .win create 2dtext "50 $y" -font $font -text $t -color lightgrey -anchor nw
  incr y $linespace
}

.win transform all {move -1.0 -1.0 -1.0}
drawaxis

.win configure -visibleangle 20.0
# .win itemconfigure triangles -style outline 
# .win configure -enablealpha true

set ::light_id [.win create light {0.0 200.0 200.0}] 

lookat
rotate
