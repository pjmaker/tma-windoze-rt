
set auto_path [concat .. $auto_path]

package require Tk
package require Canvas3d

bind . <Control-Alt-Insert> "console show"


proc ShowSource args {
  variable pc
  set f $::argv0
  edit $f
}

canvas3d .win
pack .win -expand yes -fill both
.win configure -width 800 -height 600 -background black

. configure -menu [menu .menu]
.menu add cascade -menu [menu .menu.file -tearoff 0]    -label File
.menu add cascade -menu [menu .menu.options -tearoff 0] -u 0 -label Options

#########################################################################
# Add a file menu option to spawn tkcon if we can find the script.
#
foreach f [list \
    [file join $tcl_library .. .. bin tkcon] \
    [file join $tcl_library .. .. bin tkcon.tcl]
] {
    if {[file exists $f]} {
        catch {
            source $f
            package require tkcon
            .menu.file add command -label Tkcon -command {tkcon show}
        }
        break
    }
}

#########################################################################
# Add a file menu option to quit the application
#
.menu.file add separator
.menu.file add command -label Source -command ShowSource
.menu.file add command -label Quit -command exit

#########################################################################
# Add a radio button menu accessible from the options menu to let the user
# set the value of widget option -saveunder.
#
.menu.options add cascade \
    -menu [menu .menu.options.saveunder -tearoff 0] \
    -label Saveunder
.menu.options.saveunder configure -tearoff 0
.menu.options.saveunder add radiobutton \
    -variable SAVEUNDER \
    -label All \
    -value all \
    -command set_saveunder
.menu.options.saveunder add radiobutton \
    -variable SAVEUNDER \
    -label 3d \
    -value 3d \
    -command set_saveunder
.menu.options.saveunder add radiobutton \
    -variable SAVEUNDER \
    -label None \
    -value none \
    -command set_saveunder
proc set_saveunder {} {.win configure -saveunder $::SAVEUNDER}

.menu.options add checkbutton \
    -variable ENABLEALPHA \
    -label enablealpha \
    -command set_enablealpha
proc set_enablealpha {} {.win configure -enablealpha $::ENABLEALPHA}

proc set_configvars {} {
    set ::SAVEUNDER   [.win cget -saveunder]
    set ::ENABLEALPHA [.win cget -enablealpha]
}
.menu.options configure -postcommand set_configvars

###########################################################################
# Camera control:
proc T {args} {
    .win transform -camera dashboard $args
    # Bad idea to use type(light) as it triggers a global redraw.
    #.win transform -camera type(light) $args
    .win delete CameraString

    set script {
        set format "Location: (%.2f %.2f %.2f) Center: (%.2f %.2f %.2f)"
        set str [format $format \
            [lindex [.win cget -cameralocation] 0] \
            [lindex [.win cget -cameralocation] 1] \
            [lindex [.win cget -cameralocation] 2] \
            [lindex [.win cget -cameracenter] 0] \
            [lindex [.win cget -cameracenter] 1] \
            [lindex [.win cget -cameracenter] 2] \
        ]
        .win create text {0 0} -text $str -anchor nw -tags CameraString 
        .win itemconfigure CameraString -font {Arial 10}
    }

    after cancel $script
    after 250 $script
}

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

# Mouse control.
bind .win <B1-Motion> {
    set ry [expr 360.0 * (%y  - $::Y) / [.win cget -height]]
    set rx [expr 360.0 * (%x  - $::X) / [.win cget -width]]
    T orbitup $ry orbitleft $rx
    set ::X %x
    set ::Y %y
}
bind .win <1> {
    set ::X %x
    set ::Y %y
}
bind .win <4> {
    T movein 0.98
}
bind .win <5> {
    T movein 1.02
}

foreach k [array names K] {
  bind .win <KeyPress-$k> $K($k)
  if {[string length $k] == 1} {
    bind .win <KeyPress-[string toupper $k]> $K($k)
  }
}

proc lookat {} {
  T lookat all
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


###########################################################################
# Set up callbacks to draw a "rubber-banding" box with the middle mouse
# button.
bind .win <ButtonPress-3> {
  .win create 2dline "%x %y  %x %y  %x %y  %x %y  %x %y" -color red -tags BOX
}
bind .win <ButtonRelease-3> {
  set coords [lindex [.win coords BOX] 0]
  .win delete BOX
  set x1 [lindex $coords 0]
  set y1 [lindex $coords 1]
  set x2 [lindex $coords 4]
  set y2 [lindex $coords 5]
  .win itemconf CameraString -text "Selected: [.win find viewport($x1,$y1,$x2,$y2)]"
}
bind .win <B3-Motion> {
  set coords [lindex [.win coords BOX] 0]
  lset coords 2 %x
  lset coords 4 %x
  lset coords 5 %y
  lset coords 7 %y
  .win coords BOX $coords
}
###########################################################################

bind .win <KeyPress-Q> Exit
bind .win <KeyPress-q> Exit
focus .win

proc Exit {} {
  destroy .win
  if {[llength [info commands ::canvas3d::alloc]] > 0} {
    foreach {res cnt} [::canvas3d::alloc] {
      puts "$cnt outstanding ${res}s"
    }
  }
  exit
}

proc DoMenu {title cmd} {
  if {0 == [llength [info commands .menu.demo]]} {
    .menu add cascade -menu [menu .menu.demo -tearoff 0] -label Demo
  }
  .menu.demo add command -label $title -command $cmd
}
