
source [file join [file dir [info script]] common.tcl]
.win create light {200 200 200} -horizon 1

set cone [::canvas3d::cylinder \
    -radiustwo 0.0 -height 5 -center {0 2.5 0} -normal {0 1 0}]
set sphere   [::canvas3d::sphere -center {0 6 0}]
set disc     [::canvas3d::disc -radius 5 -normal {0 1 0}]
set cylinder [::canvas3d::cylinder \
    -height 3 -normal {1 0 0} -center {0 6 0} -radiusone 0.5 -radiustwo 0.5]

.win create polygon $cone     -tags LEFT
.win create polygon $cone     -tags RIGHT
.win create polygon $sphere   -tags RIGHT -shin 5
.win create polygon $sphere   -tags LEFT
.win create polygon $disc
.win create polygon $cylinder -tags {LEFT RIGHT}

.win transform LEFT {move -2 0 0}
.win transform RIGHT {move 2 0 0}

puts [.win statistics all]


# Set up the toggle buttons (T and W).
.win create text {0 0} -tags TOGGLE \
    -text "To toggle smoothness, press T. To toggle wireframe mode, press W" \
    -anchor se -font {Arial 10}
bind .win <Configure> {
    .win coords TOGGLE "%w [expr %h - 10]"
}
bind .win <t> {
    set smooth [expr ![.win itemcget LEFT||RIGHT -smooth]]
   .win itemconfigure LEFT||RIGHT -smooth $smooth -style solid
}
bind .win <w> {
    set style [.win itemcget LEFT||RIGHT -style]
    if {$style == "solid"} {
        set style outline
    } else {
        set style solid
    }
   .win itemconfigure LEFT||RIGHT -style $style
}

# Set the camera location. First move back away from the scene to set an
# approximate angle, then use lookat to finetune the framing and make sure
# we're looking at the scene center.
#
.win configure -cameralocation {0 5 10}
.win transform -camera {} {lookat all}

bind .win <Control-Alt-Insert> "console show"

