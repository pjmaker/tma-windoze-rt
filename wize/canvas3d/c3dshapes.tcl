namespace eval ::canvas3d {
   variable pd
   set pd(script) [file normalize [info script]]
   set pd(dirname) [file dirname $pd(script)]
}

# ::canvas3d::sphere --
#
#         ::canvas3d::sphere ?-option <value>...?
#
#     Return a polygon face list that approximates a sphere. The following
#     options are supported:
#
#         -radius <float>
#         -center <vertex>
#         -detail <integer>
#
proc ::canvas3d::sphere {args} { #TYPES: . {topts -radius Float -center . -detail Int}
    ::canvas3d::args [list {radius 1.0} {center {0 0 0}} {detail 3}] $args

    set XPLUS  {1 0 0}
    set XMINUS {-1 0 0}
    set YPLUS  {0 1 0}
    set YMINUS {0 -1 0}
    set ZPLUS  {0 0 1}
    set ZMINUS {0 0 -1}
    
    set triangles [list \
        [concat $XPLUS $YPLUS $ZPLUS] \
        [concat $XPLUS $YPLUS $ZMINUS] \
        [concat $XPLUS $YMINUS $ZPLUS] \
        [concat $XPLUS $YMINUS $ZMINUS] \
        [concat $XMINUS $YPLUS $ZPLUS] \
        [concat $XMINUS $YPLUS $ZMINUS] \
        [concat $XMINUS $YMINUS $ZPLUS] \
        [concat $XMINUS $YMINUS $ZMINUS] \
    ]

    for {set i 0} {$i < $detail} {incr i} {
        set newtriangles [list]
        foreach t $triangles {
            set v1 [lrange $t 0 2]
            set v2 [lrange $t 3 5]
            set v3 [lrange $t 6 8]
    
            set v12 [::canvas3d::normalize [::canvas3d::midpoint $v1 $v2]]
            set v23 [::canvas3d::normalize [::canvas3d::midpoint $v2 $v3]]
            set v31 [::canvas3d::normalize [::canvas3d::midpoint $v3 $v1]]
    
            lappend newtriangles [concat $v1 $v12 $v31] 
            lappend newtriangles [concat $v2 $v12 $v23] 
            lappend newtriangles [concat $v3 $v31 $v23] 
            lappend newtriangles [concat $v12 $v23 $v31] 
        }
        set triangles $newtriangles
    }

    foreach {x y z} $center {}
    set transform "scale $radius $radius $radius move $x $y $z"
    return [::canvas3d::transform $triangles $transform]
}

# Return coordinates for a cube.  Use transform to make
# bigger, rectangular, etc.
proc ::canvas3d::cube {{sidelength 1.0}} {
  set p [expr {$sidelength / 2.0}]
  set m [expr {$sidelength / -2.0}]

  set rc {}
  lappend rc [list $p $p $p  $m $p $p  $m $m $p  $p $m $p]
  lappend rc [list $p $p $m  $m $p $m  $m $m $m  $p $m $m]

  lappend rc [list $p $p $p  $m $p $p  $m $p $m  $p $p $m]
  lappend rc [list $p $m $p  $m $m $p  $m $m $m  $p $m $m]

  lappend rc [list $p $p $p  $p $m $p  $p $m $m  $p $p $m]
  lappend rc [list $m $p $p  $m $m $p  $m $m $m  $m $p $m]
  return $rc
}


# ::canvas3d::disc --
#
#         ::canvas3d::disc ?-option <value>...?
#
#     Return a polygon that approximates a flat disc. The following
#     options are supported:
#
#         -radius <float>
#         -center <vertex>
#         -detail <integer>
#         -normal <vector>
#
proc ::canvas3d::disc {args} { #TYPES: . {topts -radius Float -center . -detail Int -normal .}
    ::canvas3d::args [list \
        {normal {0 0 1}}   \
        {radius 1.0}       \
        {center {0 0 0}}   \
        {detail 3}         \
    ] $args

    set XPLUS  {1 0 0}
    set XMINUS {-1 0 0}
    set YPLUS  {0 1 0}
    set YMINUS {0 -1 0}

    set vertices [list $XPLUS $YPLUS $XMINUS $YMINUS]

    for {set i 0} {$i < $detail} {incr i} {
        set new [list]
        for {set j 0} {$j < [llength $vertices]} {incr j} {
            set v1 [lindex $vertices $j]
            set v2 [lindex $vertices [expr {($j+1)%[llength $vertices]}]]

            lappend new $v1
            lappend new [::canvas3d::normalize [canvas3d::midpoint $v1 $v2]]
        }
        set vertices $new
    }

    foreach v $vertices {
        lappend triangles [lindex $v 0]
        lappend triangles [lindex $v 1]
        lappend triangles [lindex $v 2]
    }
    foreach {x y z} [::canvas3d::normalize $normal] {}
    set rx $y
    set ry [expr {-1.0 * $x}]
    set rz 0.0
    set angle [expr {acos($z) * 180.0 / 3.14159}]
    if {$angle == 0} {
        set rx $x
        set ry $y
        set rz $z
    }
    foreach {x y z} $center {}
    set rad $radius
    set transform "scale $rad $rad $rad rotate $angle $rx $ry $rz move $x $y $z"
    return [lindex [::canvas3d::transform $triangles $transform] 0]
}

# ::canvas3d::cylinder --
#
#         ::canvas3d::cylinder ?-option <value>...?
#
#     Return a polygon list that approximates a cylinder (with no end
#     faces). The following options are supported.
#
#         -radiusone <float>
#         -radiustwo <float>
#         -center    <vertex>
#         -detail    <integer>
#         -normal    <vector>
#         -height    <float>
#
proc ::canvas3d::cylinder {args} { #TYPES: . {topts -radiusone Float -radiustwo Float -center . -detail Int -normal . -height Float}
    ::canvas3d::args [list \
        {normal {0 0 1}}   \
        {radiusone 1.0}    \
        {radiustwo 1.0}    \
        {center {0 0 0}}   \
        {height 1}         \
        {detail 3}         \
    ] $args

    foreach {nx ny nz} [::canvas3d::normalize $normal] {}
    foreach {cx cy cz} $center {}
    set c1 [list \
        [expr {$cx + $nx * $height / -2.0}] \
        [expr {$cy + $ny * $height / -2.0}] \
        [expr {$cz + $nz * $height / -2.0}] \
    ]
    set c2 [list \
        [expr {$cx + $nx * $height / 2.0}] \
        [expr {$cy + $ny * $height / 2.0}] \
        [expr {$cz + $nz * $height / 2.0}] \
    ]

    set d1 [::canvas3d::disc \
        -radius $radiusone -normal $normal -detail $detail -center $c1]
    set d2 [::canvas3d::disc \
        -radius $radiustwo -normal $normal -detail $detail -center $c2]

    for {set i 0} {$i < [llength $d1]} {incr i 3} {
        set i2 [expr {($i + 3) % [llength $d1]}]

        set face [list \
            [lindex $d1 [expr {$i+0}]] \
            [lindex $d1 [expr {$i+1}]] \
            [lindex $d1 [expr {$i+2}]] \
            [lindex $d1 [expr {$i2+0}]] \
            [lindex $d1 [expr {$i2+1}]] \
            [lindex $d1 [expr {$i2+2}]] \
            [lindex $d2 [expr {$i2+0}]] \
            [lindex $d2 [expr {$i2+1}]] \
            [lindex $d2 [expr {$i2+2}]] \
            [lindex $d2 [expr {$i+0}]] \
            [lindex $d2 [expr {$i+1}]] \
            [lindex $d2 [expr {$i+2}]] \
        ]

        lappend ret $face
    }

    return $ret
}

# ::canvas3d::midpoint
#
#         ::canvas3d::midpoint v1 v2
#
proc ::canvas3d::midpoint {v1 v2} {
    return [list \
        [expr {([lindex $v1 0] + [lindex $v2 0]) / 2.0}] \
        [expr {([lindex $v1 1] + [lindex $v2 1]) / 2.0}] \
        [expr {([lindex $v1 2] + [lindex $v2 2]) / 2.0}] \
    ]
}

# ::canvas3d::normalize
#
#         ::canvas3d::normalize v1 v2
#
proc ::canvas3d::normalize {v} {
    set x [lindex $v 0]
    set y [lindex $v 1]
    set z [lindex $v 2]
    set mag [expr {sqrt($x*$x + $y*$y + $z*$z)}]
    return [list [expr {$x / $mag}] [expr {$y / $mag}] [expr {$z / $mag}]]
}

# ::canvas3d::args
#
#         ::canvas3d::args argspec cmdline
#
proc ::canvas3d::args {argspec cmdline} {
    foreach a $argspec {
        set spec(-[lindex $a 0]) up_[lindex $a 0]
        upvar [lindex $a 0] up_[lindex $a 0]
        set up_[lindex $a 0] [lindex $a 1]
    }
    for {set i 0} {$i < [llength $cmdline]} {incr i 2} { 
        set option [lindex $cmdline $i]
        set value [lindex $cmdline [expr {$i + 1}]]

        if {![info exists spec($option)]} {
            uplevel "error {No such option: $option}"
        }
        set $spec($option) $value
    }
}


