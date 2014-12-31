# Demonstrate using textures.

set dir [file dir [info script]]
source [file join [file dir [info script]] common.tcl]

array set opts {-map 1}
array set opts $argv

proc toggle {img lst {n 1}} {
  # Toggle textures via image conf -file.
  set n [expr {!$n}]
  $img conf -file [lindex $lst $n]
  after 1000 [list toggle $img $lst $n]
}

proc toggle2 {lst {n 1}} {
  # Toggle textures via itemconf.
  set n [expr {!$n}]
  .win itemconf M -teximage [lindex $lst $n]
  after 1000 [list toggle2 $lst $n]
}

proc cube {sidelength tag} {
  global dir opts
  set p [expr {$sidelength / 2.0}]
  set m [expr {$sidelength / -2.0}]
  set img [image create photo -file $dir/metalfloor.gif]
  set img2 [image create photo -file $dir/wood.gif]
  set img4 [image create photo -file $dir/metalfloor.gif]
  set img5 [image create photo -file $dir/wood.gif]
  # Make textures resident.
  .win conf -texcache 1

  # A sphere with alternating textures.
  set scd [::canvas3d::sphere -center {0 2 0}]
  set id [.win create polygon  $scd -teximage $img2]
  .win transform $id "move -2 0 0"
  toggle $img2 [list $dir/metalfloor.gif $dir/wood.gif]

  #set scd [::canvas3d::sphere -center {0 2 0} -detail 1]
  # 10 spheres with alternating textures.
  # First pin images into the cache.
  foreach i [list $img4 $img5] {
    .win create polygon {0 0 0 0 0 0 0 0 0} -teximage $i -hidden 1
  }

  set n 0
  while {[incr n]<10} {
    set id [.win create polygon  $scd -teximage $img4 -tags M]
    .win transform $id "move [expr {$n*3}] 0 0"
  }
  # Flip between the two cached textures.
  toggle2 [list $img5 $img4]

  # A cube with translucent texture.
  .win conf -enablealpha 1
  .win create polygon [list $p $p $p  $m $p $p  $m $m $p  $p $m $p] -tags P -color red
  .win create polygon [list $p $p $m  $m $p $m  $m $m $m  $p $m $m] -tags P

  .win create polygon [list $p $p $p  $m $p $p  $m $p $m  $p $p $m] -tags P
  .win create polygon [list $p $m $p  $m $m $p  $m $m $m  $p $m $m] -tags P

  .win create polygon [list $p $p $p  $p $m $p  $p $m $m  $p $p $m] -tags P
  .win create polygon [list $m $p $p  $m $m $p  $m $m $m  $m $p $m] -tags P
  .win conf -texalpha 70
  .win itemconf P -teximage $img
  .win conf -texalpha 0

  # Create mipmapped floor texture.
  .win conf -texmipmap $opts(-map)
  set img3 [image create photo -file $dir/checkerboard.gif]
  set m 10; set p -10; set l 100
  .win create polygon {0 0 0  0 0 100  100 0 100  100 0 0}  -teximage $img3 -texcoords [list 0 0   $l 0   $l $l   0 $l ] -tags L
  .win transform L "move -10 -$sidelength 3"
  .win create light {0 40 20}
  .win create light {0 40 100}
  .win conf -texmipmap 0

  # Make button that shares a named font with canvas3d text item.
  set fn [font create -family {Times Roman} -size 30]
  #.win create text { 5 10 } -anchor nw -font $fn -text $::HELP
  .win create text { 5 10 } -text "Type '?' for Help" -anchor nw -font $fn
  bind .win <question> [list tk_messageBox -message $::HELP]
  pack [button .bb -text "Quit" -font $fn -command "Exit"]
  after 2000 "font conf $fn -size 12"
  .win transform -camera type(light) {movein 30}
}

cube 1.0 cube_one

bind .win <Control-Alt-Insert> {console show}

