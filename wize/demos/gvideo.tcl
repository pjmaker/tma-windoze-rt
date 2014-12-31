#!/usr/bin/env wize

# A frontend to mplayer: the video viewer on Unix (unfinished).
# Just takes a bunch of files on the command line and plays them.

package require Gui

namespace eval ::app::gvideo {
    
    Mod export
    
    variable Opts {
        { -debug    0           "Trace input from mplayer" }
        { -geom     {}          "Geometry WxH" }
        { -player   mplayer     "Player command" }
        { -popts    {-vo xv -zoom -slave}     "Options for player" }
        { -fixsound False       "Resample sound via -rrate" }
        { -rrate    48000       "Rate for resampling" }
    }
    
    *array _ {
        fd {}   id {}   file {}    msgs {}   playlst {}   playpos 0
        ropts   {}    after:move {}   opt:str {}   opt:raw {}   opt:lst {}
        dat1 {}   hasidentify 0   runtime 30    clipinfo {}    inclipinfo 0
    }
    
    namespace eval Op {
        
        Mod upvars _
        
        proc Cmd {_ str {block False}} {
            # Send a command to mplayer.
            upvar $_ {}
            if {![info exists $_]} return
            if {$(fd) == {}} return
            if {$block} {
                fconfigure $(fd) -blocking 1
                *catch { flush $(fd) }
            }
            puts -nonewline $(fd) $str\n
            if {$block} {
                fconfigure $(fd) -blocking 0
            }
            *catch { flush $(fd) }
        }
        
        proc Load {_ file} {
            # Start mplayer with file.
            upvar $_ {}
            if {[file isdirectory $file]} {
                set file [tk_getOpenFile -initialdir $file]
                if {$file == {}} return
            }
            set x [winfo width $(w,player)]
            set y [winfo height $(w,player)]
            set xopts "-x $x -y $y"
            if {$(hasidentify)} {
                lappend xopts -identify
            }
            #set xopts ""
            set cmd "|$(-player) $(-popts) $(ropts) $xopts -wid $(id) $file 2>@1"
            set (fd) [open $cmd r+]
            set (file) $file
            fconfigure $(fd) -blocking 0
            fileevent $(fd) readable [list $_ Op::Read]
            #Cmd $_ pause
            Cmd $_ gui_about
            #after 1000 [list wm geom $(w,.) 610x410]
        }
        
        proc PlayNext {_} {
            upvar $_ {}
            if {[incr (playpos)]>=[llength $(playlst)]} {
                return
            }
            Load $_ [lindex $(playlst) $(playpos)]
        }
        
        proc Read {_} {
            # Read response from mplayer.
            upvar $_ {}
            set rc [gets $(fd) dat]
            #if {$rc<0} { close $data(-fid) }
            if {[string match "Exiting*" $dat]} {
                fileevent $(fd) readable {}
            }
            if {$(-debug)>1} {
                tclLog "DAT: $dat"
            }
            if {$(inclipinfo)} {
                if {![string match " *:*" $rc]} {
                    set (inclipinfo) 0
                } else {
                    set ln [string trim $dat]
                    *strparts : $ln nam val
                    lappend (clipinfo) $nam $val
                }
            } elseif {[string match "Clip Info:" $rc]} {
                set (inclipinfo) 1
                set (clipinfo) {}
            }
            # Input of interest looks like this.
            #  A:   6.3 V:   6.3 A-V:  0.000 ct:  0.040 154/154  1%  0%  0.6% 0 0
            if {[string match "A: *" $dat] || [string match "V: *" $dat]} {
                if {$(dat1) == {}} {
                    set (dat1) $dat
                }
                if {[scan $dat "%*s %s" secs] != 1} return
                if {$secs>$(runtime)} {
                    set (runtime) [expr {$secs*1.1}]
                }
                set pct [expr {(100.0*$secs)/$(runtime)}]
                set (v,pct) $pct
                return
            }
            
            if {$(-debug)==1} {
                tclLog "DAT: $dat"
            }
            if {[string match "ID_LENGTH=\[0-9\]*" $dat]} {
                set len [string range $dat 10 end]
                if {[string is integer -strict $len] && $len>3} {
                    set (runtime) $len
                }
            }
            if {[string match "VIDEO: *" $dat]
            && [regexp {([0-9.]+) kbyte/s} $dat NA kblen] && int($kblen)>0} {
                # Calculate runtime.
                set flen [file size $(file)]
                set (runtime) [expr {$flen/($kblen*1024)}]
            }
            if {$(-geom) == {}} {
                if {0 && [string match "VIDEO: *" $dat]} {
                    *catch {
                        set g [lindex $dat 2]
                        foreach {W H} [split $g x] break
                        $(w,player) conf -width $W -height $H
                        if {$(-debug)} { tclLog "Set geom: $g" }
                    }
                }
                # VO: [xv] 320x240 => 297x209 Planar YV12  [zoom]
                if {[string match "VO: *" $dat]} {
                    if {[regexp { => ([0-9]+)x([0-9]+) } $dat NA W H]} {
                        $(w,player) conf -width $W -height $H
                        if {$(-debug)} { tclLog "Set Geom: ${W}x$H" }
                    }
                }
                
            }
            if {[string match "* PAUSED *" $dat]} {
                return
            }
            
            if {[string match "Exiting...*" $dat]} {
                PlayNext $_
                return
            }
            
            #tclLog "DD($rc): $dat"
            append (msgs) $dat \n

        }
                
    }
    
    proc Posn {_ pos} {
        upvar $_ {}
        #set pos [expr {$(v,pct)*100}]
        if {$pos>=0 && $pos<=100} {
            Op::Cmd $_ pause 1
            $_ Op::Cmd "seek $pos 1"
        }
    }

    proc Play {_} {
        # Play the video.
        upvar $_ {}
        if {$(fd) != {}} {
            catch { close $(fd) }
            set (fd) {}
        }
        Op::Load $_ $(file)
    }
    
    proc Pause {_} {
        # Pause the video.
        upvar $_ {}
        Op::Cmd $_ pause
    }
    
    proc Stop {_} {
        # Stop the video.
        upvar $_ {}
        catch { close $(fd) }
        set (fd) {}
    }
    
    proc Quit {_} {
        # Quit the application.
        upvar $_ {}
        ::Delete $_
    }
    
    proc GetConf {_} {
        # Get mplayer conf options.
        # Stores available slave commands in (opt:lst).
        upvar $_ {}
        if {![catch { exec $(-player) -identify -input cmdlist 2>@1 } opts]} {
            set (hasidentify) 1
        } elseif {[catch { exec $(-player) -input cmdlist 2>@1 } opts]} return
        set (opt:raw) $opts
        if {$(-debug)} { tclLog "OPTS: $opts" }
        set fnd 0
        foreach i [split $opts \n] {
            if {[string trim $i] == {}} continue
            set c0 [string index $i 0]
            if {![string is lower $c0]} continue
            lappend (opt:str) $i
            *catch {
                lappend (opt:lst) [lindex $i 0]
            }
        }
    }

    proc About {_} {
        tk_messageBox -message "GUI (for mplayer) Video\nBSD Copyright 2009\nPeter MacDonald"
    }
    
    
    proc Main {_ args} {
        # Application start entry point.
        upvar $_ {}
        set (id) [expr {int([winfo id $(w,player)])}]
        GetConf $_
        if {$(-fixsound)} {
            set (ropts) "-aop list=resample:fout=$(-rrate)"
        }
        set (playlst) $args
        set (playpos) 0
        #set (to) 20
        #Scale conf $(w,pct) -to $(to)
        if {$(-geom) != {}} {
            *catch { wm geometry $(w,.) $(-geom) }
        }
        if {[llength $args]>0} {
            update
            Op::Load $_ [lindex $args 0]
            Op::Cmd $_ "seek 10 1"
            after 200 [list $_ Op::Cmd "seek 0 2"]
        }
        Scale conf $(w,pct) -command [list $_ Posn]
    }
    
    proc Cleanup {_} {
        # Application shutdown.
        upvar $_ {}
        catch { close $(fd) }
        set (fd) {}
        foreach i [array names {} after:*] {
            catch { after cancel $($i) }
        }
    }
    
    ::Tk::gui create {
        #geom 600x300
        {Menu + -id pop -label "Video Ops" -pos ^} {
            x Pause
            x About
            
        }
        {Toplevel +} {
            style {
                .pct { -showvalue 0 -width 3m }
                Toplevel {
                    @bind {
                        <3> !pop
                    }
                    @guiattrsmap {
                        -icon {
                            play playfwd
                            pause  playpause
                            stop  playstop
                            quit  stop
                        }
                    }
                }
            }
            {Canvas - -id player -pos *} {}
            {Frame + -matte 3 -pos _} {
                {Frame + -subpos l -pos _} {
                    {Scale - -id pct -horizontal 1 -pos l*} {}
                    {Button - -id play} Play
                    {Button - -id pause} Pause
                    {Button - -id stop} Stop
                    {Button - -id quit} Quit
                }
            }
        }
    }
}

