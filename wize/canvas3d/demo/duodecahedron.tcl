# This demo paints a duodecahedron and allows it to be panned and
# zoomed.
#
catch {package require Canvas3d}
frame .c
pack .c -fill both -expand 1
canvas3d .c.c -bg white -width 800 -height 600
pack .c.c -fill both -expand 1
button .c.down -text Down
bind .c.down <ButtonPress-1> {motor_start {orbitdown 2}}
bind .c.down <ButtonRelease-1> {motor_stop}
button .c.up -text Up
bind .c.up <ButtonPress-1> {motor_start {orbitup 2}}
bind .c.up <ButtonRelease-1> {motor_stop}
button .c.left -text Left
bind .c.left <ButtonPress-1> {motor_start {orbitleft 2}}
bind .c.left <ButtonRelease-1> {motor_stop}
button .c.right -text Right
bind .c.right <ButtonPress-1> {motor_start {orbitright 2}}
bind .c.right <ButtonRelease-1> {motor_stop}
button .c.in -text In
bind .c.in <ButtonPress-1> {motor_start {movein 0.98}}
bind .c.in <ButtonRelease-1> {motor_stop}
button .c.out -text Out
bind .c.out <ButtonPress-1> {motor_start {movein 1.02}}
bind .c.out <ButtonRelease-1> {motor_stop}
button .c.all -text {See All} -command \
     {.c.c transform -camera light {lookat all}}
button .c.quit -text Quit -command exit
pack .c.down .c.up .c.left .c.right .c.in .c.out .c.all .c.quit -side left
set smooth 0
checkbutton .c.smooth -text Smooth -variable smooth -command {
  .c.c itemconfig face -smooth $smooth
}
set alpha 0
checkbutton .c.alpha -text Alpha -variable alpha -command {
  .c.c config -enablealpha $alpha
}
set image [image create photo -file metalfloor.gif]
set img 0
checkbutton .c.img -text Texture -variable img -command {
  .c.c itemconfig face -teximage [expr {$img?$image:{}}]
}
pack .c.smooth .c.alpha .c.img -side left

proc motor_start {cmd} {
  variable _motor_cmd
  set _motor_cmd $cmd
  _motor_when_idle
}
proc motor_stop {} {
  variable _motor_timer
  catch {after cancel $_motor_timer}
  unset -nocomplain _motor_timer
}
proc _motor_when_idle {} {
  variable _motor_timer
  if {[info exists _motor_timer]} return
  set _motor_timer [after idle _motor_callback]
}
proc _motor_callback {} {
  variable _motor_timer
  variable _motor_cmd
  .c.c transform -camera light $_motor_cmd
  foreach {cx cy cz} [.c.c cget -cameracenter] break
  foreach {lx ly lz} [.c.c cget -cameralocation] break
  set dx [expr {$lx-$cx}]
  set dy [expr {$ly-$cy}]
  set dz [expr {$lz-$cz}]
  set dxy [expr {sqrt($dx*$dx + $dy*$dy)}]
  set angle [expr {atan2($dz,$dxy)*180.0/3.1415926}]
  if {$angle>80.0} {
    .c.c transform -camera light [list orbitdown [expr {$angle-80.0}]]
  } elseif {$angle<-80.0} {
    .c.c transform -camera light [list orbitup [expr {-$angle-80.0}]]
  }
  .c.c config -cameraup {0 0 1}
  set _motor_timer [after 10 _motor_callback]
}

proc make_polygon {cid did coords} {
  .c.c create polygon $coords -tags [list face $cid $did] -smooth 0 \
        -color {1.0 0.8 0.8 0.2} -diffuse {1 .8 .8 .2} -ambient {0.5 0.4 0.4 1}
}
proc make_line {wallid deckid coords} {
  .c.c create line $coords -color blue -tags [list wall $wallid $deckid]
}
after idle {
  .c.c config -cameralocation {100 0 0} -cameraup {0 0 1}
  .c.c create light {100 5 10} -tags light -horizon 1
  .c.c transform -camera light {lookat all}
  .c.c transform -camera light {orbitup 20 orbitleft 30}
  .c.c config -cameraup {0 0 1} -enablealpha 0
}
bind .c.c <1> {testclick %x %y}
proc testclick {x y} {
  foreach id [.c.c find -sortbydepth viewport($x,$y)] {
    puts "$id [.c.c gettag $id]"
  }
}
wm deiconify .


make_polygon c1 f1  {
  {
    1.53884176858763  0.50000000000000  0.000000000000000
    0.95105651629515  1.30901699437495  0.000000000000000
    0.00000000000000  1.00000000000000  0.000000000000000
    0.00000000000000  0.00000000000000  0.000000000000000
    0.95105651629515 -0.30901699437495  0.000000000000000
  }
  {
    0.00000000000000  1.00000000000000  0.000000000000000
    0.00000000000000  0.00000000000000  0.000000000000000
   -0.42532540417602 -0.30901699437495  0.850650808352039
   -0.68819096023559  0.50000000000000  1.376381920471180
   -0.42532540417602  1.30901699437495  0.850650808352039
  }
  {
    0.00000000000000  1.00000000000000  0.000000000000000
    0.95105651629515  1.30901699437495  0.000000000000000
    1.11351636441161  1.80901699437495  0.850650808352039
    0.26286555605957  1.80901699437495  1.376381920471180
   -0.42532540417602  1.30901699437495  0.850650808352039
  }
  {
    1.53884176858763  0.50000000000000  0.000000000000000
    0.95105651629515  1.30901699437495  0.000000000000000
    1.11351636441161  1.80901699437495  0.850650808352039
    1.80170732464720  1.30901699437495  1.376381920471180
    2.06457288070676  0.50000000000000  0.850650808352039
  }
  {
    1.53884176858763  0.50000000000000  0.000000000000000
    0.95105651629515 -0.30901699437495  0.000000000000000
    1.11351636441161 -0.80901699437495  0.850650808352039
    1.80170732464720 -0.30901699437495  1.376381920471180
    2.06457288070676  0.50000000000000  0.850650808352039
  }
  {
    0.00000000000000  0.00000000000000  0.000000000000000
    0.95105651629515 -0.30901699437495  0.000000000000000
    1.11351636441161 -0.80901699437495  0.850650808352039
    0.26286555605957 -0.80901699437495  1.376381920471180
   -0.42532540417602 -0.30901699437495  0.850650808352039
  }
  {
   -0.42532540417602  1.30901699437495  0.850650808352039
    0.26286555605957  1.80901699437495  1.376381920471180
    0.42532540417602  1.30901699437495  2.227032728823220
   -0.16245984811645  0.50000000000000  2.227032728823220
   -0.68819096023559  0.50000000000000  1.376381920471180
  }
  {
    0.26286555605957  1.80901699437495  1.376381920471180
    1.11351636441161  1.80901699437495  0.850650808352039
    1.80170732464720  1.30901699437495  1.376381920471180
    1.37638192047117  1.00000000000000  2.227032728823220
    0.42532540417602  1.30901699437495  2.227032728823220
  }
  {
    1.80170732464720  1.30901699437495  1.376381920471180
    2.06457288070676  0.50000000000000  0.850650808352039
    1.80170732464720 -0.30901699437495  1.376381920471180
    1.37638192047117  0.00000000000000  2.227032728823220
    1.37638192047117  1.00000000000000  2.227032728823220
  }
  {
    1.80170732464720 -0.30901699437495  1.376381920471180
    1.11351636441161 -0.80901699437495  0.850650808352039
    0.26286555605957 -0.80901699437495  1.376381920471180
    0.42532540417602 -0.30901699437495  2.227032728823220
    1.37638192047117  0.00000000000000  2.227032728823220
  }
  {
    0.26286555605957 -0.80901699437495  1.376381920471180
   -0.42532540417602 -0.30901699437495  0.850650808352039
   -0.68819096023559  0.50000000000000  1.376381920471180
   -0.16245984811645  0.50000000000000  2.227032728823220
    0.42532540417602 -0.30901699437495  2.227032728823220
  }
  {
    1.37638192047117  1.00000000000000  2.227032728823220
    1.37638192047117  0.00000000000000  2.227032728823220
    0.42532540417602 -0.30901699437495  2.227032728823220
   -0.16245984811645  0.50000000000000  2.227032728823220
    0.42532540417602  1.30901699437495  2.227032728823220
  }   
}
