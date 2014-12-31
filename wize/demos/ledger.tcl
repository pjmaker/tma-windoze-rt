#!/usr/bin/env wize
#
# ledger.tcl: A personal accounting program.
#
# Ledger uses tree to store double entry accounting records while
# Treeview provides a user interface.
#
# TODO: scheduled transactions, sqlite DB option.
#
# BSD Copyright 2010 - Peter MacDonald   (See http://pdqi.com/)

package require Gui

namespace eval ::app::ledger {
    
    Mod export
    
    variable pc
    set pc(Id) {$Id: ledger.tcl,v 1.20 2010/04/30 16:42:30 pcmacdon Exp $}
    set pc(version)   2.0;  # Version of Ledger.
    set pc(verdata)   2.0;  # Version of data format.
    set pc(vercvs) [lindex $pc(Id) 2]
    
    set pc(prefsfile) preferences.cnf
    set pc(ext)      .tre;   # Extension for tree data files.
    set pc(dbfile)   ledger.db3;   # Sqlite database file (futures).

    set pc(aclist:types) { asset liability equity expense revenue }
    set pc(report:types) {
        {Account Summary} {General Ledger} {Totals by Payee}
        {Reconciliation} {Trial Balance} {Validate Data}
    }
    # Extra fields to ignore in reports checking.
    set pc(xaction:extra) {}
    set pc(aclist:extra) {}
    
    variable _
    # List of accounts/catagories for dialogs.
    set _(aclist:list) {}
    set _(aclist:listsp) {}
    set _(aclist:listall) {}
    array set _ {
        changed 0   impaccts {}   rcsid 1   trees {xaction aclist sched}
        rec:closebal {}   rec:closing 0   popup {}   dialog:wins {}
        sched:cnt 0   sched:speriod {}   sched:monwids {}   archive:close 0
        sched:smonthday {}   sched:monnumwids 0   sched:ssdate 0
        origcursor {}   starting 0   rec:diff {}   edit:acct {}
        t:sched {}   t:aclist {}   t:xaction {}   cur:edit {}   edit:ids {}
        cur:edita {}   edit:xtype {}  edit:atype {}   guiobj {}   edit:sums {}
        acur {}     v,sch_period daily   v,sch_daily daily
        reco:acct {}   edit:data {}    v,rep_catacc 1
        menu:main {}   payee:listsp {}   dbh {}   nosave 0
        cvtaccts  0   catlower 0

    }

    # Command line options.
    variable Opts {
        { -dir          ~/ledger "Accounts directory"  }
    }
    
    # Configuration options.
    variable Config {
        { -acolumns          {aname anum attl atransnums aobal arbal acatagory} "Account columns to display" }
        { -asortconf        {}  "Sort configuration" }
        { -awidths          {aname 150 anum 50 atransnums 50} "Custom column widths" }
        { -commify          1   "Show values with commas" }
        { -datefmt          %Y-%m-%d "Current date format" }
        { -datefmts        {%Y-%m-%d %y-%m-%d %m/%d/%Y %d-%B-%Y %d-%B-%y %y%m%d %Y%m%d {%d %B %y}} "Date formats" }
        { -fontfix          {}  "Fixed font config" }
        { -fontvar          {}  "Variable font config" }
        { -geom             {}  "Geometry of main window" }
        { -hasmenu          1   "Start with menu visible" -type {Choice 0 1} }
        { -hasstatus        1   "Start with status visible" -type {Choice 0 1} }
        { -hastoolbar       1   "Start with toolbar visible" -type {Choice 0 1} }
        { -hidecat          0   "Display catagories" -type {Choice 0 1} }
        { -iopts            {}  "Name/value data pairs (use with caution)" }
        { -maxsplits        10  "Maximum splits to display for split edit" -type {Int -min 10} }
        { -nosched          0   "Ignore scheduled transactions" }
        { -panewidth        {}  "Width setting for pane" }
        { -usecvs           0   "Use CVS" -type {Choice 0 1} }
        { -usercs           1   "Use RCS" -type {Choice 0 1} }
        { -xcolumns         {treco tnum tdate tpayee tgroup tsum truntot tmemo} "Transaction columns to display" }
        { -xsortconf        {-column tdate}  "Sort configuration" }
        { -xwidths          {tnum 50 tdate 100 tpayee 150} "Custom column widths" }
    }


    # Account list record.
    *struct new aclist {
        { aid        0   "Id" -type Int}
        { aname      {}  "Account" }
        { aobal      0   "Opening Balance" -type Double -fmt Float}
        { attl       0   "Balance" -type Double -fmt Float}
        { acbal      0   "Closing Balance"  -type Double -fmt Float }
        { arbal      0   "Reconciled Balance" -type Double -fmt Float }
        { abudget    {}  "Budget" }
        { atransnums 0   "Count" -type Int}
        { adefaultnum 0  "Default Num"}
        { anum       {}  "Num" -type Int }
        { ainstname  {}  "Institution" }
        { ainstaddr1 {}  "Address1" }
        { ainstaddr2 {}  "Address2" }
        { ainstcity  {}  "City" }
        { ainstzip   {}  "Zip" }
        { ainstphone {}  "Phone" }
        { ainstfax   {}  "Fax" }
        { ainstemail {}  "Email" }
        { ainstcontact {} "Contact" }
        { ainstnotes {}  "Notes" }
        { acatagory  1   "Catagory" -type Bool }
        { ataxed     1   "Taxed" -type Bool }
        { atype      expense   "Type" }
        { apid       0   "Pid" }
        { arecebals  {}  "Reconciled End Balances" }
    }

    # Transaction record.
    *struct new xaction {
        { tid    {}  "Id" }
        { tnum   {}  "Num" }
        { tpayee {}  "Payee" }
        { tmemo  {}  "Memo" }
        { tsum   {}  "Amount" -type double -fmt Float }
        { tdate  {}  "Date" -fmt Date}
        { treco  {}  "Reconciled transactions"  -label R -fmt Reco}
        { tacct  {}  "Trans Account"}
        { tgroup {}  "Account" -fmt FillGrp}
        { tsched {}  "Unused"}
        { truntot {}  "Balance" -type double -fmt Float}
    }

    # Schedule record.
    *struct new schedule {
        { ssdate         {}  "Start Date" -fmt Date }
        { sedate         {}  "End Date" -fmt Date }
        { speriod        {}  "Period" }
        { speriodnum     {}  "Num Periods" }
        { smonthday      {}  "Month/Day" }
        { smonthdaynum   {}  "Month/Day-Num" }
        { slast          {}  "Last" }
    }

    set pc(catagories) {
        Auto:fuel Auto:other Auto:service Bank:fees Bank:interest Bonus Books Cash
        Charity Childcare Christmas Clothing Computer Debts Dental Dining Education
        Entertainment Gifts Groceries Grooming Hobbies Home:other Home:rent
        Home:repair Hotels Insurance Insurance Job Loan Medical Medicare
        Miscellaneous Music Restaurant Tax:federal Tax:state Telephone Travel
        Utilities Vacation
    }

    # Forward declarations for use with "-Wall".
    extern CreateAccount {_ args}
    extern Del1Xact {_ id {updopen False}}
    extern LookupField {_ table field val {fname {}}}
    extern Save {_ {dir {}}}
    extern SelAct {_}
    extern UpdateRunTotal {_ {acur {}}}
    
    ##########################################################################

    # EXT extension macro. To use create real proc or ensemble EXT.
    if {[namespace which [namespace current]::EXT] == {}} {  proc EXT {args} {} }

    proc Dollars {_ str args}    { return [format %.2f $str] }
    
    proc Float {_ str args} {
        # Return float rounded to 2 decimals.
        variable pp
        if {$str != 0.0 && abs($str) < 0.009} { set str 0.00 }
        set nstr [format %12.2f $str]
        if {$pp(-commify) && abs($str) >= 1000.00} {
            set num [string trim [string range $nstr 0 end-3]]
            set frac [string range $nstr end-2 end]
            while {[regsub {^([+-]?\d+)(\d\d\d)} $num "\\1,\\2" num]} {}
            set nstr [format %12s $num$frac]
        }
        return $nstr
    }
        
    proc Reco {_ str} {
        # Return reconciled flag.
        if {$str == {}} return;
        return R
    }
    
    proc date {_ {tim {}}} {
        # Return formated date.
        upvar $_ {}
        variable pp
        if {$tim == {}} {
            set tim [clock seconds]
        }
        return [clock format $tim -format $pp(-datefmt)]
    }

    proc Date {_ str args} { return [date $_ $str] } 

    proc Cursor {_ curs} {
        # Set cursor; TODO: change to just use busy.
        upvar $_ {}
        if {$curs == {busy}} {
            set curs watch 
        } elseif {$curs == {normal}} {
            set curs $(origcursor)
        } else { error "unknown cursor $curs" }
        $(w,aclist) conf -cursor $curs
        $(w,xaction) conf -cursor $curs
        return 
    }  

    proc Notify {_ str args} {
        return [eval [list tk_messageBox -message $str] $args]
    }
    
    proc Refresh {_} {
        # Force a refresh.
        upvar $_ {}
        foreach i {xaction aclist} {
            set t $(w,$i)
            $t conf -font [$t cget -font]
        }
    }
        
    proc Init {} {
        variable pc
        variable pp
        variable _
        variable account
        variable xact
        variable sched
        variable Config
        
        foreach win {xaction aclist schedule} {
            upvar [namespace current]::$win vv
            set pc($win:fields) $vv(names)
            set pc($win:labels) $vv(comments)
            set pc($win:defs) $vv(defaults)

            set _(${win}:last) -1
            set _(${win}:glast) -1
            set _(${win}:cnt) 0
            set _(${win}:cmd) {}
            set n -1
            #TODO: OBSOLETE: will remove after migration.
            foreach i $pc($win:fields) {
                set pc($win:flup:$i) [incr n]
            }
        }
        
        Opts q {} $Config
        array set pp [array get q]
    }

    eval Init
    
    ###############################################
    # OLD ARRAY ROUTINES TO BE DELETED.
    
    proc Var {_ table} { return ${_}_$table }
    
    proc ReadData {_ file table} {
        # Read data
        upvar $_ {}
        upvar [Var $_ $table] pd
        if {![file exists $file]} return
        set fp [open $file]
        array set pd [read $fp]
        catch {unset pd()}
        close $fp
        return
    }


    proc InitAct {_} {
        # Initialize account info
        upvar $_ {}
        variable pc
        variable pp
        upvar [Var $_ aclist] pa

        set win aclist
        set n -1
        set (aclist:list) {}
        set ll [llength $pc(aclist:fields)]
        foreach i [array names pa] {
            # Set totals.
            while {[llength $pa($i)]<$ll} { lappend pa($i) {} }
            foreach $pc(aclist:fields) $pa($i) break
            if {$aname == {}} { unset pa($i); continue }
            if {$aid > $($win:last)} {
                set ($win:last) $aid
            }
            if {$(cvtaccts) && [regexp {^([0-9]+) (.*)$} $aname {} npart rest]} {
                # Remove leading numbers from account names.
                set nn $pc(aclist:flup:aname)
                set pa($i) [lreplace $pa($i) $nn $nn $rest]
                set nn $pc(aclist:flup:anum)
                set pa($i) [lreplace $pa($i) $nn $nn $npart]

            }
            foreach j {ataxed acatagory} {
                if {![string is integer [set $j]]} {
                    set ival [string equal Y [set $j]]
                    set nn $pc(aclist:flup:$j)
                    set pa($i) [lreplace $pa($i) $nn $nn $ival]
                }
            }
            if {[string is integer -strict $atype]} {
                set atype [lindex $pc(aclist:types) $atype]
                set nn $pc(aclist:flup:atype)
                set pa($i) [lreplace $pa($i) $nn $nn $atype]
            }
            if {$aobal == {}} {
                set nn $pc(aclist:flup:aobal)
                set pa($i) [lreplace $pa($i) $nn $nn 0.00]
            }
            lappend (aclist:list) $aname
        }
        return
    }

    proc InitXact {_ {fastload 0}} {
        # Load khacc xaction info
        upvar $_ {}
        variable pc
        upvar [Var $_ aclist] pa
        upvar [Var $_ xaction] pt

        upvar [Var $_ xgroup] pg
        set n -1
        array unset pg
        set win xaction
        set ($win:list) {}
        foreach i [array names pa] {
            if {[set ttl($i) [lindex $pa($i) $pc(aclist:flup:aobal)]] == {}} {
                set ttl($i) 0
            }
        }
        foreach i [array names pt] {
            foreach $pc($win:fields) $pt($i) break
            lappend pg($tgroup) $i
            if {$fastload} continue
            if {[info exists xactnum($tacct)]} {
                incr xactnum($tacct)
            } else {
                set xactnum($tacct) 1
            }
            if {![info exists pa($tacct)]} { unset pt($i); continue }
            if {$tid > $($win:last)} {
                set ($win:last) $tid
            }
            if {$treco == {2}} {
                set nn $pc($win:flup:treco)
                set pt($i) [lreplace $pt($i) $nn $nn 1]
            } elseif {$treco == {0}} {
                set nn $pc($win:flup:treco)
                set pt($i) [lreplace $pt($i) $nn $nn {}]
            }
            if {$tgroup > $($win:glast)} {
                set ($win:glast) $tgroup
            }
            if {[regexp {([0-9]*)/([0-9]*)/([0-9]*)} $tdate {} _mon _day _year]} {
                set ndat [clock scan $_year-$_mon-$_day]
                set nn $pc($win:flup:tdate)
                set pt($i) [lreplace $pt($i) $nn $nn $ndat]
            } elseif {[string first - $tdate]>=0} {
                set ndat [clock scan $tdate]
                set nn $pc($win:flup:tdate)
                set pt($i) [lreplace $pt($i) $nn $nn $ndat]
            }
            if {[info exists ttl($tacct)]} {
                set ttl($tacct) [expr {$ttl($tacct)+$tsum}]
            } else {
                set ttl($tacct) $tsum
            }
        }
        if {![string equal xaction $win]} return
        if {!$fastload} {
            set nn $pc(aclist:flup:atransnums)
            foreach i [array names pa] {
                # Update info.
                if {![info exists xactnum($i)]} {
                    set xactnum($i) 0
                }
                set pa($i) [lreplace $pa($i) $nn $nn $xactnum($i)]
            }
            set nn $pc(aclist:flup:attl)
            foreach i [array names ttl] {
                # Update attl field in accounts.
                set pa($i) [lreplace $pa($i) $nn $nn $ttl($i)]
            }
        }
        return
    }
    
    proc OldLoad {_ dir} {
        # Old load data (from arrays).
        upvar $_ {}
        variable pc
        variable pp

        if {![file isdirectory $dir]} {
            file mkdir $dir
        }
        if {$pp(-geom) != {}} {
            *catch { wm geometry $(w,.) $pp(-geom) }
        }
        set accs [file join $dir accounts]
        if {[file exists $accs.tld]} {
            $_ ReadData $accs.tld aclist
            $_ InitAct
            $_ ReadData [file join $dir transactions.tld] xaction
            $_ ReadData [file join $dir schedule.tld] schedule
            $_ InitXact 0
        }
        #$_ sched run
        return
    }

    ###############################################
    
    proc LoadDB {_ dir} {
        # Load date from sqlite DB.
        upvar $_ {}
        variable pc
        set fn $dir/$pc(dbfile)
        if {![file exists $fn]} { return  }
        set n 0
        if {$(dbh) == {}} {
            set (dbh) [db open $fn]
        }
        foreach ft $(trees) {
            if {$ft == "sched"} continue
            set t $(t:$ft)
            tree op sqlload $t $(dbh) "SELECT * from $ft;"
            incr n
        }
        return $n
    }

    proc SaveDB {_ dir} {
        # Save to sqlite DB.
        upvar $_ {}
        variable pc
        set fn $dir/$pc(dbfile)
        if {[file exists $fn]} return
        if {[set dbh $(dbh)] == {}} {
            set dbh [db open $fn]
        }
        foreach ft $(trees) {
            set t $(t:$ft)
            *sqldump $t $(dbh) $ft
        }
        if {$(dbh) == {}} {
            db close $dbh
        }
    }
    
    proc LoadTrees {_ dir} {
        # Load data into trees.
        upvar $_ {}
        variable pc
        set tim [time {
            set n 0
            foreach i [array names $_ t:*] {
                set ft [string range $i 2 end]
                set fn $dir/$ft$pc(ext)
                if {![file exists $fn]} { continue }
                set t $($i)
                if {!$::tcl_warn(level) && [file size $fn]>5000000} {
                    set rc [catch { $t restore 0 -file $fn } erc]
                } else {
                    # Use -data on small files as it has better error catching.
                    set data [*fread $fn]
                    set rc [catch { $t restore 0 -data $data } erc]
                }
                if {$rc} {
                    Notify $_ "[mc {File or data error}]: \n$fn\n$erc" -icon error
                    set (nosave) 1
                } else {
                    $t ismodified all 0
                }
                incr n
            }
        }]
        #tclLog "LOAD: $tim"
        return $n
    }

    proc SaveTree {_ tree fn} {
        # Save tree data to file fn.
        upvar $_ {}
        variable pc
        if {[file exists $fn] && [file size $fn] != 0} {
            file rename -force $fn $fn.bak
        }
        set t $tree
        $t label 0 0
        $t set 0 header(date) [clock format [clock seconds]]
        $t set 0 header(version) $pc(version)
        $t set 0 header(verdata) $pc(verdata)
        $t set 0 header(vercvs) $pc(vercvs)
        $t incri 0 header(serial)
        $t dump 0 -file $fn
    }
    
    proc SaveTrees {_ dir} {
        # Save tree data to directory
        upvar $_ {}
        variable pc
        set tim [time {
            set n 0
            foreach ft $(trees) {
                set t $(t:$ft)
                set fn $(-dir)/$ft$pc(ext)
                SaveTree $_ $t $fn
                $t ismodified all 0
                incr n
            }
        }]
        return $n
    }
    
    proc DoLoad {_ dir} {
        # Load the data
        upvar $_ {}
        variable pc
        #set ln [LoadDB $_ $dir]
        #if {$ln != 0} return
        set ln [LoadTrees $_ $dir]
        if {$ln != 0} return
        
        # Fallback to old array format.
        OldLoad $_ $dir
        upvar [Var $_ aclist] pa
        upvar [Var $_ xaction] px
        set ta $(w,aclist)
        set tx $(w,xaction)
        set acur {}
        set t $(t:aclist)
        foreach i [array names pa] {
            set d {}
            foreach dn $pc(aclist:fields) dv $pa($i) { lappend d $dn $dv }
            $t insert 0 -node $i -data $d
            if {$acur == {}} {
                set (acur) [set acur $i]
            }
        }
        set t $(t:xaction)
        foreach i [array names px] {
            set d {}
            foreach dn $pc(xaction:fields) dv $px($i) { lappend d $dn $dv }
            #$tx insert 0 $i -data $d -hide 1
            set id [$t insert 0 -node $i -data $d]
            set gid [$t get $id tgroup]
            $t tag add grp$gid $id
        }
        if {$ln == 0} {
            SaveTrees $_ $dir
        }
        return
    }

    proc TransDest {_ key {field aid} {other 0}} {
        # Lookup destination account info for a transaction.
        upvar $_ {}
        variable pc
        set rc {}
        set tx $(t:xaction)
        set ta $(t:aclist)
        set gid [$tx get $key tgroup]
        set rc [*lremove [$tx tag nodes grp$gid] $key]
        if {![llength $rc]} return
        if {[llength $rc] != 1} {
            if {$field == {aname}} {
                return <SPLIT>
            }
        }
        set rrc {}
        foreach m $rc {
            if {!$other} { set m $key }
            set acct [$tx get $m tacct]
            set nval [$ta get $acct $field]
            if {$field == "aname"} { return $nval }
            lappend rrc $nval
        }
        return $rrc
    }

    proc TransLookup {_ table args} {
        # Return keys for all matching fields. 
        upvar $_ {}
        variable pc
        set pd $(t:$table)
        if {[expr {[llength $args]%2}]} { error "Need even number args" }
        set rc {}
        foreach i [$pd children 0] {
            set n 1
            foreach {field str} $args {
                set rec [$pd get $i $field]
                if {$rec != $str} {
                    set n 0
                }
            }
            if {$n} { lappend rc $i }
        }
        return $rc
    }

    proc FillGrp {_ id} {
        # Format account name from group.
        return [TransDest $_ $id aname 1]
    }
    
    proc Update-Status {_ {ac {}}} {
        # Update the status line with account/transaction info.
        upvar $_ {}
        if {$ac == {}} {
            set ac [TreeView index $(w,aclist) focus]
        }
        if {$ac == {}} { return }
        set pa $(t:aclist)
        set aname [$pa get $ac aname]
        set n [$pa get $ac atransnums]
        set attl [$pa get $ac attl]
        set (v,status2) "$aname: $n Transactions  Balance: [Float $_ $attl]"
    }
        
    
    proc Font_ {_ type font args} {
        # Set the font.
        upvar $_ {}
        if {$font == {}} return
        foreach {fn color} $font break
        if {$type == "f"} {
            set ff TkFixedFont
        } else {
            set ff TkDefaultFont
        }
        eval font conf $ff [font actual $fn]
        return
        #TODO:
        #$(w,xaction) conf -fg $color
        #$(w,aclist) conf -fg $color
    }

    proc Fixed-Font {_} {
        # Change the fixed font.
        upvar $_ {}
        set w $(w,xaction)
        Tk::gui::Font::new -command [list $_ Font_ f] -initialfont [font conf TkFixedFont] -fg [$w cget -fg] -colors 1 -parent $(w,.)
    }
    
    proc Variable-Font {_} {
        # Change the variable font.
        upvar $_ {}
        set w $(w,xaction)
        Tk::gui::Font::new -command [list $_ Font_ v] -initialfont [font conf TkDefaultFont] -fg [$w cget -fg] -colors 1 -parent $(w,.)
    }

    proc Close {_} {
        # Close the main window.
        upvar $_ {}
        ::Delete $_
    }

    proc Backup {_} {
        # Make a backup of data.
        upvar $_ {}
        set fname [tk_chooseDirectory -parent $(w,.) -title [mc {Backup Data Directory}]]
        if {$fname == {}} return
        if {![file isdirectory $fname]} {
            file mkdir $fname
        }
        $_ Save $fname
        return
    }

    proc Open {_} {
        # Open a new ledger main window.
        upvar $_ {}
        set fname [tk_chooseDirectory -parent $(w,.) -title [mc {Accounts Data Directory}]]
        if {$fname == {}} return
        if {![file isdirectory $fname]} {
            file mkdir $fname
        }
        if {$fname == $(-dir)} {
            tk_messageBox -message [mc {Warning: Open Twice}] -type ok -parent $(w,.)
        }
        #TODO: ???
        #Load -dir $fname
        ::New [namespace current] -dir $fname
        return
    }

    proc SaveWind {_ wid} {
        # Save contents of a text widget to a file.
        upvar $_ {}
        set fname [tk_getSaveFile -parent $(w,.) -title [mc {Save To File}]]
        if {$fname == {}} return
        set fp [open $fname w+]
        puts $fp [${wid}c get 1.0 end]
        puts $fp [$wid get 1.0 end]
        close $fp
        return
    }
 
    proc SortFields {_ table field args} {
        # Return sorted indices for table by field.
        Opts p $args {
            { -dir      {}  "Direction of sort" }
            { -fname    {}  "Field name to restrict sort by" }
            { -fval     {}  "Field value to go with -fname" }
        }
        upvar $_ {}
        variable pc
        set pa $(t:aclist)
        set pd $(t:$table)
        
        #if {$p(-dir) == {}} { set p(-dir) $(-$table:sortdir) }
        if {$p(-dir) == {}} { set p(-dir) increasing }

        set rc {}
        if {[string length [set fidx $p(-fval)]]} {
            set find $pc($table:flup:$p(-fname))
        }
        if {$table == "aclist" && $field == "aid"} {
            foreach i [$pa children 0] {
                set nam [$pa get $i atransnums]
                lappend rc [list $nam $i]
            }
        } elseif {$table == "xaction" && $field == "tgroup"} {

            if {$p(-fval) != {}} {
                set lst [$pd find -key $p(-fname) -name $p(-fval)]
            } else {
                set lst [$pd children 0]
            }
            foreach i $lst {
                set nam [TransDest $_ $i aname]
                lappend rc [list $nam $i]
            }
        } else {
            if {$p(-fval) != {}} {
                set lst [$pd find -key $p(-fname) -name $p(-fval)]
            } else {
                set lst [$pd children 0]
            }
            foreach i $lst {
                lappend rc [list [$pd get $i $field] $i]
            }
        }
        set type [*value pc($table:type:$field) ascii]
        set sl [lsort -$type -$p(-dir) -index 0 $rc]
        set src {}
        foreach i $sl {
            lappend src [lindex $i 1]
        }
        return $src
    }

    proc DelGroup {_ gid} {
        # Delete transaction and it's groupmates.
        upvar $_ {}
        set ids [$(t:xaction) tag nodes grp$gid]
        foreach i $ids { $_ Del1Xact $i }
        incr (changed)
        return
    }

    proc NewGroup {_} {
        # Return a new transaction group.
        upvar $_ {}
        set pt $(t:xaction)
        set n 0
        while {1} {
            set tag grp[incr n]
            if {![$pt tag exists $tag] || [$pt tag nodes $tag] == {}} {
                return $n
            }
        }
    }
    
    proc SortSub {t i1 i2 args} {
        # Sort account compare routine.
        set c1 [$t get $i1 acatagory]
        set c2 [$t get $i2 acatagory]
        if {$c1 != $c2} {
            set rc [string compare $c1 $c2]
        } else {
            set n1 [$t get $i1 aname]
            set n2 [$t get $i2 aname]
            set rc [string compare $n1 $n2]
        }
        return $rc
    }
    
    proc Sort-Accounts {_} {
        # Sort accounts by name: non-catagory first, then catagories.
        variable pc
        upvar $_ {}
        set pa $(t:aclist)
        tree op sort $pa 0 -reorder -command [namespace current]::SortSub
    }
    

    proc Fix-Sums {_} {
        # Fixup account transactions counts
        variable pc
        upvar $_ {}
        set pa $(t:aclist)
        set pt $(t:xaction)
        foreach i [$pa children root] {
           $pa set $i atransnums 0
           set val [$pa get $i aobal]
           if {abs($val)<0.005} {
               set val 0.00
               $pa set $i aobal $val
           }
           $pa set $i attl $val
        }
        foreach i [$pt children root] {
           set tacct [$pt get $i tacct]
           set tsum [$pt get $i tsum]
           $pa incr $tacct atransnums
           $pa incr $tacct attl $tsum
        }
    }

    ########## SCHEDULED TRANSACTIONS (TODO) #################

    #proc doschedule {_ args} {
    #    # Do scheduled transactions.
    #    upvar $_ {}
    #    upvar [Var $_ schedule] ps
    #    variable pc
    #    variable pp

    #    if {$pp(-nosched)} return
    #    set now [clock scan [$_ date]]
    #    set sec_days [expr {60*60*24}]
    #    foreach i [array names ps] {
    #        foreach $pc(xaction:fields) $ps($i) break
    #        if {$tsched == {} || ![info exists p($tgroup)]} {
    #            lappend p($tgroup) $i
    #        } else {
    #            set p($tgroup) [concat $i $p($tgroup)]
    #        }
    #    }
    #    set nn $pc(xaction:flup:tsched)
    #    set ss $pc(schedule:flup:slast)
    #    #tclLog "aa [array size ps]"
    #    set (sched:cnt) 0
    #    foreach i [array names p] {
    #        set n [lindex $p($i) 0]
    #        set tsched [lindex $ps($n) $nn]
    #        #  tclLog "SCHED: $ps($n)"
    #        foreach $pc(schedule:fields) $tsched break
    #        if {$ssdate > $now} continue
    #        if {$sedate != {} && $slast && $sedate < $slast} continue
    #        set cnt 0
    #        while 1 {
    #            set oslast $slast
    #            if {!$slast} {
    #                if {$speriod != {monthly}} {
    #                    $_ sched insert $p($i) [set slast $ssdate]
    #                    #        tclLog "INS: NOMON $slast"
    #                    continue
    #                }
    #                set slast [expr {$ssdate-$sec_days}]
    #            }
    #            switch -- $speriod {
    #                daily {
    #                    set next [expr {$slast+($speriodnum*$sec_days)}]
    #                    if {$next > $now} break else {
    #                        $_ sched insert $p($i) [set slast $next]
    #                        #        tclLog "INS: DAY"
    #                    }
    #                }
    #                single {
    #                    break
    #                }
    #                monthly {
    #                    set nxt $slast
    #                    set m -1
    #                    set max [expr {$speriodnum*31}]
    #                    while {[incr m]<=$max} {
    #                        set nxt [expr {$nxt+$sec_days}]
    #                        if {$nxt > $now} break
    #                        set mday [clock format $nxt -format %d]
    #                        if {$smonthday == {specific}} {
    #                            if {$mday == $smonthdaynum} {
    #                                if {[incr cnt] >= $speriodnum} {
    #                                    set cnt 0
    #                                    $_ sched insert $p($i) [set slast $nxt]
    #                                    #    tclLog "INS: $mday == $smonthdaynum"
    #                                    break
    #                                }
    #                            }
    #                        } else {
    #                            set lnxt [expr {$nxt+$sec_days}]
    #                            set lmday [clock format $lnxt -format %d]
    #                            if {$lmday == 1} {
    #                                if {[incr cnt] >= $speriodnum} {
    #                                    set cnt 0
    #                                    $_ sched insert $p($i) [set slast $nxt]
    #                                    #    tclLog "INS: LMDAY"
    #                                    break
    #                                }
    #                            }
    #                        }
    #                        if {$nxt > $now} break
    #                    }
    #                }
    #                default { error "unknown speriod" }
    #            }
    #            if {$slast == $oslast} break
    #        }
    #        set tsched [lreplace $tsched $ss $ss $slast]
    #        set ps($n) [lreplace $ps($n) $nn $nn $tsched]
    #    }
    #    if {$(sched:cnt)} {
    #        set (v,status1) [concat [mc Applied] " $(sched:cnt) " [mc {Scheduled Transactions}]]
    #    }
    #    return
    #}


    #proc sched {_ sub args} {
    #    # Subcommands of "sched  OBSOLET"
    #    variable pc
    #    variable pp
    #    upvar [Var $_ xaction] pt
    #    upvar $_ {}
    #    if {[string equal run $sub]} {
    #        $_ doschedule
    #        after 3600000 "$_ sched run"
    #        return
    #    }
    #    if {[string equal period $sub]} {
    #        if {$(sched:speriod) == {monthly}} {
    #            set state normal
    #        } else {
    #            set state disabled
    #        }
    #        foreach i $(sched:monwids) {$i conf -state $state}
    #        return
    #    }
    #    if {[string equal monthday $sub]} {
    #        if {$(sched:smonthday) == {specific}} {
    #            set state normal
    #        } else {
    #            set state disabled
    #        }
    #        foreach i $(sched:monnumwids) {$i conf -state $state}
    #        return
    #    }
    #    if {[string equal update $sub]} {
    #        $_ sched period
    #        $_ sched monthday
    #        return
    #    }
    #    if {[string equal init $sub]} {
    #        foreach i $pc(schedule:fields) j $pc(schedule:defs) {
    #            set (sched:$i) $j
    #        }
    #        set (sched:ssdate) [$_ date]
    #        $_ sched update
    #        return
    #    }
    #    if {[string equal setfields $sub]} {
    #        set idx [lindex $args 0]
    #        if {![info exists pt($idx)]} {
    #            return [$_ sched init]
    #        }
    #        if {[set iv [lindex $pt($idx) $pc(xaction:flup:tsched)]] != {}} {
    #            foreach i $pc(schedule:fields) j $iv {
    #                #      tclLog "SE ($idx): $i $j"
    #                if {[string equal $i ssdate] || [string equal $i sedate]} {
    #                    if {$j == {}} {
    #                        set (sched:$i) $j
    #                        } else {
    #                        set (sched:$i) [clock format $j -format $pp(-datefmt)]
    #                    }
    #                } else {
    #                    set (sched:$i) $j
    #                }
    #            }
    #        }
    #        return
    #    }
    #    if {[string equal getfields $sub]} {
    #        foreach i $pc(schedule:fields) {
    #            # tclLog "SG: $i $(sched:$i)"
    #            switch -- $i {
    #                ssdate - sedate {
    #                    if {$(sched:$i) == {}} {
    #                        lappend src {}
    #                    } else {
    #                        lappend src [clock scan $(sched:$i)]
    #                    }
    #                }
    #                default { lappend src $(sched:$i) }
    #            }
    #        }
    #        return $src
    #    }
    #    if {[string equal cancel $sub]} {
    #        $_ close
    #        return
    #    }
    #    if {[string equal commit $sub]} {
    #        set cur $(xaction:cur)
    #        if {![info exists pt($cur)]} return
    #        set src [$_ sched getfields]
    #        set nn $pc(xaction:flup:tsched)
    #        set pt($cur) [lreplace $pt($cur) $nn $nn $src]
    #        return
    #    }
    #    if {[string equal done $sub]} {
    #        upvar [Var $(--schedule) schedule] ups
    #        $_ sched commit
    #        array unset ups
    #        array set ups [array get pt]
    #        set ov $(--schedule)
    #        set (changed) 0
    #        $_ close
    #        doschedule $ov
    #        return
    #    }
    #    if {[string equal insert $sub]} { 
    #        # Insert specific sched transaction to date
    #        foreach {arg now} $args break
    #        upvar [Var $_ schedule] ps
    #        upvar [Var $_ xgroup] pg
    #        incr (sched:cnt)
    #        set ngid [NewGroup $_]
    #        foreach j $arg {
    #            foreach $pc(xaction:fields) $ps($j) break
    #            $(t:aclist) incr $tacct attl $tsum
    #            $(t:aclist) incr $tacct atransnums 1
    #            set nid [incr (xaction:last)]
    #            set pt($nid) $ps($j)
    #            lappend pg($ngid) $nid
    #            $(t:xaction) set $nid tdate $now tid $nid tgroup $ngid tsched {}
    #        }
    #        incr (changed)
    #        return
    #    }
    #    error "Unknown sched cmd: $sub $args"
    #}

    ########## RECONCILE #################>>
    proc UpdReconcile {_ acct sum} {
        # Update the arbal field when deleting a reconciled transaction.
        variable pc
        upvar $_ {}
        set pa $(t:aclist)
        $pa incr $acct arbal $sum
        return
    }

    proc DiffMonth {_ d1 d2} {
        # Return 1 if month and or year is different in two dates.
        upvar $_ {}
        set m1 [clock format $d1 -format %m]
        set m2 [clock format $d2 -format %m]
        if {$m1 != $m2} { return 1 }
        set y1 [clock format $d1 -format %Y]
        set y2 [clock format $d2 -format %Y]
        if {$y1 != $y2} { return 1 }
        return 0
    }

    # "ARCHIVE TRANACTIONS"
    proc Archive {_ {close 0}} {
        # Archive transactions.
        upvar $_ {}
        set (archive:close) $close
        Tk::gui toplevel $_ -id archive
    }
    

    proc Close-Yearend {_} {
        # Archive and update yearend (TODO:).
        Archive $_ 1
    }

    proc FillPayee {_} {
        # Fill in the payee list.
        upvar $_ {}
        set wt $(w,xaction)
        set f [TreeView find $wt -notop -return tpayee]
        set f [lsort -unique -dictionary $f]
        if {[lindex $f 0] != {}} {
            set f [linsert $f 0 {}]
        }
        set (payee:listsp) $f
        return $f
    }

    proc FillAccount {_} {
        # Fill in the accounts list.
        upvar $_ {}
        set pa $(t:aclist)
        set f [$pa find -notop -return aname]
        set f [lsort -unique -dictionary $f]
        set (aclist:list) $f
        if {[lindex $f 0] != {}} {
            set f [linsert $f 0 {}]
        }
        set (aclist:listsp) $f
        set (aclist:listall) [concat <All> $(aclist:list)]
        return $f
    }

    proc Import {_} {
        # Import transactions
        #TODO: delete old or use temp tree to rename (use trace?).
        variable pc
        upvar $_ {}
        set pt $(t:xaction)
        set pa $(t:aclist)

        set fname [tk_getOpenFile -parent $(w,.) -title [mc {Transactions To Import}]]
        if {$fname == {}} return
        set dir [file dirname $fname]
        set afile [file join $dir aclist$pc(ext)]
        if {[file tail $fname] == "xaction$pc(ext)" && [file exists $afile]} {
            if {[tk_messageBox -message [mc {Import Accounts File?}] -type okcancel -parent $(w,.)] == {ok}} {
                tree op restore $(t:aclist) -file $afile
                FillAccount $_
            }
        }
        tree op restore $(t:xaction) -file $fname
        incr (changed)
        $_ Fix-Sums
        return
    }

    proc Import-QIF-Accounts {_} {
        # Import a QIF accounts file
        upvar $_ {}
        variable pc
        set pt $(t:xaction)
        set pa $(t:aclist)
        set fname [tk_getOpenFile -parent $(w,.) -title [mc {QIF Account File To Import}]]
        if {$fname == {}} return
        set fp [open $fname r]
        Cursor $_ busy
        update
        set accts {}
        set cnt 0
        set iscat 0
        set desc {}
        set name {}
        set lf [open [file join $(-dir) import.log] a+]
        puts $lf "Importing accounts from $fname"
        while {[set n [gets $fp str]]>0} {
            set ch [string index $str 0]
            set rest [string trim [string range $str 1 end]]
            if {[string match Type* $str]} continue
            if {[string match !Type:Cat* $str]} {
                set iscat 1
                puts $lf "accounts are catagories"
                continue
            }
            switch -- $ch {
                N { set name $rest }
                D { set desc $rest }
                I { set p(atype) revenue }
                E { set p(atype) expense }
                R { }
                T {
                    if {$iscat} {
                        set p(ataxed) 1
                    } else {
                        set desc $rest
                    }
                }
                ^ {
                    if {$name == {}} {
                        puts $lf "account already exists: $rest"
                    } elseif {[LookupField $_ aclist aname $name] == {}} {
                        set aid [CreateAccount $_ aname $name acatagory $iscat ainstnotes $desc]
                        lappend accts $aid
                        foreach i [array names p] {
                            $pa update $aid $i $p($i)
                        }
                        puts $lf "created account: $rest"
                    }
                    set desc {}
                    set name {}
                    array unset p
                    incr cnt
                }
            }
        }
        puts $lf {}
        close $lf
        close $fp
        set (v,status1) "$cnt [mc {account/catagories imported}]"
        Cursor $_ normal
        incr (changed)
        foreach aid $accts {
            UpdateRunTotal $_ $aid
        }
        FillAccount $_
        Sort-Accounts $_
        SelAct $_
        return
    }

    proc Export-QIF-Accounts {_ {catagories 0}} {
        # Export a QIF accounts file
        upvar $_ {}
        variable pc
        set pt $(t:xaction)
        set pa $(t:aclist)
        set fname [tk_getSaveFile -parent $(w,.) -title [mc {QIF Account File To Export}]]
        if {$fname == {}} return
        set fp [open $fname w+]
        set cnt 0
        set lf [open [file join $(-dir) import.log] a+]
        puts $lf "Exporting accounts from $fname"
        set alst [$pa find -notop]
        foreach i $alst {
            set iscat [$pa get $i acatagory]
            if {$iscat} {
                if {!$catagories} continue
            } else {
                if {$catagories} continue
            }
            set g [$pa get $i]
            array unset p
            array set p $g
            puts $fp "N$p(aname)"
            puts $fp "D$p(ainstnotes)"
            switch -- $p(atype) {
                revenue { puts $fp "I" }
                expense { puts $fp "E" }
            }
            puts $fp ^
        }
        puts $lf {}
        close $lf
        close $fp
        set (v,status1) "$cnt [mc {exported}]"
        return
    }
    
    proc Export-QIF-Catagories {_} {
        # Export a QIF catagories file
        Export-QIF-Accounts $_ 1
    }

    proc QIF-Export {_ {acct {}}} {
        # Export to QIF file.
        upvar $_ {}
        variable pc
        variable pp
        set pt $(t:xaction)
        set pa $(t:aclist)

        if {$acct == {}} {
            set acct [TreeView index $(w,aclist) focus]
        }
        if {$acct == {}} {
            tk_messageBox -message [mc {Sorry, an account must be selected first}] -type ok -parent $(w,.)
            return
        }
        set aname [$pa get $acct aname]
        set fname [tk_getSaveFile -parent $(w,.) -title [mc {QIF File To Export}]]
        if {$fname == {}} return
        set fp [open $fname w+]
        set cnt 0
        set lf [open [file join $(-dir) import.log] a+]
        puts $lf "Exporting $aname $fname"
        puts $fp "!Type:Bank"
        foreach i [$pt find -notop -key tacct -name $acct] {
            set g [$pt get $i]
            array unset p
            array set p $g
            puts $fp "D[clock format $p(tdate) -format %D]"
            puts $fp "T$p(tsum)"
            if {$p(tpayee) != {}} { puts $fp "P$p(tpayee)" }
            if {$p(tnum) != {}}   { puts $fp "N$p(tnum)" }
            if {$p(tmemo) != {}}  { puts $fp "M$p(tmemo)" }
            if {$p(treco) != {}}  { puts $fp "CR" }
            set ids [$pt tag nodes grp$p(tgroup)]
            if {[llength $ids]>=2 && [set n [lsearch $ids $i]]>=0} {
                set ids [lreplace $ids $n $n]
            } else {
                Notify $_ "invalid group: $p(tgroup)" -icon error
                break
            }
            if {[llength $ids]==1} {
                set i2 [lindex $ids 0]
                set acct2 [$pt get $i2 tacct]
                set aname [$pa get $acct2 aname]
                set ch L
            } else {
                set ch S
            }
            foreach i2 $ids {
                set acct2 [$pt get $i2 tacct]
                set aname2 [$pa get $acct2 aname]
                puts $fp "$ch$aname2"
                if {$ch == "S"} {
                    puts $fp "\$[expr {-[$pt get $i2 tsum]}]"
                }
            }
            puts $fp "^"
            incr cnt
        }
        puts $lf "$cnt transactions exported"
        puts $lf {}
        close $lf
        close $fp
        set (v,status1) "$cnt [mc {transactions exported}]"
        return
    }

    proc QIF-Import {_ {targacct {}}} {
        # Import a QIF file into cur account.
        upvar $_ {}
        variable pc
        variable pp
        set pt $(t:xaction)
        set pa $(t:aclist)

        if {$targacct == {}} {
            set targacct [TreeView index $(w,aclist) focus]
        }
        if {$targacct == {}} {
            tk_messageBox -message [mc {Sorry, an account must be selected first}] -type ok -parent $(w,.)
            return
        }
        set fname [tk_getOpenFile -parent $(w,.) -title [mc {QIF File To Import}]]
        if {$fname == {}} return
        Cursor $_ busy
        update
        set fp [open $fname r]
        set insplit 0
        set naccts {}
        foreach j $pc(xaction:fields) k $pc(xaction:defs) { set p($j) $k}
        set s 0; set cnt 0
        set lf [open [file join $(-dir) import.log] a+]
        puts $lf "Importing $fname"
        while {[set n [gets $fp str]]>0} {
            set ch [string index $str 0]
            set rest [string trim [string range $str 1 end]]
            if {[regexp {^Type} $str]} continue
            switch -- $ch {
                D {
                    if {[catch {set p(tdate) [clock scan $rest]}]} {
                        set p(tdate) []
                        puts $lf "Invalid date, using today: $str"
                    }
                }
                T {
                    set p(tsum) $rest
                    regsub -all -- , $p(tsum) {} p(tsum)
                    set p(tsum) [expr {int($p(tsum))}]
                }
                C { set p(treco) {} }
                P { set p(tpayee) $rest }
                N { set p(tnum) $rest }
                M { set p(tmemo) $rest }
                L { set p(tgroup) $rest }
                $ { regsub -all -- , $rest {} rest; set split(sum:$s) $rest }
                S {
                    incr s
                    set split(cat:$s) $rest
                }
                ^ {
                    set avals {}
                    if {$s} {
                        set accts {}
                        for {set i 1} {$i<=$s} {incr i} {
                            lappend accts $split(cat:$i)
                            lappend avals $split(cat:$i) $split(sum:$i)
                        }
                    } else {
                        set accts [list $p(tgroup)]
                        set avals [list $p(tgroup) $p(tsum)]
                    }
                    set skip 0
                    foreach i $(impaccts) {
                        if {[lsearch $accts $i]>=0} {
                            set skip 1
                        }
                    }
                    if {$skip} {
                        puts $lf "Already imported!: $str"
                    } elseif {$p(tsum) == 0} {
                        puts $lf "Skipping zero sum!: $str"
                    } else {
                        foreach i $accts {
                            if {$(catlower)} { set i [string tolower $i] }
                            set aid [LookupField $_ aclist aname $i]
                            if {$aid == {}} {
                                set aid [$_ CreateAccount aname $i acatagory 1]
                            }
                            if {[lsearch $naccts $aid]<0} {
                                lappend naccts $aid
                            }
                        }
                        set p(tid) -1
                        set p(tgroup) [NewGroup $_]
                        set p(tacct) $targacct
                        #set rc {}; foreach i $pc(xaction:fields) { lappend rc $p($i) }
                        #set pt($p(tid)) $rc
                        set gtag grp$p(tgroup)
                        set id [$pt insert 0 -data [array get p] -tags $gtag]
                        $pt update $id tid $id
                        #lappend pg($p(tgroup)) $p(tid)
                        $(t:aclist) incr $targacct attl $p(tsum)
                        $(t:aclist) incr $targacct atransnums 1
                        foreach {nacct nsum} $avals {
                            if {$(catlower)} { set nacct [string tolower $nacct] }
                            #lappend pg($p(tgroup)) $nid2
                            #set pt($nid2) $pt($p(tid))
                            set nid2 [$pt insert 0 -data [array get p] -tags $gtag]
                            $pt update $nid2 tid $nid2
                            set nsum [expr {-$nsum}]
                            set nacct [LookupField $_ aclist aname $nacct]
                            $(t:xaction) set $nid2 tacct $nacct tid $nid2 tsum $nsum
                            $(t:aclist) incr $nacct attl $nsum
                            $(t:aclist) incr $nacct atransnums 1
                        }
                        foreach j $pc(xaction:fields) k $pc(xaction:defs) { set p($j) $k}
                        set s 0
                        array unset split
                        if {![expr {[incr cnt]%10}]} {
                            set (v,status1) "$cnt [mc {imported}]"
                            update
                        }
                    }
                }
            }
        }
        puts $lf "$cnt imported"
        puts $lf {}
        close $lf
        close $fp
        set (v,status1) "$cnt [mc {imported}]"
        Cursor $_ normal
        incr (changed)
        lappend (impaccts) [LookupField $_ aclist aid $targacct aname]
        foreach aid $naccts {
            UpdateRunTotal $_ $aid
        }
        Sort-Accounts $_
        SelAct $_
        return
    }

    proc CBB-Import {_} {
        # Import a CBB file into cur account.
        upvar $_ {}
        variable pc
        variable pp
        set pt $(t:xaction)
        set pa $(t:aclist)

        set targacct [TreeView index $(w,aclist) focus]
        if {$targacct == {}} {
            tk_messageBox -message [mc {Sorry, an account must be selected first}] -type ok -parent $(w,.)
            return
        }
        set fname [tk_getOpenFile -parent $(w,.) -title [mc {CBB File To Import}]]
        set targname [LookupField $_ aclist aid $targacct aname]
        if {$fname == {}} return
        lappend (impaccts) $targname
        Cursor $_ busy
        update
        set fp [open $fname r]
        set insplit 0
        foreach j $pc(xaction:fields) k $pc(xaction:defs) { set p($j) $k}
        set cnt 0; set s 0
        set lf [open [file join $(-dir) import.log] a+]
        puts $lf "Importing $fname"
        while {[set n [gets $fp str]]>0} {
            set ch [string index $str 0]
            if {$ch == {#}} continue
            foreach {p(tdate) p(tnum) p(tpayee) debit p(tsum) cat p(tmemo) reco} [split $str \t] break
            if {$p(tsum) == {} || ![string is double $p(tsum)]} {
                set p(tsum) 0 
            }
            if {$debit == {} || ![string is double $debit]} {
                set debit 0 
            }
            if {$debit != 0.0} { set p(tsum) [expr {-$debit}] }
            if {[string equal x $reco]} { set p(treco) 1 } else { set p(treco) {} }
            if {[catch {set p(tdate) [clock scan $p(tdate)]}]} {
                set p(tdate) [clock seconds]
                puts $lf "Invalid date, using today: $str"
            }
            if {[string first | $cat]>=0} {
                foreach {sdst scmt samt} [split [string trim $cat |] |] {
                    incr s
                    if {$(catlower) && [string index $sdst 0] != "\["} {
                        set sdst [string tolower $sdst]
                    }
                    if {[set split(cat:$s) [string trim $sdst {[] }]] == {}} {
                        set split(cat:$s) Unspecified
                    }
                    set split(sum:$s) [expr {-$samt}]
                }
            } else {
                if {$(catlower) && [string index $p(tgroup) 0] != "\["} {
                    set p(tgroup) [string tolower $p(tgroup)]
                }
                if {[set p(tgroup) [string trim $cat {[] }]] == {}} {
                    set p(tgroup) Unspecified
                }
            }
            set avals {}
            if {$s} {
                set accts {}
                for {set i 1} {$i<=$s} {incr i} {
                    lappend accts $split(cat:$i)
                    lappend avals $split(cat:$i) $split(sum:$i)
                }
            } else {
                set accts [list $p(tgroup)]
                set avals [list $p(tgroup) $p(tsum)]
            }
            foreach i $accts {
                if {[LookupField $_ aclist aname $i] == {}} {
                    $_ CreateAccount aname $i acatagory 1
                }
            }
            set skip 0
            foreach i $(impaccts) {
                if {[lsearch $accts $i]>=0} {
                    set skip 1
                }
            }
            if {$p(tpayee) == {Opening Balance}} {
                $(t:aclist) set $targacct aobal $p(tsum)
                $(t:aclist) incr $targacct attl $p(tsum)
                puts $lf "Set openning balance: $str"
            } elseif {$skip} {
                puts $lf "Already imported!: $str"
            } elseif {$p(tsum) == 0} {
                puts $lf "Skipping zero sum!: $str"
            } else {
                set p(tid) [incr (xaction:last)]
                set p(tgroup) [NewGroup $_]
                set p(tacct) $targacct
                #set rc {}; foreach i $pc(xaction:fields) { lappend rc $p($i) }
                #set pt($p(tid)) $rc
                #lappend pg($p(tgroup)) $p(tid)
                set gtag grp$p(tgroup)
                set id [$pt insert 0 -data [array get p] -tags $gtag]
                $pt update $id tid $id
                $(t:aclist) incr $targacct attl $p(tsum)
                $(t:aclist) incr $targacct atransnums 1
                foreach {nacct nsum} $avals {
                    #set nid2 [incr (xaction:last)]
                    #lappend pg($p(tgroup)) $nid2
                    #set pt($nid2) $pt($p(tid))
                    set nid2 [$pt insert 0 -data [array get p] -tags $gtag]
                    $pt update $nid2 tid $nid2
                    set nsum [expr {-$nsum}]
                    set nacct [LookupField $_ aclist aname $nacct]
                    $(t:xaction) set $nid2 tacct $nacct tid $nid2 tsum $nsum
                    $(t:aclist) incr $nacct attl $nsum
                    $(t:aclist) incr $nacct atransnums 1
                }
            }
            array unset p
            foreach j $pc(xaction:fields) k $pc(xaction:defs) { set p($j) $k}
            set s 0
            array unset split
            if {![expr {[incr cnt]%10}]} {
                set (v,status1) "$cnt [mc {imported}]"
                update
            }
        }
        puts $lf {}
        close $lf
        set (v,status1) "$cnt [mc {imported}]"
        close $fp
        incr (changed)
        Sort-Accounts $_
        Cursor $_ normal
        return
    }

    proc CommitRCSFile {_ fn} {
        # RCS commit one file.
        upvar $_ {}
        variable pp
        if {!$pp(-usercs)} return
        set dir [file join $(-dir) RCS]
        if {![file isdirectory $dir]} { file mkdir $dir }
        set fn [file normalize [file join $(-dir) $fn]]
        if {[catch {exec ci -q -l $fn << Ledger} rc]} {
            tk_messageBox -message "[mc {RCS checkin failed: Disabling}]\n$rc" -type ok -parent $(w,.)
            set pp(-usercs) 0
            return
        }
        return
    }
    
    proc CommitRCS {_} {
        # RCS commit
        upvar $_ {}
        variable pp
        variable pc
        foreach ft $(trees) {
            if {!$pp(-usercs)} return
            CommitRCSFile $_ $ft$pc(ext)
        }
    }

    proc CommitCVS {_} {
        # CVS/RCS commit
        upvar $_ {}
        variable pp
        if {!$pp(-usecvs)} return
        if {![file isdirectory [file join $(-dir) CVS]]} {
            tk_messageBox -message [mc {CVS failed.  Disabling}] -type ok -parent $(w,.)
            set pp(-usecvs) 0
            return
        }
        set pwd [pwd]
        cd $(-dir)
        exec cvs -Q commit -m Ledger
        cd $pwd
        return
    }
    
    proc ListFmt {lst {pad " "}} {
        # Format list column aligned.
        foreach r $lst {
            set n -1
            foreach c $r {
                incr n
                set l [string length $c]
                if {![info exists w($n)] || $l>$w($n)} {
                    set w($n) $l
                }
            }
        }
        set rv {}
        foreach r $lst {
            set cc {}
            set n -1
            foreach c $r {
                incr n
                append cc [format %$w($n)s $c] $pad
            }
            append rv $cc \n

        }
        return $rv
    }

    
    proc DumpWindow {_ wd {type list}} { #TYPES: . _ . {choice list text align}
        # Dump treeview window as text.
        upvar $_ {}
        set c -1
        set cl {}
        foreach i [TreeView find $wd -visible] {
            set val [TreeView entry value $wd $i]
            if {$type == "text"} {
                set val [join $val " "]
            }
            lappend cl $val
        }
        switch -- $type {
            list  { return $cl }
            align { return [ListFmt $cl] }
            text  { return [join $cl \n] }
            default {
                .Warn "unknown type: $type"
            }
        }
    }
    
    proc Print-Window {_ {table xaction}} {
        # Print text dump of a treeview window to a file.
        #TODO: reformat to align columns.
        upvar $_ {}
        set wd $(w,$table)
        set data [DumpWindow $_ $wd align]
        set fname [tk_getSaveFile -parent $(w,.) -title [mc {Print To File}]]
        if {$fname == {}} return
        set fp [open $fname w+]
        puts $fp $data
        close $fp
    }

    proc LoadConf {_ {dir {}}} {
        # Load config options from directory.
        # Assume suser may have edited the data.
        upvar $_ {}
        variable pc
        variable pp
        variable Opts
        variable Config
        if {$dir == {}} { set dir $(-dir) }
        set fn [file join $dir $pc(prefsfile)]
        if {![file exists $fn]} return
        if {[catch {
            set data [read [set fp [open $fn]]]
        } erc]} {
            tclLog "LoadConf error: $erc"
            return
        }
        if {[llength $data]%2} {
            .Warn "odd length config"
        }
        catch { close $fp }
        foreach {nam val} $data {
            set op($nam) $val
        }
        # User-edit may use strings where int/bool is expected, so coerce types.
        Opts tp [array get op] $Config -force 2
        foreach nam [array names op] {
            set pp($nam) $tp($nam)
        }
        if {$pp(-fontfix) != {}} {
            #*catch { eval font conf TkFixedFont $pp(-fontfix) }
        }
        if {$pp(-fontvar) != {}} {
            #*catch { eval font conf TkDefaultFont $pp(-fontvar) }
        }
        # Check -datefmt is valid.
        if {[*catch { clock format 0 -format $pp(-datefmt) } ]} {
            set pp(-format) %Y-%m-%d
        }
        foreach {nam val} $pp(-iopts) {
            if {![info exists ($nam)]} {
                .Warn "unknown -iopt: $nam"
            } else {
                set ($nam) $val
            }
        }
        return
    }

    proc SaveConf {_ {dir {}}} {
        # Save configuration
        upvar $_ {}
        variable pc
        variable pp
        set pp(-geom) [winfo geometry $(w,.)]
        foreach ft $(trees) {
            set ff [string index $ft 0]
            if {[info exists (w,$ft)]} {
                # Save treeview config.
                set w $(w,$ft)
                set ww {}
                foreach i [TreeView column names $w] {
                    set wv [TreeView column cget $w $i -width]
                    if {$wv != 0} {
                        lappend ww $i $wv
                    }
                }
                set pp(-${ff}widths) $ww
                set pp(-${ff}sortconf)
                set sc {}
                foreach i [TreeView sort conf $w] {
                    set val [lindex $i 4]
                    if {$val == {}} continue
                    lappend sc [lindex $i 0] $val
                }
                set pp(-${ff}sortconf) $sc
            }
        }
        set pp(-fontfix) [font conf TkFixedFont]
        set pp(-fontvar) [font conf TkDefaultFont]
        set pp(-panewidth) [Panedwindow sash coord $(w,painmain) 0]
        if {$dir == {}} { set dir $(-dir) }
        set fn [file join $dir $pc(prefsfile)]
        set fp [open $fn w+]
        foreach i [lsort [array names pp]] {
            puts $fp [list $i $pp($i)]
        }
        close $fp
    }

    proc Save {_ {dir {}}} {
        # Save accounts and transactions.
        upvar $_ {}
        variable pp
        if {$(nosave)} {
            Notify $_ "Save is disabled"
            return
        }
        set isbak 1
        Cursor $_ busy
        update
        if {$dir == {}} {
            set isbak 0
            set dir $(-dir)
            SaveConf $_
        }
        SaveTrees $_ $dir
        #SaveDB $_ $dir
        set tim [clock format [clock seconds] -format %T]
        if {!$isbak} {
            set (changed) 0
            if {$pp(-usecvs)} { $_ CommitCVS }
            if {$pp(-usercs)} { $_ CommitRCS }
            set msg "[mc Saved]: $tim"
        } else {
            set msg "[mc Backup]: $tim"
        }
        set (v,status1) $msg
        Cursor $_ normal
        return
    }

    ######## MANIPULATE TABLE RECORDS ########

    proc LookupField {_ table field val {fname {}}} {
        # Lookup data field table.
        upvar $_ {}
        set pd $(t:$table)
        if {$fname == {}} {
            return [$pd find -key $field -name $val -limit 1]
        }
        return [$pd find -key $field -name $val -limit 1 -return $fname]
    }
    
    proc CreateAccount {_ args} {
        # Create a new account.
        variable pc
        upvar $_ {}
        set pa $(t:aclist)

        set table aclist
        foreach nam $pc(aclist:fields) val $pc(aclist:defs) { set p($nam) $val }
        foreach {nam val} $args { set p($nam) $val }
        if {$p(aname) == {}} { error "aname field missing" }
        if {[TransLookup ${_} aclist aname $p(aname)] != {}} {
            error "duplicate account"
        }
        set aid [$pa insert 0 -data [array get p]]
        $pa set $aid aid $aid
        return $aid
    }

    proc DelAcct {_ acct} {
        # Delete an account and its trans.
        variable pc
        upvar $_ {}
        set pa $(t:aclist)
        set pt $(t:xaction)
        
        foreach i [TransLookup $_ xaction tacct $acct] {
            set gid [$pt get $i tgroup]
            foreach j [TransLookup $_ xaction tgroup $gid] {
                $_ Del1Xact $j
            }
        }
        $pa delete $acct
        incr (changed)
        return
    }

    proc UpdateRunTotal {_ {acur {}}} {
        # Update running total or balance.
        upvar $_ {}
        set pa $(t:aclist)
        set pt $(t:xaction)
        if {[$pa size 0]<=1} return

        if {$acur == {}} {
            set acur [TreeView index $(w,aclist) focus]
        }
        if {$acur == {}} return
        set indlist [SortFields $_ xaction tdate -fname tacct -fval $acur -dir increasing]
        set ttl [$pa get $acur aobal]
        $pt sum -runtotal truntot -start $ttl -diff 0.005 $indlist tsum
        return
        
        #set rc $ttl
        #foreach id $indlist {
        #    set new [$pt get $id tsum]
        #    set ttl [expr {$ttl+$new}]
        #    $pt update $id truntot $ttl
        #}
    }

    proc AcctSumAdj {_ id acct {add 1}} {
        # Adjust the account sum/count by the transaction sum
        upvar $_ {}
        set pa $(t:aclist)
        set pt $(t:xaction)
        
        set tsum [$pt get $id tsum]
        if {$add} {
            $pa incr $acct atransnums
            $pa incr $acct attl $tsum
        } else {
            $pa incr $acct atransnums -1
            $pa incr $acct attl [expr {-$tsum}]
        }
        UpdateRunTotal $_ $acct
    }
 
    proc Del1Xact {_ id {updopen False}} {
        # Delete 1 transaction (Should use AcctSumAdj ???)
        upvar $_ {}
        set pt $(t:xaction)
        set pa $(t:aclist)
        
        set aid   [$pt get $id tacct]
        set tsum  [$pt get $id tsum]
        set treco [$pt get $id treco]
        $pt delete $id
        if {![$pa exists $aid]} return
        $pa incr $aid attl [expr {-$tsum}]
        $pa incr $aid atransnums -1
        set anum [$pa get $aid anum]
        if {$updopen && [string is integer $anum] && $anum < 8000} {
            $pa incr $aid aobal $tsum
        }
        if {$treco != {}} { catch {$_ UpdReconcile $aid $tsum} }
        return
    }


    proc MoveFocus {_ table} {
        # Move the focus down if possible, else up.
        upvar $_ {}
        set t $(w,$table)
        set idx [TreeView index $t focus]
        if {$idx == {}} return
        blt::tv::MoveFocus $t down
        set nidx [TreeView index $t focus]
        if {$idx == $nidx} {
            blt::tv::MoveFocus $t up
            set nidx [TreeView index $t focus]
        }
        if {$idx == {}} return
        TreeView tag delete $t curfocus [TreeView find $t -visible]
        TreeView tag add $t curfocus $nidx

    }
    
    proc Delete-Account {_ {acct {}}} {
        # Delete an account and its trans.
        upvar $_ {}
        if {$acct == {}} {
            set acct [TreeView index $(w,aclist) focus]
        }
        if {$acct == {}} { return 0 }
        if {[tk_messageBox -message [mc {Ok to delete account and it's transactions?}] -type yesno -parent $(w,.)] != "yes"} {
            return 0
        }
        MoveFocus $_ aclist
        DelAcct $_ $acct
        FillAccount $_
        set (v,status1) [mc {Account deleted}]
        return 1
    }

    proc Make-Catagories {_} {
        # Create the default catagory accounts.
        variable pc
        variable pp
        upvar $_ {}
        set n 0
        if {[Notify $_ "[mc {Ok to create the default catagory-accounts?}]" -type yesno] != "yes"} return
        set lower [Notify $_ "[mc {Make catagory names lower-case?}]" -type yesno -default no]
        foreach i $pc(catagories) {
            set i [mc $i]
            if {$lower} { set i [string tolower $i] }
            if {![catch {$_ CreateAccount aname $i acatagory 1}]} {
                incr n
                lappend (aclist:list) $i
            }
        }
        Sort-Accounts $_
        set (v,status1) " $n [mc {catagories}]"
    }
    
    proc New-Account {_} {
        # Create a new account.
        upvar $_ {}
        set (edit:atype) new
        Tk::gui toplevel $_ -id editacct
        #account $_ new
    }
    
    proc Edit-Account {_} {
        # Edit an existing account.
        upvar $_ {}
        set (edit:atype) edit
        Tk::gui toplevel $_ -id editacct
    }

    proc Edit-Acc {_} {
        # Edit clicked on account if not in title.
        upvar $_ {}
        set act [TreeView index $(w,aclist) current]
        if {$act == {}} { return }
        return [Edit-Account $_]
    }
        
    proc Reports {_} {
        # Display the reports dialog.
        upvar $_ {}
        Tk::gui toplevel $_ -id reports
    }

    proc Hide-Catagories {_} {
        # Toggle showing of catagory accounts.
        upvar $_ {}
        variable pp
        set a $(w,aclist)
        set ids [TreeView find $a -column acatagory -name 1]
        if {$pp(-hidecat)} {
            TreeView hide $a $ids
        } else {
            TreeView show $a $ids
        }
    }

    
    proc Show-Menu {_} {
        # Toggle showing of menu.
        upvar $_ {}
        set mm [$(w,.) cget -menu]
        if {$(menu:main) == {}} {
            set (menu:main) $mm
        }
        $(w,.) conf -menu [expr {$mm == {} ? $(menu:main) : ""}]
    }
    
    proc Show-Statusbar {_}  {
        # Toggle showing of statusbar.
        upvar $_ {}
        Tk::gui win toggle $_ statusbar
    }
    
    proc Show-Toolbar {_} {
        # Toggle showing of toolbar.
        upvar $_ {}
        Tk::gui win toggle $_ toolbar
    }
    
    proc ShowAcct {_ account {curid {}}} {
        # Show only transaction for account.
        upvar $_ {}
        set t $(w,xaction)
        set pt $(t:xaction)
        TreeView hide $t all
        TreeView show $t -column tacct -name $account
        if {$curid != {} && [$pt exists $curid]} {
            TreeView entry select $t $curid
        }
    }

    proc SelAct {_} {
        # Handle change of selected account and make visible its transactions.
        upvar $_ {}
        set a $(w,aclist)
        set t $(w,xaction)
        set pt $(t:xaction)
        set pa $(t:aclist)
        
        set oid [TreeView index $t focus]
        $pt tag delete curfocus [TreeView find $t -visible]
        if {$oid != {}} {
            $pt tag add curfocus $oid
        }
        set id [TreeView index $a focus]
        if {$id == {}} return
        $pa tag delete curfocus curfocus
        $pa tag add curfocus $id
        set ac [TreeView entry set $a $id aid]
        TreeView hide $t all
        TreeView show $t -column tacct -name $ac
        update
        # TODO: the rest could be done with an [after].
        set id [TreeView find $t -visible -withtag curfocus]
        if {$id != {}} {
            TreeView entry select $t [lindex $id 0]
        } else {
            set id [TreeView index $t top]
            if {$id != {}} {
                TreeView entry select $t $id
                $pt tag add curfocus $id
            }
        }
        Update-Status $_ $ac
    }
    
    proc SetupTree {_ l t} {
        # Initialize treeview state.
        upvar $_ {}
        variable pc
        variable pp
        set a $(w,aclist)
        set x $(w,xaction)
        upvar [namespace current]::$l vvv
        set ll [string index $l 0]
        foreach i $vvv(description) {
            set nam [lindex $i 0]
            array unset q
            set q(-label) [expr {[lindex $i 2]!=""?[lindex $i 2]:$nam}]
            array set q { -type {} -fmt {} }
            array set q [lrange $i 3 end]
            set h [expr {[lsearch $pp(-${ll}columns) $nam]<0}]
            set ltyp [string tolower [lindex $q(-type) 0]]
            set creg {}
            switch -- $ltyp {
                int {
                    set just right
                    set mode integer
                }
                float - double {
                    set just right
                    set mode real
                    set creg {-* Red}
                }
                default {
                    set just left
                    set mode dictionary
                }
            }
            if {$nam == "treco"} { set just center }
            TreeView column insert $t end $nam -title $q(-label) -hide $h -justify $just -command {blt::tv::SortColumn %W %C} -sortmode $mode -colorpattern $creg
            if {$q(-fmt) != {}} {
                if {$q(-fmt) == "FillGrp"} {
                    set vv %#
                } else {
                    set vv %V
                }
                TreeView style create textbox $t $nam -formatcmd [list $_ $q(-fmt) $vv]
                TreeView column conf $t $nam -style $nam
            }
                    
            styles item $t column $nam
        }
        # Apply saved widths and positions.
        set n 0
        foreach i $pp(-${ll}columns) {
            *catch { TreeView column move $t $i [incr n] }
        }
        foreach {i j} $pp(-${ll}widths) {
            *catch { TreeView column conf $t $i -width $j }
        }
        TreeView conf $t -flat 1
    }
    
    ##########################################################################

    proc Cleanup {_} {
        # Handle teardown of ledger.
        upvar $_ {}
        if {$(changed)} {
            set rv [Notify $_ "Save changes before quitting?" -type yesnocancel]
            switch -- $rv {
                yes {
                    Save $_
                }
                no {
                    set (changed) 0
                    SaveConf $_
                }
                cancel {
                    return -code break
                }
            }
        }
    }

    proc SetupView {_} {
        # Restore saved view setting options.
        upvar $_ {}
        variable pc
        variable pp
        if {$pp(-panewidth) != {}} {
            *catch { eval Panedwindow sash place $(w,painmain) 0 $pp(-panewidth) }
        }
        if {!$pp(-hasmenu)} { Show-Menu $_ }
        if {!$pp(-hastoolbar)} { Show-Toolbar $_ }
        if {!$pp(-hasstatus)} { Show-Statusbar $_ }
        if {$pp(-hidecat)} { Hide-Catagories $_ }
        foreach {i j} {xaction x aclist a} {
            if {[set ii $pp(-${j}sortconf)] != {}} {
                *catch {eval [list TreeView sort conf $(w,$i)] $ii }
                TreeView sort auto $(w,$i) yes
            }
        }
    }
    
    proc Main {_ args} {
        # Program startup.
        upvar $_ {}
        variable pc
        variable pp
        EXT Main 0
        LoadConf $_
        if {$pp(-geom) != {}} {
            *catch { wm geometry $(w,.) $pp(-geom) }
        }
        set ei [lindex [split $_ _] end]
        set a $(w,aclist)
        set x $(w,xaction)
        set (t:sched) [tree create sched_$ei]
        $(t:sched) label 0 0
        foreach l {aclist xaction} {
            set t $(w,$l)
            set (t:$l) [tree create ${l}_$ei]
            $(t:$l) label 0 0
            SetupTree $_ $l $t
        }
        DoLoad $_ $(-dir)
        wm title $(w,.) "[mc Ledger]: $(-dir)"
        set pa $(t:aclist)
        #$pa sort 0 -key anum -reorder
        foreach l {aclist xaction} {
            set t $(w,$l)
            TreeView conf $(w,$l) -tree $(t:${l})
        }
        set (aclist:list) [lsort -dictionary [$pa find -notop -return aname]]
        set (aclist:listsp) [concat {{}} $(aclist:list)]
        set tx $(w,xaction)
        TreeView style create textbox $a noncat
        styles item $a style noncat
        foreach i [$pa find -key acatagory -name 0] {
            #TreeView entry conf $a $i -style noncat
            TreeView style set $a noncat aname $i
        }
        TreeView hide $tx all
        focus $(w,aclist)
        set acur [$(t:aclist) firstchild 0]
        if {$acur != -1} {
            update
            TreeView entry select $(w,aclist) $acur
            TreeView show $tx -name $acur -column tacct
        }
        #bind $(w,aclist) <Double-1> [list $_ SelAct @%x,%y]
        bind $(w,aclist) <<TreeViewFocusEvent>> [list $_ SelAct]
        if {[TreeView tag exists $a curfocus]} {
            set aid [lindex [TreeView tag nodes $a curfocus] 0]
            TreeView entry select $a $aid
        }
        SetupView $_
        SelAct $_
        FillPayee $_
        FillAccount $_
        EXT Main 1
        set (v,status1) "Loaded $(-dir)"
    }
    
    proc Calculator {_} {
        # Display the calculator.
        Tk::gui::calculator::new
    }
    
    proc Calendar {_} {
        # Display the calendar.
        Tk::gui::calendar::new
    }
    
    proc CurTrans {_} {
        # Get the current transaction id.
        upvar $_ {}
        set wa $(w,aclist)
        set wx $(w,xaction)
        set acct [TreeView index $wa focus]
        if {$acct == {}} { return -1 }
        set id [TreeView index $wx focus]
        if {$id == {}} { return -1 }
        return $id
    }
    
    proc New-Transaction {_ {type new}} {
        # Create a new transaction.
        upvar $_ {}
        if {[$(t:aclist) size root] < 3} {
            Notify $_ "Must create at least 2 accounts first"
            return
        }
        set (edit:xtype) $type
        Tk::gui toplevel $_ -id editxact
    }
    
    proc New-Transaction-Date {_} {
        # Create a new transaction with current date.
        upvar $_ {}
        if {[CurTrans $_]<0} return
        New-Transaction $_ newdate
    }
    
    proc Edit-Transaction {_} {
        # Edit current transaction.
        upvar $_ {}
        if {[CurTrans $_]<0} return
        set (edit:xtype) edit
        Tk::gui toplevel $_ -id editxact
    }
    
    proc Edit-Trans {_} {
        # Edit transaction clicked on if not in title.
        upvar $_ {}
        set act [TreeView index $(w,xaction) current]
        if {$act == {}} return
        return [Edit-Transaction $_]
    }
    
    proc Delete-Transaction {_ {id {}}} {
        # Delete a transaction.
        upvar $_ {}
        if {[CurTrans $_]<0} return
        if {$id == {}} {
            set id [TreeView index $(w,xaction) focus]
        }
        if {$id == {}} { return 0 }
        set on {}
        if {[tk_messageBox -message [mc {Ok to delete transaction?}] -type yesno -parent $(w,.)] != {yes}} {
            return 0
        }
        MoveFocus $_ xaction
        set gid [$(t:xaction) get $id tgroup]
        $_ DelGroup $gid
        UpdateRunTotal $_
        return 1
    }
    
    proc Move-Transaction {_} {
        # Move transaction.
        upvar $_ {}
        if {[CurTrans $_]<0} return
        Tk::gui toplevel $_ -id movexact
    }
        
    proc Scheduled-Transactions {_} {
        # Scheduled transactions dialog.
        upvar $_ {}
        Tk::gui toplevel $_ -id schedxact

    }
    
    proc About {_} {
        # Display version and copyright.
        upvar $_ {}
        variable pc
        Notify $_ "Ledger $pc(version).$pc(vercvs)\nBSD Copyright 2009\nPeter MacDonald"
    }

    proc Reconcile {_} {
        # Reconciliation dialog.
        upvar $_ {}
        if {[set idx [TreeView index $(w,xaction) focus]] == {}} {
            return
        }
        if {[$(t:xaction) get $idx treco] != {}} {
            Notify $_ "Select last un-reconciled transaction for end-date"
            return
        }
        Tk::gui toplevel $_ -id reconcile
    }
    
    proc Clear-Reconcile {_} {
        # Clear reconciled flag.
        upvar $_ {}
        set pt $(t:xaction)
        set pa $(t:aclist)
        if {[set idx [TreeView index $(w,xaction) focus]] == {}} return
        if {[set acc [TreeView index $(w,aclist) focus]] == {}} return
        if {[$pt get $idx treco] == {}} {
            Notify $_ "Current transaction is not reconciled"
            return
        }
        if {[Notify $_ "Remove reconciled flag" -type okcancel] != "ok"} {
            return
        }
        $pt update $idx treco ""
        $pa incr $acc arbal [expr {-[$pt get $idx tsum]}]
    }
    
    proc Update-RunTotals {_} {
        # Update balances for all accounts.
        upvar $_ {}
        set pa $(t:aclist)
        foreach acct [$pa find -notop] {
            UpdateRunTotal $_ $acct
        }
    }
    
    
    
    ###########################################################
    ######################     DIALOGS    #####################
    ###########################################################
    
    

    # EDIT ACCOUNT
    namespace eval Edita {
        
        Mod upvars _ pc pp
        Mod uses ..
        
        proc Main {_} {
            upvar $_ {}
            variable pp
            variable pc
            set wa $(w,aclist)
            set pa $(t:aclist)
            set sub $(edit:atype)
            if {$sub == "new"} {
                foreach nam $pc(aclist:fields) val $pc(aclist:defs) {
                    set (v,eda_$nam) $val
                }
            } else {
                set id [TreeView index $wa focus]
                if {$id == {}} return
                set (cur:edita) $id
                foreach {nam val} [$pa get $id] {
                    if {[info exists (v,eda_$nam)]} {
                        set (v,eda_$nam) $val
                    }
                }
            }
            focus $(w,eda_aname)
            EXT Edita Main
        }
        
        proc Ok {_ {dup 0}} {
            upvar $_ {}
            variable pc
            set wt $(w,xaction)
            set pa $(t:aclist)
            set sub $(edit:atype) 
            set acct $(cur:edita)
            foreach {i val} [array get {} v,eda_*] {
                set name [string range $i 6 end]
                switch -- $name {
                    aobal {
                        if {$val == {}} {
                            set (v,eda_aobal) 0
                        } else {
                            if {![string is double $val]} {
                                Notify $_ "[mc {Invalid opening balance}]: $val"
                                return
                            }
                        }
                    }
                    arbal {
                        if {$val == {}} {
                            set (v,eda_acbal) 0
                        } else {
                            if {![string is double $val]} {
                                Notify $_ "[mc {Invalid reconciled balance}]: $val"
                                return
                            }
                        }
                    }
                    acbal {
                        if {$val == {}} {
                            set (v,eda_acbal) 0
                        } else {
                            if {![string is double $val]} {
                                Notify $_ "[mc {Invalid closing balance}]: $val"
                                return
                            }
                        }
                    }
                    atype {
                        if {[set vind [lsearch $pc(aclist:types) $val]] < 0} {
                            Notify $_ "[mc {Invalid account type}]:  $val"
                            return
                        }
                    }
                    anum {
                        if {[string length $val]} {
                            set id [TransLookup $_ aclist anum $val]
                            if {$sub == "new" || $acct != $id} {
                                if {$id != {}} {
                                    Notify $_ [mc {Duplicate account number}]
                                    return
                                }
                            }
                        }
                    }
                    aname {
                        if {![string length $val]} {
                            Notify $_ [mc {missing name}]
                            return
                        }
                        set id [TransLookup $_ aclist aname $val]
                        if {$sub == "new" || $acct != $id} {
                            if {$id != {}} { return [mc {Duplicate account name}] }
                        }
                    }
                }
            }
            EXT Edita Ok

            if {$sub == "new"} {
                set id [$pa insert 0 -names $pc(aclist:fields) -values $pc(aclist:defs)]
            } else {
                set id $(cur:edita)
                if {$id == {}} return
            }
            foreach {nam val} [$pa get $id] {
                if {[info exists (v,eda_$nam)]} {
                    $pa supdate $id $nam $(v,eda_$nam)
                }
            }
            if {$sub == "new"} {
                $pa update $id aid $id
            }
            Tk::gui dialogclose $_
            if {$sub == "new"} {
                set (v,status1) [mc {Account created}]
            } else {
                set (v,status1) [mc {Account updated}]
            }
            $_ UpdateRunTotal $acct
            $_ FillAccount
            $_ Sort-Accounts
            if {$sub != "new"} {
                $_ Refresh
            }
            set sty [expr {[$pa get $id acatagory] ? "" : "noncat"}]
            TreeView style set $(w,aclist) $sty aname $id
            #TreeView entry conf $(w,aclist) $id -style $sty
            incr (changed)
            $_ Fix-Sums
            return
        }

        
        proc Cancel {_} {
            Tk::gui dialogclose $_
        }
        
        proc Delete {_} {
            upvar $_ {}
            variable pc
            set pa $(t:aclist)
            set id $(cur:edita)
            if {$id == {}} return
            if {![Delete-Account $_ $id]} {
                return
            }
            Tk::gui dialogclose $_
        }
        
    }
    
    # EDIT TRANSACTION
    namespace eval Editx {
        
        Mod upvars _ pc pp
        Mod uses ..
        
        proc FillXact {_} {
            # Fill in transaction with latest matching payee.
            upvar $_ {}
            set t $(t:xaction)
            set tpayee $(v,edx_tpayee)
            if {$(v,edx_tdest) != {} || $(v,edx_tsum) != {}} return
            set acct $(edit:acct)
            #set ais [$t find -key tacct -name $acct]
            #if {$ais=={}} return
            set ids [$t find -key tpayee -name $tpayee]
            if {$ids == {}} return
            set min 0
            set cur {}
            foreach i $ids {
                set d [$t get $i tdate]
                if {$d>$min || ($d == $min && [string equal $acct [$t get $i tacct]])} {
                    set min $d
                    set cur $i
                }
            }
            if {$cur == {}} return
            set tsum [$t get $cur tsum]
            set (v,edx_tsum) $tsum
            set tgroup [$t get $cur tgroup]
            set lst {}
            foreach i [$t tag nodes grp$tgroup] {
                if {$i == $cur} continue
                lappend lst $i
            }
            set (edit:sums) [list $tsum $acct]
            foreach i $lst {
                lappend (edit:sums) [$t get $i tsum] [$t get $i tacct]
            }
            if {[llength $lst]==1} {
                set aid [$t get $lst tacct]
                set (v,edx_tdest) [$(t:aclist) get $aid aname]
                Spinbox conf $(w,edx_tdest) -state normal
            } else {
                set (v,edx_tdest) "<SPLIT>"
                Spinbox conf $(w,edx_tdest) -state disabled
            }
        }
        
        proc Open {_} {
            # Fill in fields for transaction edit.
            upvar $_ {}
            variable pp
            variable pc
            set wt $(w,xaction)
            set wa $(w,aclist)
            set wd $(w,edx_tdest)
            set pt $(t:xaction)
            
            set acct [TreeView index $wa focus]
            if {$acct == {}} return
            set (edit:acct) $acct
            set sub $(edit:xtype)
            set isedit 0
            Spinbox conf $wd -state readonly
            set (v,edx_tdest) {}
            set (v,edx_treco) {}
            #focus $(w,edx_tsum)
            focus $(w,edx_tpayee)
            switch -- $sub {
                edit {
                    set (v,edx_label) [mc "Edit Transaction:"]
                    Button conf $(w,edx_dup) -state normal
                    set isedit 1
                    set id [TreeView index $wt focus]
                    if {$id == {}} return
                    if {[$pt get $id tacct] != $acct}  return
                    set vals [$pt get $id]
                    set (edit:data) $vals
                    set (cur:edit) $id
                    set gid [$pt get $id tgroup]
                    set sums {}
                    set (edit:sums) [list [$pt get $id tsum]  $acct]
                    set (edit:ids) $id
                    foreach i [$pt tag nodes grp$gid] {
                        if {$i == $id} continue
                        lappend (edit:ids) $i
                        lappend (edit:sums) [$pt get $i tsum] [$pt get $i tacct]
                    }
                    foreach {nam val} $vals {
                        switch -- $nam {
                            treco {
                                if {$val != {}} {
                                    set val [clock format $val -format $pp(-datefmt)]
                                }
                            }
                            tdate {
                                set val [clock format $val -format $pp(-datefmt)]
                            }
                            tgroup {
                                if {$isedit} {
                                    set ss [$_ FillGrp $id]
                                    set (v,edx_tdest) $ss
                                    if  {$ss=="<SPLIT>"} {
                                        Spinbox conf $wd -state disabled
                                    }
                                }
                            }
                        }
                        if {[info exists (v,edx_$nam)]} {
                            set (v,edx_$nam) $val
                        }
                    }
                }
                new - newdate {
                    set (v,edx_label) [mc "New Transaction:"]
                    Button conf $(w,edx_dup) -state disabled
                    set vals {}
                    set (edit:sums) [list 0 $acct 0 {}]
                    set (edit:ids) {}
                    #if {$(edit:lastacc) == {}} {
                    #    set (edit:lastacc) [lindex $(aclist:list) 0]
                    #}
                    #set (v,edx_tdest) $(edit:lastacc)
                    foreach nam $pc(xaction:fields) val $pc(xaction:defs) {
                        lappend vals $nam $val
                        switch -- $nam {
                            tdate {
                                if {$sub == "new"} {
                                    set val [clock seconds]
                                } else {
                                    set id [TreeView index $(w,xaction) focus]
                                    set val [$pt get $id tdate]
                                }
                                set val [clock format $val -format $pp(-datefmt)]
                            }
                        }
                        if {[info exists (v,edx_$nam)]} {
                            set (v,edx_$nam) $val
                        }
                    }
                    set (edit:data) $vals
                }
            }
            Entry  icursor $(w,edx_tsum) 0
            Entry  selection range $(w,edx_tsum) 0 end
            EXT Editx Open
        }
        
        proc Main {_} {
            # Begin transaction edit.
            upvar $_ {}
            variable pp
            Tk::gui::calendar::bindings $(w,edx_tdate) $pp(-datefmt)
            bind $(w,edx_tpayee) <Tab> [list [namespace current]::FillXact $_]
            EXT Editx Main
            Open $_
        }

        
        proc DateSel {_ {val {}}} {
            # Date selection dialog.
            upvar $_ {}
            if {$val != {}} {
                set (v,edx_tdate) $val
                return
            }
            ::Tk::gui::calendar::new -command [list [namespace current]::DateSel $_] -parent $(w,.)
        }
        
        proc CalcSel {_ {val {}}} {
            # Calculator dialog.
            upvar $_ {}
            if {$val != {}} {
                set (v,edx_tsum) $val
                return
            }
            ::Tk::gui::calculator::new -command [list [namespace current]::CalcSel $_]  -parent $(w,.)
        }
        
        proc Ok {_ {dup 0}} {
            # Complete transaction editing.
            variable pc
            upvar $_ {}
            set pt $(t:xaction)
            set pa $(t:aclist)
            set wt $(w,xaction)
            set sub $(edit:xtype)
            set acct $(edit:acct)
            set isedit 0
            set res {}
            if {[set id [lindex $(edit:ids) 0]] != {}} {
                set tgrp [$pt get $id tgroup]
            } else {
                set tgrp [$_ NewGroup]
            }
            array set d $(edit:data)
            #set (edit:lastacc) $(v,edx_tdest)
            foreach {nam oval} [array get d] {
                if {$nam == "tgroup"} {
                    set val $(v,edx_tdest)
                } elseif {[info exists (v,edx_$nam)]} {
                    set val $(v,edx_$nam)
                } else {
                    continue
                }
                switch -- $nam {
                    tsum {
                        if {![string is double -strict $val]} {
                            Notify $_ "[mc {Amount is not a number}]: $val"
                            return
                        }
                        set val [format %.2f $val]
                    }
                    tdate {
                        if {[catch { clock scan $val } tval]} {
                            Notify $_ "[mc {Date error}]: $tval"
                            return
                        }
                        set val $tval
                    }
                    tgroup {
                        if {$val == "<SPLIT>"} {
                        } elseif {$val == ""} {
                            Notify $_ "[mc {Account must be specified}]"
                            return
                        } else {
                            .Assert {[llength $(edit:sums)]==4}
                            set aid [LookupField $_ aclist aname $val aid]
                            if {$aid == {}} {
                                Notify $_ "[mc {Account is invalid}]: $val"
                                return
                            }
                            if {$aid == $(edit:acct)} {
                                $_ Notify "[mc {Account source and dest must be different}]"
                                return 
                            }
                            #set (edit:sums) [lreplace $(edit:sums) 3 3 $aid]
                            set sum $(v,edx_tsum)
                            set nsum [expr {-$sum}]
                            set (edit:sums) [list $sum $acct $nsum $aid]
                        }
                        set val $tgrp
                        #set nam tgroup
                    }
                }
                set d($nam) $val
            }
            EXT Editx Ok
            set ls [expr {[llength $(edit:sums)]/2}]
            set ids $(edit:ids)
            set li [llength $ids]
            set accs {}
            #tclLog "ESU: $(edit:sums)"
            # Add or subtract ids.
            if {$li<$ls} {
                set n [expr {[llength $(edit:ids)]*2-1}]
                while {$li<$ls} {
                    set d(tsum) [format %.2f [lindex $(edit:sums) [incr n]]]
                    set d(tacct) [lindex $(edit:sums) [incr n]]
                    set data [array get d]
                    set id [$pt insert 0 -data $data -tags grp$tgrp]
                    $pa incr $d(tacct) attl $d(tsum)
                    $pa incr $d(tacct) atransnums 1
                    lappend accs $d(tacct)
                    if {$n>1} {
                        TreeView hide $wt $id
                    }
                    $pt update $id tid $id
                    #tclLog "CREATE($id) [$pt get $id]"
                    lappend ids $id
                    incr li
                }
            } elseif {$li>=$ls} {
                while {$li>$ls} {
                    set eidx [lindex $ids end]
                    array set e [$pt get $eidx]
                    $pa incr $e(tacct) attl [expr {-$e(tsum)}]
                    $pa incr $e(tacct) atransnums -1
                    lappend accs $e(tacct)
                    $pt delete $eidx
                    set (edit:ids) [lrange $(edit:ids) 0 end-1]
                    incr li -1
                }
            }
            # Update the existing id fields.
            # Minimize updates eg. might be using sqlite on the backend.
            set n -2
            foreach i $(edit:ids) {
                array set o [$pt get $i]
                incr n 2
                foreach nam $pc(xaction:fields) {
                    set val $d($nam)
                    switch -- $nam {
                        tid - treco continue
                        tsum {
                            set val [format %.2f [lindex $(edit:sums) $n]]
                        }
                        tacct {
                            set val [lindex $(edit:sums) [expr {$n+1}]]
                        }
                    }
                    if {![string equal $o($nam) $val] || $nam == "tgroup"} {
                        #tclLog "UPDATE($i) $nam = $val"
                        $pt update $i $nam $val
                    }
                }
                $pa incr $o(tacct) attl [expr {-$o(tsum)}]
                $pa incr $o(tacct) atransnums -1
                $pa incr $d(tacct) attl $d(tsum)
                $pa incr $d(tacct) atransnums 1
                lappend accs $o(tacct) $d(tacct)
            }
            foreach i [lsort -unique $accs] {
                $_ UpdateRunTotal $i
            }
            if {$sub != "edit"} {
                update
                TreeView entry select $wt [lindex $ids 0]
            }
            if {[lsearch $(payee:listsp) $d(tpayee)]<0} {
                Spinbox conf $(w,edx_tpayee) -values [$_ FillPayee]
            }
            incr (changed)
            Tk::gui dialogclose $_
        }
        
        proc Cancel {_} {
            Tk::gui dialogclose $_
        }
        
        proc Delete {_} {
            upvar $_ {}
            variable pc
            set id $(cur:edit)
            if {$id == {}} return
            if {[$_ Delete-Transaction $id]} {
                Tk::gui dialogclose $_
            }
        }
        
        proc Duplicate {_} {
            upvar $_ {}
            set pt $(t:xaction)
            if {$(edit:xtype) != "edit"} {
                $_ Notify "[mc {Can not duplicate new transaction}]"
                return
            }
            if {[catch { clock scan $(v,edx_tdate) } tdate]} {
                $_ Notify "[mc {Date error}]: $tdate"
                return
            }
            set id [lindex $(edit:ids) 0]
            set tgroup [$pt get $id tgroup]
            set grp [$_ NewGroup]
            foreach i [$pt tag nodes grp$tgroup] {
                set data [$pt get $i]
                set id [$pt insert 0 -data $data -tags grp$grp]
                $pt update $id tgroup $grp treco {} tid $id tdate $tdate
            }
            $_ ShowAcct $(edit:acct) [lindex $(edit:ids) 0]
            $_ UpdateRunTotal $(edit:acct)
            Tk::gui dialogclose $_
        }
        
        proc Splits {_} {
            upvar $_ {}
            Tk::gui toplevel $_ -id editsplit
        }

    }
    
    # "SPLIT TRANSACTIONS"
    namespace eval Editxs {
        
        Mod upvars _ pc pp
        Mod uses ..
        
        proc Main {_} {
            upvar $_ {}
            variable pp
            variable pc
            set wt $(w,xaction)
            set pt $(t:xaction)
            set pa $(t:aclist)
            set id $(cur:edit)
            focus $(w,eds_sum1)
            for {set n 1} {$n<$pp(-maxsplits)} {incr n} {
                set (v,eds_sum$n) ""
                $(w,eds_acct$n) set {}
            }
            #if {$id == {}} return
            set n -1
            foreach {sum aid} $(edit:sums) {
                if {[incr n]==0} continue
                set (v,eds_sum$n) [expr {-$sum}]
                if {$aid != {}} {
                    $(w,eds_acct$n) set [$pa get $aid aname]
                }
            }
            focus $(w,eds_sum1)
            Entry selection range $(w,eds_sum1) 0 end
            EXT Editxs Main
        }
                
        proc Ok {_} {
            variable pp
            upvar $_ {}
            set pa $(t:aclist)
            set es [lrange $(edit:sums) 0 1]
            set m 0
            set tsum 0
            for {set n 1} {$n<$pp(-maxsplits)} {incr n} {
                set sum $(v,eds_sum$n)
                set aname $(v,eds_acct$n)
                if {$sum == "" && $aname == ""} continue
                if {![string is double -strict $sum]} {
                    $_ Notify "[mc {invalid Amount}]: $sum"
                    return 
                }
                set sum [format %.2f $sum]
                if {$aname == ""} {
                    $_ Notify "[mc {Account is required}]"
                    return 
                }
                set acct [$pa find -key aname -name $aname]
                if {$acct == $(edit:acct)} {
                    $_ Notify "[mc {Account source and dest must be different}]"
                    return 
                }
                lappend es [expr {-$sum}] $acct
                set tsum [expr {$tsum+$sum}]
            }
            EXT Editxs Ok
            if {[llength $es] <= 2} {
                $_ Notify "[mc {Must have at least one splits}]"
            } else {
                set (edit:sums) [lreplace $es 0 0 $tsum]
                set (v,edx_tsum) $tsum
                if {[llength $es] == 4} {
                    set aid [lindex $es 3]
                    set (v,edx_tdest) [$pa get $aid aname]
                    Spinbox conf $(w,edx_tdest) -state readonly
                } else {
                    set (v,edx_tdest) <SPLIT>
                    Spinbox conf $(w,edx_tdest) -state disabled
                }
            }
            Tk::gui dialogclose $_
        }
        
        proc Cancel {_} {
            Tk::gui dialogclose $_
        }
                
        proc Delete {_} {
            # Delete the split transaction.
            upvar $_ {}
            if {[llength $(edit:sums)]>4} {
                set (edit:sums) [lrange $(edit:sums) 0 1]
                lappend (edit:sums) [lindex $(edit:sums) 0] {}
                Spinbox conf $(w,edx_tdest) -state readonly
                set (v,edx_tdest) {}
            }
            Tk::gui dialogclose $_
        }

    }
    
    # "SCHEDULED TRANSACTION (unfinished)"
    namespace eval Sched {
        
        Mod upvars _ pc pp
        Mod uses ..
        
        proc Reopen {_} {
            upvar $_ {}
        }
        
        proc Main {_} {
            upvar $_ {}
            set wx $(w,xaction)
            set t $(w,sch_tlist)
            SetupTree $_ xaction $t
            TreeView column conf $t truntot -hide 1
            TreeView column move $t tsum tpayee
            TreeView style create checkbox $t cb -showvalue 0
            TreeView column conf $t treco -style cb -autowidth 0 -edit 1 -command {}
            TreeView conf $t -tree [tree create]
            #bind $t <<TreeViewEditEnd>> [list [namespace current]::Edit $_ %x %y]
            Reopen $_
        }
        
        proc Cancel {_} {
            upvar $_ {}
            Tk::gui dialogclose $_
        }
        
        proc Finish {_} {
        }
        
    }

    # "RECONCILE ACCOUNT"
    namespace eval Reconcile {
        
        Mod upvars _ pc pp
        Mod uses ..
        
        proc Finished {_} {
            upvar $_ {}
            set pa $(t:aclist)
            set pt $(t:xaction)
            set wt $(w,rec_tlist)
            set tt [TreeView cget $wt -tree]
            
            set acct $(edit:acct)
            if {[catch { clock scan $(v,rec_dateclose) } ndate]} {
                $_ Notify "[mc {invalid date}]: $(v,rec_dateclose)"
                return
            }
            set arbal $(v,rec_balclose)
            $pa set $acct arbal $arbal
            set ndate [clock scan $(v,rec_dateclose)]
            $pa set $acct arecebals($ndate) $(v,rec_balclose)
            set n 0
            foreach i [$tt children 0] {
                if {[$tt get $i treco]} {
                    incr n
                    $pt update $i treco $ndate
                }
            }
            incr (changed)
            set (v,status1) "$n [mc {Reconciled}]"
            Tk::gui dialogclose $_
        }
        
        proc SetDiff {_} {
            upvar $_ {}
            set (v,rec_diff) [expr {$(v,rec_balclose)-$(v,rec_obal)}]
        }
        
        proc Edit {_ cind idx} {
            upvar $_ {}
            set tt [TreeView cget $(w,rec_tlist) -tree]
            set treco [$tt get $idx treco]
            set tsum [$tt get $idx tsum]
            if {!$treco} {
                set (v,rec_diff) [expr {$(v,rec_diff)+$tsum}]
            } else {
                set (v,rec_diff) [expr {$(v,rec_diff)-$tsum}]
            }
        }
        
        proc Cancel {_} {
            upvar $_ {}
            Tk::gui dialogclose $_
        }
        
        proc Reopen {_} {
            upvar $_ {}
            set pa $(t:aclist)
            set pt $(t:xaction)
            set acct [TreeView index $(w,aclist) focus]
            set idx [TreeView index $(w,xaction) focus]
            set tt [TreeView cget $(w,rec_tlist) -tree]
            if {$acct == {} || $idx == {}} {
                Cancel $_
                return
            }
            set (edit:acct) $acct
            $tt delete 0
            set ldate [$pt get $idx tdate]
            foreach i [$pt find -name $acct -key tacct] {
                set treco [$pt get $i treco]
                if {$treco != ""} continue
                set tdate [$pt get $i tdate]
                if {$tdate>$ldate} { continue }
                $tt insert 0 -node $i -data [$pt get $i]
                $tt set $i treco 0
            }
            set aname [$pa get $acct aname]
            wm title $(w,reconcile) "[mc {Reconcile Account}]: $aname"
            set (v,rec_dateclose) [$_ date $ldate]
            set (reco:acct) $acct
            set bo [$pa get $acct aobal]
            if {$bo == ""} { set bo 0 }
            set (v,rec_obal) $bo
            set bc [$pa get $acct acbal]
            if {$bc == ""} { set bc 0 }
            set (v,rec_balclose) $bc
            SetDiff $_
        }

        proc Main {_} {
            upvar $_ {}
            set wx $(w,xaction)
            set t $(w,rec_tlist)
            SetupTree $_ xaction $t
            TreeView column conf $t truntot -hide 1
            TreeView column move $t tsum tpayee
            TreeView style create checkbox $t cb -showvalue 0
            TreeView column conf $t treco -style cb -edit 1 -command {}
            TreeView conf $t -tree [tree create]
            bind $t <<TreeViewEditEnd>> [list [namespace current]::Edit $_ %x %y]

            #TreeView style create combobox $t co -choices "A B C"
            #$t col conf tnum -style co -edit 1
            Reopen $_
        }
        
    }
        
    namespace eval Archive {
        
        Mod uses ..
        Mod upvars _ pp pc
        
        proc Main {_} {
            upvar $_ {}
            variable pp
            if {$(archive:close)} {
                set (v,arc_delete) 1
            } else {
                set (v,arc_delete) 0
            }
            Listbox selection set $(w,arc_aclist) 0
            if {$(v,arc_startdate) == {}} {
                set (v,arc_startdate) [$_ date]
            }
            if {$(v,arc_enddate) == {}} {
                set (v,arc_enddate) [$_ date]
            }
            #Tk::gui::calendar::bindings $(w,arc_startdate) $pp(-datefmt)
            #Tk::gui::calendar::bindings $(w,arc_enddate) $pp(-datefmt)
        }
        
        proc Cancel {_} {
            Tk::gui dialogclose $_
        }

        proc Ok {_} {
            # Archive transaction.
            #TODO: close yearend.
            # close evar type {but {}}
            variable pc
            upvar $_ {}
            set close $(archive:close)
            set pa $(t:aclist)
            set pt $(t:xaction)

            if {$(v,arc_startdate) == {} || $(v,arc_enddate) == {}} {
                $_ Notify [mc {missing date}]
                return
            }
            if {[catch {clock scan $(v,arc_startdate)} sdate] ||
            [catch {clock scan $(v,arc_enddate)} edate]} {
                $_ Notify [mc {invalid date}]
                return
            }
            if {![info exists sdate]} return
            set saveall 0
            if {[Listbox selection includes $(w,arc_aclist) 0]} {
                set saveall 1
            } else {
                set rc [$(w,arc_aclist) curselection]
                set accts {}
                foreach i $rc {
                    set j [lindex $en(list:accts) $i]
                    lappend accts [LookupField $_ aclist aname $j aid]
                }
                if {$accts == {}} {
                    $_ Notify [mc {No accounts selected}]
                    return
                }
            }
            set n 0
            foreach i [$pt children 0] {
                set tdate [$pt get $i tdate]
                if {$tdate >= $sdate && $tdate <= $edate} {
                    incr n
                    if {!$saveall && [lsearch $accts $tacct]<0} {
                        continue
                    }
                    $pt tag add archive $i
                }
            }
            if {$n > 0} {
                if {$(v,arc_saveacc)} {
                    set fdir [tk_chooseDirectory -parent $(w,.) -title [mc {Save To}]:]
                    if {![file isdirectory $fdir]} {
                        file mkdir $fdir
                    }
                    set fname [file join $fdir xaction$pc(ext)]
                    set afile [file join $fdir aclist$pc(ext)] 
                    tree op dump $(t:aclist) -file $afile
                } else {
                    set fname [tk_getSaveFile -parent $(w,.) -title [mc {Save Transactions To}]:]
                }
                if {$fname == {}} return
            
                if {$(v,arc_delete)} {
                    foreach i [$pt tag nodes archive] {
                        *catch { $_ Del1Xact $i $close }
                    }
                    incr (changed)
                }

                set data [tree op tag dump $(t:xaction) archive]
                set fp [open $fname w+]
                puts $fp $data
                close $fp
            
                tree op tag delete $pt archive all
            }
            $_ Fix-Sums

            set (v,status1) "[mc Archived] $n [mc transactions]"
            Tk::gui dialogclose $_
            return
        }

    }
    
    # "REPORTS DIALOG"
    namespace eval Reports {
        
        Mod upvars _ pc pp
        Mod uses ..
        
        proc Done {_} {
            upvar $_ {}
            Tk::gui dialogclose $_
        }
        
        proc Save {_} {
            upvar $_ {}
            set w $(w,rep_text)
            set fname [tk_getSaveFile -parent $(w,reports) -title [mc {Print To File}]]
            if {$fname == {}} return
            set fp [open $fname w+]
            set data [$w get 1.0 end]
            set lst {}
            set len 55
            set len2 23
            foreach i [split $data \n] {
                if {[string first $i \t]} {
                    set llst [split $i \t]
                    set rc [format %-${len}s [lindex $llst 0]]
                    append rc [format %${len2}s [join [lrange $llst 1 end] \t]]
                    set i $rc
                }
                append lst $i \n
            }
            puts $fp $lst
            close $fp
            return
        }
        
        proc DateSel {_ {val {}}} {
            # Date selection dialog.
            upvar $_ {}
            if {$val != {}} {
                set (v,rep_datestart) $val
                return
            }
            ::Tk::gui::calendar::new -command [list [namespace current]::DateSel $_] -parent $(w,.)
        }
        
        proc DateSele {_ {val {}}} {
            # Date selection dialog.
            upvar $_ {}
            if {$val != {}} {
                set (v,rep_dateend) $val
                return
            }
            ::Tk::gui::calendar::new -command [list [namespace current]::DateSele $_] -parent $(w,.)
        }
        
        
        proc Refresh {_} {
            # Generate a report
            upvar $_ {}
            variable pc
            set pa $(t:aclist)
            set pt $(t:xaction)

            set repidx [lsearch $pc(report:types) $(v,rep_men)]
            set repname [lindex $pc(report:types) $repidx]
            set w $(w,rep_text)
            $w delete 1.0 end
            set sep "-----------------\n"
            if {[$(w,rep_acclst) selection includes 0]} {
                set accts {}
                foreach i [lrange $(aclist:listall) 1 end] {
                    lappend accts [LookupField $_ aclist aname $i aid]
                }
            } else {
                set rc [$(w,rep_acclst) curselection]
                set accts {}
                foreach i $rc {
                    set j [$(w,rep_acclst) get $i]
                    lappend accts [LookupField $_ aclist aname $j aid]
                }
            }
            if {$(v,rep_sortacc)} {
                set rc {}
                foreach i $accts {
                    set j [$pa get $i anum]
                    lappend q($j) $i
                }
                foreach j [lsort [array names q]] {
                    foreach i $q($j) {
                        lappend rc $i
                    }
                }
                set accts $rc
            }
            if {!$(v,rep_catacc)} {
                set rc {}
                foreach i $accts {
                    if {[$pa get $i acatagory] != "1"} { lappend rc $i }
                }
                set accts $rc
            }
            set dateb [clock scan $(v,rep_datestart)]
            set datee [clock scan $(v,rep_dateend)]
            set FT "$(v,rep_datestart) [mc TO] $(v,rep_dateend)"
            if {$repidx == 4} {
                # Trial Balance
                set dateb 0
            }

            if {$repidx == 0} {
                # Account Summary
                $w insert end "*** [mc {ACCOUNT SUMMARY}] ***\t$FT\n" B
                $w insert end "       [mc TOTAL] [mc ACC#]\t[mc ACCOUNT]\n" B
                set ttsum 0
                foreach i $accts {
                    set anum [$pa get $i anum]
                    set aname [$pa get $i aname]
                    set attl [$pa get $i attl]
                    $w insert end "[Float $_ $attl] $anum\t$aname\n"
                    set ttsum [expr {$attl+$ttsum}]
                }
                $w insert end "$sep[Float $_ $ttsum] Grand Total\n"
                return
            }

            if {$repidx == 5} {
                # Validate xaction and aclist (eg. after hand edit).
                set tlst {}
                set ecnt 0
                set acnt 0
                set acckeys [lsort [concat $pc(aclist:extra) $pc(aclist:fields)]]
                foreach idx [$pa children 0] {
                    set keys [lsort [$pa keys $idx]]
                    set emsg {}
                    if {![string equal $keys $acckeys]} {
                        lappend emsg [mc {account key mismatch}]
                    }
                    set acat [$pa get $idx acatagory]
                    if {$acat != "0" && $acat != "1"} {
                        lappend emsg [mc {account acatagory not 0 or 1}]
                    }
                    if {$emsg != {}} {
                        $w insert end "Account($idx): [join $emsg ,]\n"
                    }
                }
                set allkeys [lsort [concat $pc(xaction:extra) $pc(xaction:fields)]]
                foreach ii [$pt tag names] {
                    if {![string match grp* $ii]} continue
                    set i [string range $ii 3 end]
                    set ttsum 0
                    set tns [$pt tag nodes $ii]
                    set emsg {}
                    foreach j $tns {
                        set tsum [$pt get $j tsum]
                        set ttsum [expr {$tsum+$ttsum}]
                        if {[info exists qq($j)]} {
                            lappend emsg [mc {multiple groups}]
                        }
                        set qq($j) 1
                        set keys [lsort [$pt keys $j]]
                        if {![string equal $keys $allkeys]} {
                            lappend msg [mc {key mismatch}]
                        }
                        lappend tlst $j
                    }
                    if {[llength $tns]<2} {
                        lappend emsg [mc {group < 2}]
                    }
                    if {abs($ttsum) > 0.000001} {
                        lappend emsg [mc {sum != 0}]
                    }
                    if {$emsg != {}} {
                        foreach j $tns {
                            set aname [$pa get $j aname]
                            set tmemo [$pt get $j tmemo]
                            set tpayee [$pt get $j tpayee]
                            set tsum [$pt get $j tsum]
                            set tdate [$pt get $j tdate]
                            $w insert end "(tid=$j,grp=$tgroup)[join $emsg ,]:  [Date $_ $tdate] [Float $_ $tsum] [format %-30s $aname] [format %-20s $tpayee] $tmemo\n"
                            incr ecnt
                        }
                    }
                }
                if {[llength $tlst] != ([$pt size 0]-1)} {
                    set ntlst {}
                    foreach i [$pt children root] {
                        if {[lsearch $tlst $i]<0} {
                            lappend ntlst $i
                        }
                    }
                    incr ecnt
                    $w insert end "([llength $tlst] != [$pt size 0]) transactions missing grp tag: $ntlst\n"
                }
                if {$ecnt} {
                    $w insert 1.0 "*** [mc {INVALID TRANSACTIONS}] ***\t$FT\n" B
                } else {
                    $w insert 1.0 "[mc {DATA IS VALID}]\n" B
                }
                return
            }

            # Make p() a per-account list of date-filtered sorted transactions.
            # all() contains all transactions for sel accounts.
            foreach i [$_ SortFields xaction tdate] {
                set tacct [$pt get $i tacct]
                if {[lsearch $accts $tacct]<0} { continue }
                if {$repidx == 3} { lappend all($tacct) $i }

                set tdate [$pt get $i tdate]
                if {$tdate < $dateb || $tdate > $datee} continue
                set treco [$pt get $i treco]
                if {$repidx != 3 && $(v,rep_reconciled) && ![string length $treco]} continue
                lappend p($tacct) $i
                if {$repidx == 4} { set lasti($tacct) $i }
            }

            if {$repidx == 4} {
                # Trial Balance
                $w insert end "*** [mc {TRIAL BALANCE}] ***\t$FT\n" B
                $w insert end "       [mc TOTAL] [mc ACC#]\t[mc ACCOUNT]\n" B
                set gttl 0
                foreach i $accts {
                    set aobal [$pa get $i aobal]
                    if {![info exists lasti($i)]} {
                        set ttl $aobal
                    } else {
                        set last $lasti($i)
                        if {![info exists rt($i)]} {
                            $_ UpdateRunTotal $i
                            set rt($i) 1
                        }
                        set ttl [$pt get $last truntot]
                    }
                    $w insert end "[Float $_ $ttl] [$pa get $i anum]\t[$pa get $i aname]\n"
                    set gttl [expr {$gttl+$ttl}]
                }
                $w insert end "$sep[Float $_ $gttl] Grand Total"
                return
            }

            if {$repidx == 1} {
                # General Ledger
                $w insert end "*** [mc {GENERAL LEDGER}] ***\t$FT\n" B
                set lsum 0
                set gsum 0
                foreach i $accts {
                    set anum [$pa get $i anum]
                    set aname [$pa get $i aname]
                    $w insert end "[mc {TRANSACTIONS FOR}] $anum\t$aname\n" B
                    set sum 0
                    set ksum 0
                    set msum 0
                    set ilast {}
                    if {[info exists p($i)]} {
                        foreach j $p($i) {
                            set tsum [$pt get $j tsum]
                            if {!$(v,rep_credits) && $tsum>0} continue
                            if {!$(v,rep_debits) && $tsum<0} continue
                            set tdate [$pt get $j tdate]
                            if {$(v,rep_monthly) && [string length $ilast] && [$_ DiffMonth $tdate $ilast]} {
                                $w insert end "$sep[mc {Total for}] [clock format $ilast -format %Y-%m]: [Float $_ $msum]\n\n"
                                set msum 0
                            }
                            set msum [expr {$msum+$tsum}]
                            set ilast $tdate
                            set val [TransDest $_ $j aname]
                            if {$treco == {1}} { set r R } else { set r { } }
                            set sum [expr {$sum+$tsum}]
                            set tpayee [$pt get $j tpayee]
                            set tmemo [$pt get $j tmemo]
                            $w insert end "$r [Date $_ $tdate] [Float $_ $tsum] ([Float $_ $sum]) [format %-15s $val] [format %-20s $tpayee] $tmemo\n"
                        }
                        if {$(v,rep_monthly) && [string length $ilast] && $msum} {
                            $w insert end "$sep[mc {Total for}] [clock format $ilast -format %Y-%m]: [Float $_ $msum]\n\n"
                        }
                    }
                    set aobal [$pa get $i aobal]
                    set ksum [expr {$ksum+$aobal+$sum}]
                    $w insert end "$sep[mc Total]:\t[Float $_ $sum] + [format %.2f $aobal] = [Float ${_} $ksum]\n\n"
                    set lsum [expr {$lsum+$sum}]
                    set gsum [expr {$gsum+$aobal}]
                }
                $w insert end "$sep[mc TOTAL]:\t[Float $_ [expr {$lsum-$gsum}]] + [format %.2f $gsum] = [Float $_ [expr {$lsum-$gsum}]]\n\n" B
                return
            }

            if {$repidx == 2} {
                # Total by payee.
                $w insert end "*** [mc {TOTALS BY PAYEE}] ***\t$FT\n" B
                foreach i [array names p] {
                    foreach j $p($i) {
                        set tpayee [$pt get $j tpayee]
                        set tsum [$pt get $j tsum]
                        if {[info exists q($tpayee)]} {
                            set q($tpayee) [expr {$q($tpayee)+$tsum}]
                        } else {
                            set q($tpayee) $tsum
                        }
                    }
                }
                foreach i [lsort -dictionary [array names q]] {
                    $w insert end "[Float $_ $q($i)] $i\n"
                }
                return
            }

            if {$repidx == 3} {
                # Reconciliation Report.
                $w insert end "*** [mc {RECONCILIATION REPORT}] ***\t$FT\n" B
                foreach i [array names p] {
                    # Foreach acct.
                    set aname [$pa get $i aname]
                    set aobal [$pa get $i aobal]
                    $w insert end "*[mc {RECONCILIATION FOR ACCOUNT:}]\t$aname\n" B
                    array unset r
                    foreach j $p($i) {
                        # First get statement end dates.
                        if {[$pt exists $j]} {
                            lappend r([$pt get $j treco]) $j
                        }
                    }
# Get balr: the reconciled end-balance for just before first transaction.
                    set balr $aobal
                    set balb $aobal
                    set first [lindex $p($i) 0]
                    foreach j $all($i) {
                        # Foreach xact on acct.
                        if {$j == $first} break
                        set treco [$pt get $j treco]
                        set tsum [$pt get $j tsum]
                        if {[string length $treco]} {
                            set balr [expr {$balr+$tsum}]
                        }
                    }
                    array unset r {}
                    set lst [lsort -integer [array names r]]
                    set start $(v,rep_datestart)
                    set end [lindex $lst [set n 0]]
                    set rsum 0; set usum 0; set rneg 0; set rcnt 0; set ucnt 0
                    if {[llength $p($i)]} { lappend p($i) {} }
                    array unset q
                    if {[info exists lastj]} { unset lastj }
                    foreach j $p($i) {
                        # Foreach xact on this acct.
                        if {[string length $j]} {
                            foreach {l m} [$pt get $j] { set $l $m }
                            if {![string length $truntot]} {
                                $_ UpdateRunTotal $tacct
                                foreach {l m} [$pt get $j] { set $l $m }
                            }
                        }
                        if {![string length $j] || $tdate>$end} {
                            while {1} {
                                if {$rcnt} {
                                    if {[info exists lastj]} {
                                        set balb [$pt get $lastj truntot]
                                    }
                                    set arecebals [$pa get $i arecebals]
                                    array set qq $arecebals
                                    if {[info exists qq($end)]} {
                                        set balt $qq($end)
                                    } else {
                                        set balt $aobal
                                    }
                                    array unset qq
                                    $w insert end "\nStatement End Date:" I "\t[$_ date $end]"
                                    $w insert end "\nReconciled Transactions" I ":\t$rcnt"
                                    $w insert end "\nOutstanding Transactions" I ":\t$ucnt"
                                    $w insert end "\nReconciled Debits" I ":\t[Float $_ $rneg]"
                                    $w insert end "\nReconciled Credits" I ":\t[Float $_ [expr {$rsum-$rneg}]]"
                                    $w insert end "\nStatement End Balance" I ":\t[Float $_ $balt]"
                                    $w insert end "\nBook End Balance" I ":\t[Float $_ $balb]"
                                    $w insert end "\nOutstanding Amount" I ":\t[Float $_ $usum]"
                                    set bald [expr {$balb-$balt-$usum}]
                                    $w insert end "\nReconcilation Difference" I ":\t[Float $_ $bald]\n"
                                }
                                if {![string length [set end [lindex $lst [incr n]]]]} break
                                if {$tdate<=$end} break
                            }
                            if {![string length $end]} break
                            set rsum 0; set rneg 0; set rcnt 0
                            if {[info exists q($end:rsum)]} {
                                foreach k {rsum rcnt rneg} { set $k $q($end:$k); }
                                incr ucnt $q($end:ucnt)
                                set usum [expr {$usum+$q($end:usum)}]
                            }
                        }
                        set lastj $j
                        if {![string length $j]} break
                        set balr [expr {$balr+$tsum}]
                        if {![string length $end]} { break }
                        if {[string length $treco]} {
                            if {[string equal $treco $end]} {
                                set rsum [expr {$rsum+$tsum}]; incr rcnt
                                if {$tsum<0} { set rneg [expr {$rneg+$tsum}] }
                                #tclLog "XX: [clock format $tdate] "
                            } else {
                                if {![info exists q($treco:rsum)]} {
                                    foreach k {rsum rcnt rneg usum ucnt} { set q($treco:$k) 0 }
                                }
                                set q($treco:rsum) [expr {$q($treco:rsum)+$tsum}];
                                incr q($treco:rcnt)
                                if {$tsum<0} { set q($treco:rneg) [expr {$q($treco:rneg)+$tsum}] }
                                set usum [expr {$usum+$tsum}]; incr ucnt
                                incr q($treco:ucnt) -1
                                set q($treco:usum) [expr {$q($treco:usum)-$tsum}];
                            }
                        } else {
                            set usum [expr {$usum+$tsum}]; incr ucnt
                        }
                    }
                    $w insert end "\n* [mc {RECONCILED}] $aname periods:\t[array size r]\n\n" B
                }
                $w insert end "\n*** [mc {END RECONCILIATION REPORT}] ***\t$FT\n" B
                return
            }
            error "unknown report type: $repidx $(v,rep_type)"
        }

        proc Main {_} {
            upvar $_ {}
            variable pp
            set pa $(t:aclist)
            set (v,rep_datestart) [$_ date]
            set (v,rep_dateend) [$_ date]
            set l $(w,rep_acclst)
            Listbox insert $l end <All>
            Listbox selection clear $l 0 end
            Listbox selection set $l 0
            foreach i [$pa children 0] {
                $l insert end [$pa get $i aname]
            }
            set wt $(w,rep_text)
            $wt conf  -wrap none -tabs {500 right}; # -font {Courier -14}
            set ff [font actual [$wt cget -font]]
            $wt tag conf B -font TkDefaultFont -foreground #0033CC
            $wt tag conf I -font [concat $ff -slant italic] -foreground #336633
            Tk::gui::calendar::bindings $(w,rep_datestart) $pp(-datefmt)
            Tk::gui::calendar::bindings $(w,rep_dateend) $pp(-datefmt)

            Refresh $_
        }
        
        
    }
        
    # "MOVE TRANSACTION
    namespace eval Movex {
        
        Mod upvars _ pc pp
        Mod uses ..
        
        proc Main {_} {
            upvar $_ {}
            set acct [TreeView index $(w,aclist) focus]
            set id [TreeView index $(w,xaction) focus]
            if {$acct == {} || $id == {}} return
            set (edit:acct) [list $acct $id]
        }
        
        proc Ok {_} {
            # {win acct id evar type {but {}}}
            # Move a transaction.
            upvar $_ {}
            set pa $(t:aclist)
            set pt $(t:xaction)
            foreach {acct id} $(edit:acct) break

            if {$(v,mov_acc) == {}} {
                $_ Notify [mc {Missing account}]
                return
            }
            set nacct [LookupField ${_} aclist aname $(v,mov_acc) aid]
            if {$nacct == $acct} {
                $_ Notify [mc {Source and destination Accounts must be different}]
                return
            }
            incr (changed)
            $pt set $id tacct $nacct
            $_ AcctSumAdj $id $acct 0
            $_ AcctSumAdj $id $nacct
            $_ ShowAcct $acct
            Tk::gui dialogclose $_
        }
        
        proc Cancel {_} {
            Tk::gui dialogclose $_
        }
        


    }
    
    proc SetDate {_ date} {
        # Set the date format, if valid.
        upvar $_ {}
        variable pp
        if {[*catch { clock format 0 -format $date } ]} {
            Notify $_ "[mc {Invalid date format}]: $date" -icon error
            return
        }
        set pp(-datefmt) $date
        Refresh $_
    }
        
    proc DateFmt {_ m} {
        # Post handler to build date menu.
        upvar $_ {}
        variable pp
        if {[Menu index $m end]>1} return
        foreach i $pp(-datefmts) {
            Menu add radiobutton $m -label $i -value $i -variable [namespace current]::pp(-datefmt) -command [list $_ SetDate $i]
        }
    }



    ::Tk::gui create {
        
        # "STYLE FOR MAIN"
        {style} {
            Toplevel {
                @deffonts {
                    fixed    {Courier -14}
                    scaled    {Verdana,Helvetica -12 bold}
                }
                @eval {
                    #eval font conf TkDefaultFont [font actual [fonts lookup %W scaled]]
                    #eval font conf TkFixedFont [font actual [fonts lookup %W fixed]]
                }
            }
            Entry {
                -highlightthickness 0
            }
            TreeView {
                @eval {
                    TreeView column conf %W 0 -hide 1
                    TreeView style create textbox %W alt -bg LightBlue
                }
                -altstyle alt -underline 1 -bg White
            }
            .xaction {
                @bind {
                    <Double-ButtonRelease-1> Edit-Trans
                    <Return> Edit-Transaction
                    <3> !xamenu 
                }
            }
            .aclist {
                @eval {
                    %W style conf alt -bg #9db9c8
                }
                @bind {
                   <Double-ButtonRelease-1> Edit-Acc
                   <3> !acmenu 
               }
           }
            TreeView::column {
                -bd 1 -relief raised
            }
            Panedwindow {
                -showhandle 0
            }
        }

        # "EDIT TRANSACTIONS"
        {Toplevel + -id editxact -ns Editx -openmsg Main -title "Edit Transaction"} {
            
            style {
                Toplevel {
                    @bind { <Return> Editx::Ok }
                }
                Entry { -width 50 }
                .edx_treco { -state disabled }
                .edx_tdate { @@ {-tip "The date for the transaction" } }
                .edx_butsum -
                .edx_butdate { -takefocus 0 }
            }

            {Frame + -matte 4 -pos *} {
                {Label - -id edx_label} {Edit Transaction:}
                {Frame + -matte 3 -pos *} {
                    {grid + -colattr { {} {-pos _} } -pos * } {
                        {row +} { Label Reconciled {Entry - -id edx_treco} {} }
                        {row +} { Label Num {Entry - -id edx_tnum} {} }
                        {row +} {
                            Label Date 
                            {Frame + -subpos l} {
                                {Entry - -id edx_tdate} {}
                                {Button - -icon appdate -msg DateSel -id edx_butdate} {}
                            }
                        }
                        {row +} {
                            Label Payee
                            {Spinbox - -id edx_tpayee -listvar (payee:listsp) -autofill 1 -combo 1 -pos _} {}
                        }
                        {row +} {
                            Label Amount 
                            {Frame + -subpos l} {
                                {Entry - -id edx_tsum -type Double} {}
                                {Button - -icon appcalc -msg CalcSel -id edx_butsum} {}
                            }
                        }
                        {row +} {
                            Label Account
                            {Frame + -subpos l -pos _} {
                                {Spinbox - -id edx_tdest -listvar (aclist:listsp) -readonly  2 -combo 1 -pos l_!} {}
                                {Button} {Splits}
                            }
                        }
                        {row +} { Label Memo {Entry - -id edx_tmemo} {} }
                    }
                }
                {Frame + -subpos l*/ -pos _} {
                    Button Ok
                    Button Cancel
                    {Button - -id edx_dup} Duplicate
                }
            }
        }
        
        # "EDIT SPLITS"
        {Toplevel + -id editsplit -pid editxact -ns Editxs -openmsg Main -title "Edit A Split Transaction"} {
            
            style {
                Entry { -width 15 }
                Toplevel {
                    @bind { <Return> Editxs::Ok }
                }
            }
            {Frame + -matte 4 -pos *} {
                {Label} {Edit Split Transaction:}
                {Frame + -matte 3 -pos *} {
                    subst {
                        {grid + -colattr { {} {-pos _} } -pos * } {
                            {row +} { Label Amount Label Account }
                            [*nrepeat "{row +} { {Entry - -id eds_sum%N -type Double} {} {Spinbox - -id eds_acct%N -readonly  2 -listvar (aclist:listsp) -combo 1} {} }\n" $pp(-maxsplits)]
                        }
                    }
                }
                {Frame + -subpos l*/ -pos _} {
                    Button Ok
                    Button Cancel
                    Button Delete
                }
            }
        }

        # "MOVE TRANSACTION"
        {Toplevel + -id movexact -ns Movex -openmsg Main -title "Move a Transaction"} {
            style {
                Entry { -width 15 }
            }
            {Frame + -matte 4 -pos *} {
                {Label} {Move Transaction To:}
                {Frame + -matte 3 -pos *} {
                    {grid + -pos * } {
                        {row +} { Label Account {Spinbox - -id mov_acc -readonly  2 -listvar (aclist:list)} {}}
                    }
                }
                {Frame + -subpos l*/ -pos _} {
                    Button Ok
                    Button Cancel
                }
            }
        }

        # "EDIT ACCOUNT"
        {Toplevel + -id editacct -ns Edita -openmsg Main -title "Edit Account"} {
            style {
                Toplevel {
                    @bind { <Return> Edita::Ok }
                }
                Entry { -width 30 }
            }
            {Frame + -matte 4} {
                {Label} {Edit Account:}
                {Frame + -matte 3} {
                    {grid + -colattr { {} {-pos _} } -pos * } {
                        {row +} { Label "Account Name"  {Entry - -id eda_aname} {} }
                        {row +} { Label "Account Number"  {Entry - -id eda_anum} {} }
                        {row +} { Label "Opening Balance"  {Entry - -id eda_aobal} {} }
                        {row +} { Label "Closing Balance"  {Entry - -id eda_acbal} {} }
                        {row +} { Label "Reconciled Balance"  {Entry - -id eda_arbal} {} }
                        {row +} { Label "Account Is Catagory"  {Checkbutton - -id eda_acatagory} {} }
                        {row +} { Label "Account Is Taxable"  {Checkbutton - -id eda_atax} {} }
                        {row +} { Label "Account Type"  {Spinbox - -id eda_atype -listvar pc(aclist:types) -combo 1} {} }
                        {row +} { Label "Institution Name"  {Entry - -id eda_ainstname} {} }
                        {row +} { Label "Address1"  {Entry - -id eda_ainstaddr1} {} }
                        {row +} { Label "Address2"  {Entry - -id eda_ainstaddr2} {} }
                        {row +} { Label "City"  {Entry - -id eda_ainstcity} {} }
                        {row +} { Label "Zip/Postal"  {Entry - -id eda_ainstzip} {} }
                        {row +} { Label "Phone"  {Entry - -id eda_ainstphone} {} }
                        {row +} { Label "Fax"  {Entry - -id eda_ainstfax} {} }
                        {row +} { Label "Email"  {Entry - -id eda_ainstemail} {} }
                        {row +} { Label "Contact"  {Entry - -id eda_ainstcontact} {} }
                        {row +} { Label "Notes"  {Entry - -id eda_ainstnotes} {} }
                    }
                }
                {Frame + -subpos l*/ -pos _} {
                    Button Ok
                    Button Cancel
                    Button Delete
                }
            }
        }
        
        # "ARCHIVE TRANACTIONS"
        {Toplevel + -id archive -ns Archive -openmsg Main -title "Archive Transactions"} {
            style {
                .sttable { -width 500 }
                Spinbox { -width 16 }
            }
            {Frame + -matte 4 -pos *} {
                {grid + -pos *} {
                    {row + -pos *} {
                        {Label} "Delete Transactions"
                        {Checkbutton - -id arc_delete} {}
                    }
                    {row + -pos *} {
                        {Label} "Also Save Account"
                        {Checkbutton - -id arc_saveacc} {}
                    }
                    {row + -pos *} {
                        {Label} "Start Date"
                        {Spinbox - -id arc_startdate} {}
                    }
                    {row + -pos *} {
                        {Label} "End Date"
                        {Spinbox - -id arc_enddate} {}
                    }
                    {row + -pos *} {
                        {Label} "Account"
                        {Listbox - -id arc_aclist -multiple 1 -listvar (aclist:listall)} {}
                    }
                }
            }
            {Frame + -subpos l*/ -pos _} {
                Button Ok
                Button Cancel
            }
        }
        

        # "RECONCILE ACCOUNT"
        {Toplevel + -id reconcile -ns Reconcile -openmsg Main -reopenmsg Reopen -esc 0 -title "Reconcile Account:"} {
            style {
                Entry -
                Spinbox { -width 10 }
                TreeView { -width 600 }
            }
            {Frame + -pos *} {
                {Frame + -matte 3 -pos |l} {
                    Label "Closing Date"
                    {Entry - -id rec_dateclose} {}
                    Label "Opening Balance"
                    {Label - -id rec_obal} {}
                    Label "Closing Balance"
                    {Entry - -id rec_balclose} {}
                    Label "Difference"
                    {Label - -id rec_diff} {}
                    Button Cancel
                    Button Finished
                    
                }
                {Frame + -matte 3 -pos *l} {
                    {TreeView - -id rec_tlist -scroll * -pos *} {}
                }
            }
            
        }

        # "SCHEDULE TRANSACTIONS"
        {Toplevel + -id schedxact -ns Sched -openmsg Main -title "Scheduled Transactions"} {
            style {
                Entry -
                Spinbox { -width 10 }
                TreeView { -width 600 }
            }
            {Panedwindow + -pos *} {
                {pane +} {
                    {Frame + -matte 4 -pos *} {
                        {Label} {Starting Date}
                        {Entry - -id sch_start} {}
                        {Label} {Ending Date}
                        {Entry - -id sch_end} {}
                        {Labelframe + -label "Periodicity" -subpos w -pos *} {
                            {Radiobutton - -name sch_period -value daily} Daily
                            {Radiobutton - -name sch_period -value monthly} Monthly
                            {Radiobutton - -name sch_period -value single} {Single Transaction}
                            {Frame + -pos _ -subpos l} {
                                Label Every
                                {Spinbox - -id sch_every} 1
                                Label Periods
                            }
                        }
                        {Labelframe + -label "Day Of The Month" -pos *} {
                            {Frame + -pos w_ -subpos l} {
                                {Radiobutton - -name sch_daily -value daily} {}
                                Label "Specific Day"
                                {Spinbox - -id sch_day} 1
                            }
                            {Frame + -pos w_ -subpos l} {
                                {Radiobutton - -name sch_daily -value last} {}
                                Label "Last Day"
                            }
                        }
                        {Frame + -subpos l*/ -pos _} {
                            Button Cancel
                            Button Finish
                        }
                    }
                }
                {pane +} {
                    {TreeView - -id sch_tlist -scroll *} {}
                }
            }
        }

        # "REPORTS DIALOG"
        {Toplevel + -id reports -ns Reports -openmsg Main -title "Transaction Reports"} {
            style {
                .rep_acclst { -width 30 -exportselection 0 }
                .rep_date* { -width 25 }
                .rep_text {
                    @tags {
                        
                    }
                }
            }
            {Frame + -subpos *l -pos *} {
                {Frame + -id rep_left} {
                    {Frame + -pad 5,5 -pos *} {
                        {Frame + -matte 3 -pos *} {
                            Label "Starting Date"
                            {Frame + -pos _} {
                                {Entry - -id rep_datestart -pos _l} {}
                                {Button - -icon appdate -msg DateSel -id rep_butdate -pos l} {}
                            }
                            Label "Ending Date"
                            {Frame + -pos _} {
                                {Entry - -id rep_dateend -pos _l} {}
                                {Button - -icon appdate -msg DateSele -id rep_butedate -pos l} {}
                            }
                        }
                        {Frame +} {
                            Label "Report Type"
                            {Menubutton - -msg Refresh -id rep_men} {
                                {Account Summary}
                                {General Ledger}
                                {Totals by Payee}
                                {Reconciliation}
                                {Trial Balance}
                                {Validate Transaction Data}
                            }
                        }
                        {Frame + -matte 3 -subpos e} {
                            {Frame + -subpos r} {
                                {Checkbutton - -id rep_sortacc} {}
                                Label "Sorted by Account Num"
                            }
                            {Frame + -subpos r} {
                                {Checkbutton - -id rep_catacc} {}
                                Label "Include Catagory Accounts"
                            }
                            {Frame + -subpos r} {
                                {Checkbutton - -id rep_reconciled} {}
                                Label "Reconciled Transactions Only"
                            }
                            {Frame + -subpos r} {
                                {Checkbutton - -id rep_credits} {}
                                Label "Credits"
                                {Checkbutton - -id rep_debits} {}
                                Label "Debits"
                                {Checkbutton - -id rep_monthly} {}
                                Label "Monthly"
                            }
                        }
                    }
                    {Frame + -pos *} {
                        {Listbox - -id rep_acclst -multiple 1 -scroll * -pos *} {}
                    }
                    {Frame + -pos _ -subpos l*/} {
                        Button Done
                        Button Save
                        Button Refresh
                    }

                }
                {Frame + -id rep_right -pos *l} {
                    {Text - -id rep_text -scroll * -pos *} {}
                }

            }
        }

        # "MAIN MENU"
        {Menu +} {
            {menu + -label File} {
                x Open
                {x - -key <Alt-s>} Save
                sep {}
                {menu + -label Archive} {
                    x  Backup
                    x Archive
                    x Import
                    x Close-Yearend
                }
                sep {}
                x Close
            }
            {menu + -label Account} {
                x New-Account
                x Edit-Account
                x Delete-Account
                sep {}
                x Reconcile
                sep {}
                {menu + -label Import} {
                    x Import-QIF-Accounts
                    x Export-QIF-Accounts
                    x Export-QIF-Catagories
                }
                {menu + -label Setup} {
                    x Make-Catagories
                    x Update-RunTotals
                    x Sort-Accounts
                    x Fix-Sums
                }
            }
            {menu + -label Transaction} {
                {x - -key <Alt-e>} Edit-Transaction
                {x - -key <Alt-n>} New-Transaction
                {x - -key <Alt-Shift-N>} New-Transaction-Date
                {x - -key <Alt-d>} Delete-Transaction
                x Move-Transaction
                sep {}
                #x Scheduled-Transactions
                x Reports
                x Print-Window
                sep {}
                {menu + -label Import} {
                    x QIF-Import
                    x QIF-Export
                    x CBB-Import
                }
                x Clear-Reconcile
            }
            {menu + -label Options} {
                {c - -var pp(-hasmenu) -key <Alt-m>} Show-Menu
                {c - -var pp(-hasstatus)} Show-Statusbar
                {c - -var pp(-hastoolbar)} Show-Toolbar
                {c - -var pp(-hidecat)} Hide-Catagories
                sep {}
                {#c - -var pp(-nosched) -label No-Scheduled} {}
                #sep {}
                {c - -var pp(-usecvs) -label CVS-Save} {}
                {c - -var pp(-usercs) -label RCS-Save} {}
                sep {}
                x Fixed-Font
                x Variable-Font
                {menu + -label Date-Format -post DateFmt } {
                }
                {menu + -label Language} {
                }
            }
            {menu + -label Programs} {
                x Calculator
                x Calendar
            }
            {menu + -label Help} {
                x About
                #x License
                #x Reload-Tcl
                #x Documentation
            }
        }

        {Menu + -id acmenu} {
            x Edit-Account
            x New-Account
            x Delete-Account
        }
        
        {Menu + -id xamenu} {
            x Edit-Transaction
            x New-Transaction
            x New-Transaction-Date
            x Move-Transaction
            x Delete-Transaction
        }


        # "MAIN TOPLEVEL WINDOW"
        {Toplevel + -title "Ledger" -geom 600x480} {
            style {
                Toplevel {
                    @guiattrsmap {
                        -icon {
                            tb_save filesave
                            tb_new filenew
                            tb_date filenew2
                            tb_edit edit
                            tb_del kill
                        }
                        -tip {
                            tb_save "Save file"
                            tb_new  "New transaction"
                            tb_date "New transaction with date of current"
                            tb_edit "Edit transaction"
                            tb_del  "Delete transaction"
                        }
                    }
                }
                .tb_* { -takefocus 0 }
                TreeView {
                    -selectbackground DarkBlue -selectforeground White
                    -nofocusselectbackground #085d8c -nofocusselectforeground White
                }
                TreeView::style::noncat.aclist {
                    -fg DarkGreen -shadow Gold
                }
            }
            
            {statusbar - -id statusbar -ids {status1 status2}} {}
            {Frame + -id toolbar -subpos wl -pos _} {
                {Button - -id tb_save}  Save
                {Button - -id tb_new}   New-Transaction
                {Button - -id tb_date}  New-Transaction-Date
                {Button - -id tb_edit}  Edit-Transaction
                {Button - -id tb_del}   Delete-Transaction
            }
            {Panedwindow + -id painmain -pos *} {
                {pane +} {
                    {TreeView - -id aclist -scroll * -pos *} {}
                }
                {pane +} {
                    {TreeView - -id xaction -scroll * -pos *} {}
                }
            }
        }
    }
}

