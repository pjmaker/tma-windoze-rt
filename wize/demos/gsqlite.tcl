#!/usr/bin/env wize
# An simple sqlite frontend using GUI.
#
# BSD copyright 2008 - Peter MacDonald - http://pdqi.com
# RCS: @(#) $Id: gsqlite.tcl,v 1.26 2010/05/10 18:28:31 pcmacdon Exp $

package require Gui

namespace eval ::app::gsqlite {
    
    Mod export

    variable _
    array set _ {
        db {}    db:name {}    db:tbl {}    db:open 0    db:file {}
        maxrows 1000    cur:startrow 0    cur:firstrow 0    cur:lastrow 0
        filename {}    guiobj {}  editopts {}   istable 1
    }
    
    set _(filetypes) {
        {Database {.db .db3 .dat}}
        {Sql {.sql .qry}}
        {All *}
        
    }
    
    # Table columns
    variable tabs
    array set tabs {
        struct
        {# "Name" "Data Type" "Primary Key" "Not NULL" "Default Value"}
        data
        {#}
        indexes
        {# "Index name" "On table" "On column" "Unique" "SQL code"}
        triggers
        {# "Trigger name" "On table" "On column" "SQL code"}
        views
        {# "View name" "SQL code"}
        qhtbl
        {# "Rows" "SQL"  "Execution Date" "Execution Time" }
        qrtbl
        {#}
    }
    #constraint
    #{# "Constraint Name" "Column Name" "Default" "Not NULL" "Primary Key" "Unique" "Collate" "Check" "Foreign Key"}


    ################# Start of Code ####################
    
    namespace eval DB {
        
        Mod upvars _ tabs

        proc UpdateRowCount {_ tn} {
            # Update row count.
            upvar $_ {}
            set rsz [db onecolumn $(db) "SELECT COUNT(*) FROM $tn;"]
            set ts $(w,dblist)
            set e [TreeView find $ts -usepath -name main/Tables/$tn]
            if {$e == {}} return
            set dat [TreeView entry cget $ts $e -data]
            array set q $dat
            set q(Size) $rsz
            TreeView entry conf $ts $e -data [array get q]
        }
    
        proc Cols {db table} {
            set lst [$db eval "PRAGMA table_info($table)"]
            set cols {}
            set n -1
            foreach i $lst {
                incr n
                if {($n%6)==1} { lappend cols $i }
            }
            return $cols
        }

        proc GetSchema {_ str tn} {
            # Take apart the schema and return field info as a list of lists.
            #TODO: use PRAGMA table_info(tbl)
            upvar $_ {}
            set s [string first ( $str]
            set l [string last ) $str]
            set str [string range $str [incr s] [incr l -1]]
            set fldss [string map {' {} \" {} "\)" "\) "} [split $str ,]]
            set types {}
            set lst {}
            set pkey {}
            foreach i $fldss {
                #array unset q
                array set q { type {} primary 0 default {} notnull 0 data {} }
                set q(data) $i
                set ttail [lrange $i 1 end]
                #set q(name) [lindex $i 0]
                set q(type) [lindex $i 1]
                lappend types $q(type)
                set ltail [string tolower $ttail]
                if {[string first "integer primary key" $ltail]>=0} {
                    set pkey [lindex $i]
                    set q(primary) 1
                }
                set li [string tolower [set ui [lrange $i 2 end]]]
                if {[string first "not null" $ltail]>=0} {
                    set q(notnull) 1
                }
                if {[set ld [lsearch $ltail default]]>=0} {
                    set q(default) [lindex $ui [incr ld]]
                }
                lappend lst [lindex $i 0] [array get q]                
            }
            set (dbtypes,$tn) $types
            set (dbschema,$tn) [list pkey $pkey types $types fields $lst]
        }
       
        proc ClearCols {_ tvd } {
            upvar $_ {}
            TreeView delete $tvd 0 end
            foreach i [lrange [TreeView column names $tvd] 1 end] {
                TreeView column delete $tvd 1
            }
        }
 

        proc MakeCols {_ tn tvd cols tbl {isdata 0} {types {}}} {
            upvar $_ {}
            TreeView delete $tvd 0 end
            set m 1
            foreach i [lrange [TreeView column names $tvd] 1 end] {
                TreeView column delete $tvd 1
            }
            #catch { TreeView style create textbox $tvd text1 -font "Courier -12 bold"}
            set edit no
            set eo $(editopts)
            set c -1
            set d 0
            if {[lindex $cols 0] != "#"} {
                set cols [concat # $cols]
            }
            foreach i $cols {
                if {$i == "rowid"} continue
                set type [string tolower [lindex $types $c]]
                incr c; incr d
                set sty text$d
                if {![catch {TreeView style create textbox $tvd $sty}]} {
                    styles item $tvd "column::style::$d" $sty {style conf}
                }
                if {!$c} {
                    set j center
                } else {
                    set j [expr {[string match *int* $type]?"right":"left"}]
                }
                set n [TreeView column insert $tvd end $i -edit $edit -editopts $eo -justify $j -style $sty]
                #TreeView column conf $tvd $n -bindtags "all $n"

                set class [list column column::$d]
                if {$d%2} { lappend class column::odd }
                styles item $tvd $class $n
                if {$isdata} {
                    set edit yes
                }
                incr m
            }
        }
        proc RunQuery {_ query tbl {isdata 0}} {
            # Populate table with results of an SQL query.
            upvar $_ {}
            set n -1
            set tvd $(w,$tbl)
            busy hold $(w,.)
            update
            after idle [list busy release $(w,.)]
            ClearCols $_ $tvd
            db eval $(db) $query xy {
                incr n
                if {$n == 0} {
                    set rid [lindex [array get xy rowid] 1]
                    if {$rid != {}} { set (cur:firstrow) $rid }
                    set tn $(db:tbl)
                    MakeCols $_ $tn $tvd $xy(*) $tbl $isdata [expr {$isdata?$(dbtypes,$tn):""}]
                }
                set data [list # $n]
                array unset r
                set node -1
                foreach i $xy(*) {
                    set ni $i
                    if {$ni == "rowid"} {
                        set ni #
                        set node [expr {$xy($i)==""?-1:($xy($i)+1)}]
                    }
                    if {$ni == "#" && $xy($i) == {}} {
                        continue
                    }
                    set r($ni) $xy($i)
                }
                if {![info exists r(#)]} {
                    set r(#) $n
                }
                TreeView insert $tvd end $n -node $node -data [array get r]
                if {$n > $(maxrows)} { break }
            }
            if {$isdata && [info exists xy(rowid)]} {
                set (cur:lastrow) $xy(rowid)
            }
            return $n
        }
        
        proc GetRows {_ tn} {
            # Run query to get data rows 
            upvar $_ {}
            array set q $(dbschema,$tn)
            set get *
            if {![info exists q(pkey)] || $q(pkey) == {}} {
                set get rowid,*
            }
            append dir " LIMIT $(maxrows) OFFSET $(cur:startrow)"
            RunQuery $_ "SELECT $get FROM $tn $dir" data 1
        }

        proc Load {_ tn} {
            # Load table.
            upvar $_ {}
            variable tabs
            
            set tvs $(w,struct)
            set tvh $(w,schema)
            Text conf $tvh -state normal
            Text replace $tvh 1.0 end $(dbsqlc,$tn)
            Text conf $tvh -state disabled
            TreeView delete $tvs 0 end
            set (db:tbl) $tn
            # Load Schema window.
            set q(fields) {}
            if {![info exists (dbschema,$tn)]} {
                GetSchema $_ $(dbsqlc,$tn) $tn
            }
            array set q $(dbschema,$tn)
            set data {}
            set n -1
            set clst {}
            set types {}
            foreach {j k} $q(fields) {
                incr n
                lappend clst $j
                set data [list # $n Name $j]
                array unset r
                array set r $k
                lappend types $r(type)
                lappend data "Default Value" $r(default)
                lappend data "Data Type" $r(type)
                if {$r(primary)} { lappend data "Primary Key" True }
                if {$r(notnull)} { lappend data "Not NULL" True }
                TreeView insert $tvs end $n -data $data

            }
            # Handle empty table.
            set rsz [db onecolumn $(db) "SELECT COUNT(*) FROM $tn;"]
            set (v,status) "Table '$tn' has $rsz rows"
            if {$rsz == 0} {
                MakeCols $_ $tn $(w,data) $clst $tn 1 $types
                return
            }
            
            # Load the Data tab
            $_ DB::GetRows $tn
        }
    }

    namespace eval Query {
        
        Mod upvars _ tabs
        
        proc GetHist {_ x y} {
            # Copy sql from History to Query tab.
            upvar $_ {}
            set tv $(w,qhtbl)
            set ind [TreeView nearest $tv $x $y]
            if {$ind == {}} return
            set data [TreeView entry cget $tv $ind -data]
            array set d $data
            Text replace $(w,qtxt) 1.0 end $d(SQL)
            Tabset tab select $(w,qtab) SQL
        }
  
        namespace eval Tcl_Eval {
            proc Eval {db __script} {
                eval $__script
            }
        }
        proc Tcl {_} {
            # Eval Tcl code with access to $db.
            upvar $_ {}
            set script [Text get $(w,qtxt) 1.0 end]
            if {$script =={}} { return }
            if {![info complete $script]} {
                tk_messageBox -message "script not complete" -icon warning
                return
            }
            if {[catch {Tcl_Eval::Eval $(db) $script} rv]} {
                tk_messageBox -message $rv\n$::errorInfo -icon error
                return
            }
            if {[string length $rv]<30 && [string first \n $rv]<0} { 
                set (v,status) "Result: $rv"
            } else {
                set rq [string range $script 0 30]
                if {[string length $script]>30} { append rq ... }
                Tk::viewText $rv -label "Tcl Results of\n'$rq'" -title "Tcl Results"
            }

        }
      
        proc Run {_} {
            # Execute the SQL query.
            upvar $_ {}
            variable tabs
            set query [string trim [Text get $(w,qtxt) 1.0 end]]
            if {$query =={}} { return }
            if {![db complete $(db) $query]} {
                tk_messageBox -message "query not complete" -icon warning
                return
            }
            if {[catch {time {set cnt [$_ DB::RunQuery $query qrtbl]}} tim]} {
                tk_messageBox -message $tim -icon error
                return
            }
            set tim [lindex $tim 0]
            set tim [format %1.6f [expr {$tim/1000000.0}]]
            set tvd $(w,qhtbl)
            set n [lindex [TreeView find $tvd 0 end] end]
            if {$n == {}} { set n -1 }
            incr n
            foreach i $tabs(qhtbl) {
                if {$i == "#"} {
                    set r($i) $n
                    continue
                }
                switch -glob -- $i {
                    *Time       { set r($i) $tim }
                    *Date       { set r($i) [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] }
                    Rows   { set r($i) $cnt }
                    SQL         { set r($i) $query }
                }
            }
            TreeView insert $tvd end $n -data [array get r]
            Tabset tab select $(w,qtab) Results
        }
        
        proc Explain {_} {
            # Explain a query.
            upvar $_ {}
            set query [string trim [Text get $(w,qtxt) 1.0 end]]
            if {$query == {}} return
            if {![db complete $(db) $query]} {
                tk_messageBox -message "query not complete" -icon warning
                return
            }
            $_ DB::RunQuery "EXPLAIN $query" qrtbl
            Tabset tab select $(w,qtab) Results
        }
        
        proc Save {_} {
            # Save a query.
            upvar $_ {}
            if {[set fn [tk_getSaveFile -parent $(w,.) -title "Save query to" -filetypes $(filetypes)]] == {}} return
            *fwrite $fn [Text get $(w,qtxt) 1.0 end]
        }
        
        proc Load {_} {
            # Load a query.
            upvar $_ {}
            if {[set fn [tk_getOpenFile -parent $(w,.) -title "Query to insert" -filetypes $(filetypes)]] == {}} return
            set data [*fread $fn]
            Text insert $(w,qtxt) end $data
        }
        
        proc Clear {_} {
            # Clear query window.
            upvar $_ {}
            Text delete $(w,qtxt) 1.0 end
        }
        
        proc Export {_} {
        }
        
    }


    # File menu.
    namespace eval File {
        
        Mod upvars _ tabs
        
        proc OpenTbl {_ ind} {
            # Handle opening of table.
            upvar $_ {}
            if {!$(db:open)} return
            set tv $(w,dblist)
            set tags [TreeView tag names $tv $ind]
            if {[lsearch $tags table]<0 && [lsearch $tags view]<0} return
            set tbl [TreeView get $tv $ind]
            if {[set ssi [string first ( $tbl]]>0} {
                set tbl [string range $tbl 0 [incr ssi -1]]
            }
            if {$tbl == $(db:tbl)} return
            set (istable) [expr {[lsearch $tags table]>=0}]
            if {$(db:tbl) != {}} {
                set ot $(db:tbl)
                foreach i [array names {} cur:*] {
                    set ext [string range $i 4 end]
                    set (tbl,$ext,$ot) $($i)
                    set (cur:$ext) 0
                }
                foreach i [array names {} tbl,*,$tbl] {
                    set ext [lindex [split $i ,] 1]
                    set (cur:$ext) $($i)
                }
            }
            $_ DB::Load $tbl
            TreeView selection clearall $tv
            TreeView selection set $tv $ind
            TreeView focus $tv $ind
            $_ DB::UpdateRowCount $tbl
        }
        
        proc OpenTable {_ x y} {
            upvar $_ {}
            set tv $(w,dblist)
            set ind [TreeView nearest $tv $x $y]
            return [OpenTbl $_ $ind]
        }

        proc GetDefs {str} {
            set s [string first ( $str]
            set l [string last ) $str]
            set str [string range $str [incr s] [incr l -1]]
            return [string map {\" {} ' {}} $str]
        }
        
        proc Reload {_} {
            upvar $_ {}
            variable tabs
            set ff $(db)
            set fd [file dirname $(db:file)]

            set (db:open) 0
            set tvl $(w,dblist)
            set tvd $(w,data)
            set tvi $(w,indexes)
            set tvt $(w,triggers)
            set tvv $(w,views)
            TreeView delete $tvl all
            TreeView delete $tvi all
            TreeView delete $tvt all
            TreeView delete $tvv all
            set n 0
            set ni 0
            set nt 0
            set nv 0
            #TreeView bind $tvl table <1> [list $_ File::OpenTable %x %y]
            array set types {}
            TreeView column conf $tvl 0 -title [file tail $(db:file)]
            array set types { table 1 view 1 }
            db eval $ff {PRAGMA database_list} dbf {
                set fsz [file size $dbf(file)]
                if {$fsz>=1024} {
                    set fsz [expr {$fsz/1024}]K
                }
                set dbinf [list $fsz [file tail $dbf(file)] [file dirname $dbf(file)]]
                TreeView insert $tvl end $dbf(name) -data [list Size $dbinf]
                set ind [TreeView insert $tvl end $dbf(name)/Tables -forcetree 1]
                TreeView tag add $tvl tables $ind
                
                set tpre $dbf(name)/
                db eval $ff "SELECT * FROM $dbf(name).sqlite_master;" xx {
                    set ttl [string totitle $xx(type)]s
                    if {![info exists types($xx(type))]} {
                        TreeView insert $tvl end $tpre$ttl
                    }
                    set types($xx(type)) 1
                    set tn $dbf(name).$xx(name)
                    if {[info exists xx(sql)]} {
                        set (sql,$xx(type),$tn) $xx(sql)
                    }
                    set ind [TreeView insert $tvl end $tpre$ttl/$tn -label $xx(name)]
                    if {$xx(type) == "table"} {
                        set size [db onecolumn $ff "SELECT COUNT(*) FROM $tn"]
                        TreeView entry conf $tvl $ind -opencommand [list $_ File::OpenTbl %#] -data [list Size $size]
                        TreeView tag add $tvl table $ind
                        set (dbsqlc,$tn) $xx(sql)
                        set (dbtype,$tn) table
                        if {$n == 0 } {
                            set ftn $tn
                            TreeView selection set $tvl $ind
                            TreeView focus $tvl $ind
                        }
                        incr n
                    }
                
                    if {$xx(type) == "view"} {
                        array unset r
                        foreach i $tabs(views) {
                            if {$i == "#"} {
                                set r($i) $nt
                                continue
                            }
                            switch -glob -- $i {
                                *ame        { set r($i) $xx(name) }
                                SQL*        { set r($i) $xx(sql) }
                            }
                        }
                        db eval $ff "SELECT * FROM $tn;" xy {
                            set (dbtype,$tn) view
                            set (dbschema,$tn) {}
                            set (dbtypes,$tn) {}
                            set (dbsqlc,$tn) {}
                            break
                        }

                        TreeView insert $tvv end $nv -data [array get r]
                        TreeView tag add $tvl view $ind
                        incr nv
                    }
                
                    if {$xx(type) == "index"} {
                        array unset r
                        set lsql [string tolower $xx(sql)]
                        if {[set soi [string first " on " $lsql]]>=0} {
                            set oncol [string range $xx(sql) [incr soi 4] end]
                        } else {
                            set oncol {}
                        }
                        foreach i $tabs(indexes) {
                            if {$i == "#"} {
                                set r($i) $ni
                                continue
                            }
                            switch -glob -- $i {
                                *ame        { set r($i) $xx(name) }
                                *table      { set r($i) $dbf(name).$xx(tbl_name)}
                                *olumn      { set r($i) $oncol }
                                Unique      { set r($i) {} }
                                SQL*        { set r($i) $xx(sql) }
                            }
                        }
                        TreeView insert $tvi end $ni -data [array get r]
                        incr ni
                    }
                
                    if {$xx(type) == "trigger"} {
                        array unset r
                        set lsql [string tolower $xx(sql)]
                        if {[set soi [string first " of " $lsql]]>=0} {
                            set oncol [string range $xx(sql) [incr soi 4] end]
                            set oncol [lindex $oncol 0]
                        } else {
                            set oncol {}
                        }
                        if {[set soi [string first " on " $lsql]]>=0} {
                            set ontbl [string range $xx(sql) [incr soi 4] end]
                            set ontbl [lindex $ontbl 0]
                        } else {
                            set ontbl {}
                        }
                        foreach i $tabs(triggers) {
                            if {$i == "#"} {
                                set r($i) $nt
                                continue
                            }
                            switch -glob -- $i {
                                *ame        { set r($i) $xx(name) }
                                *olumn      { set r($i) $oncol }
                                *able       { set r($i) $dbf(name).$ontbl }
                                SQL*        { set r($i) $xx(sql) }
                            }
                        }

                        TreeView insert $tvt end $nt -data [array get r]
                        incr nt
                    }
                }
            }
            TreeView open $tvl tables
            set (db:open) 1
            if {[info exists ftn]} {
                $_ DB::Load $ftn
            }
        }
    
        proc Open {_  {f {}}} {
            # Open a new db file.
            upvar $_ {}
            if {$f == {}} {
                set f [tk_getOpenFile -parent $(w,.) -title "Open Existing Database" -filetypes $(filetypes)]
                if {$f == {}} {
                    set f [tk_getSaveFile -parent $(w,.) -title "Create New Database" -filetypes $(filetypes)]
                }
                if {$f == {}} return
            } elseif {![file exists $f]} {
                if {[tk_messageBox -message "Create new DB: $f?" -type okcancel]
                != "ok"} return
            }
            set fd [file rootname [file tail $f]]
            if {[catch {db open $f} ff]} {
                tk_messageBox -message "open failed: $ff" -icon error
                return
            }
            set (db,$fd) $ff
            set (db) $ff
            set (db:name) [file rootname [file tail $f]]
            set (db:file) $f
            Reload $_
            set (v,status) "Loaded database: $(db:name)"
        }
        
        proc Refresh {_} {
            # Refresh the tables view.
            upvar $_ {}
            if {$(db) == {}} {
                Open $_
            } else {
                Reload $_
            }
        }
        
        proc Attach {_} {
            # Attach an existing database file.
            upvar $_ {}
            if {$(db) == {}} {
                Open $_
            } else {
                set f [tk_getOpenFile -parent $(w,.) -title "Attach a Database" -filetypes $(filetypes)]
                if {$f == {}} return
                set idx 1
                set nnam [set nam [file rootname [file tail $f]]]
                while {![catch {db eval $(db) "select count(*) from $nnam.sqlite_master"}] && $idx<100} {
                    set nnam $nam[incr idx]
                }
                db eval $(db) "ATTACH DATABASE '$f' AS $nnam;"
                Reload $_
            }
        }
        
        proc New {_} {
            # Start a new gsqlite instance.
            upvar $_ {}
            [namespace parent]::new
        }
        
        proc Console {_} {
            # Open a Tcl console.
            console show
        }

        proc Save {_} {
            # Save the file.
            upvar $_ {}
            if {$(filename) == {}} {
                tk_messageBox -message "Must save first"
                return
            }
            set t $(tabwin,$tab)
            set d [Text get $(w,text1) 1.0 end]
            *fwrite $f $d
        }
        
        proc Quit {_} {
            # Quit editor.
            if {[tk_messageBox -message "Ok to quit" -type yesno -default no]} {
                ::Delete
            }
        }
        
    }
    
    proc Code {_} {
        # Show the source code for gsqlite.
        variable pd
        ::Wiz::edit::new $pd(script)
    }

    proc Server {_} {
        # Start an SOS server on this database.
        upvar $_ {}
        set f {}
        if {$(db) == {}} {
            set f [tk_getOpenFile -parent $(w,.) -title "Open Existing Database" -filetypes $(filetypes)]
            if {$f == {}} return
            File::Open $_ $f
            if {$(db) == {}} return
        }
        ::lib sos new -server 2 -db $(db)
    }

    proc Client {_} {
        # Start an interactive SOS client against Server.
        ::lib sos new -client 2

    }

    proc Next {_} {
        # Show the next 1000 records.
        upvar $_ {}
        if {$(cur:firstrow)<0} return
        incr (cur:startrow) $(maxrows)
        $_ DB::GetRows $(db:tbl)
    }
    
    proc Previous {_} {
        # Show the previous 1000 records.
        upvar $_ {}
        if {$(cur:firstrow)<0} return
        if {[incr (cur:startrow) -$(maxrows)]<=0} {
            set (cur:startrow) 0
        }
        $_ DB::GetRows $(db:tbl)

    }
    
    proc Add {_} {
        # Add a new record.
        upvar $_ {}
        set tv $(w,data)
        set cl [TreeView column names $tv]
        if {[lindex $cl end] == "PRIMARY"} {
            set cl [lrange $cl 0 end-1]
        }
        set cn [llength $cl]
        incr cn -2
        set ind [TreeView index $tv view.top]
        if {$ind == {}} {
            set ind end
        }
        db eval $(db) "INSERT INTO $(db:tbl) DEFAULT VALUES;"
        set rowid [db last_insert_rowid $(db)]
        set data [list # $rowid]
        db eval $(db) "SELECT * FROM $(db:tbl) WHERE rowid == $rowid;" xy {
            foreach i [lrange $cl 2 end] {
                lappend data $i $xy($i)
            }
            TreeView insert $tv $ind $rowid -data $data
            break
        }
        update
        TreeView see $tv end
        TreeView selection set $tv end
        $_ DB::UpdateRowCount $(db:tbl)
    }
    
    proc Delete {_} {
        # Delete the currently selected record.
        upvar $_ {}
        if {[tk_messageBox -type okcancel -icon warning -message [mc "Ok to delete row"]] != "ok"} return
        set tv $(w,data)
        set ind [TreeView index $tv focus]
        set data [TreeView entry cget $tv $ind -data]
        array set d $data
        set query "DELETE FROM $(db:tbl) WHERE rowid = $d(#);"
        db eval $(db) $query
        TreeView delete $tv $ind
        $_ DB::UpdateRowCount $(db:tbl)
    }
    
    proc Edited {_ w x y} {
        # Handle completion of edit by updating sqlite.
        upvar $_ {}
        set cind $x
        set ind $y
        set col [lindex [TreeView column names $w] $cind]
        set val [TreeView entry set $w $ind $col]
        set rowid [TreeView entry set $w $ind #]
        set query [format {UPDATE %s SET %s = $val WHERE rowid = $rowid;} $(db:tbl) $col]
        db eval $(db) $query
    }
    
    proc Close {_} {
        ::Delete $_
    }
    
    proc EditCheck {_ w ind col} {
        # Disable editing if not a table.
        upvar $_ {}
        if {$w == $(w,data)} {
            if {!$(istable)} { return {-readonly 1} }
        }
    }
    
    proc Main {_ args} {
        # Instantiate new sqlite frontend.
        upvar $_ {}
        variable tabs

        set wdb $(w,dblist)
        set (editopts) {-autonl 1 -optscmd}
        lappend (editopts) [list $_ EditCheck]
        TreeView conf $(w,data) -allowduplicates 1 -flat 1
        foreach {tbl lst} [array get tabs] {
            set tv $(w,$tbl)
            $tv column conf 0 -hide 1
            DB::MakeCols $_ $tbl $tv $lst $tbl
        }
        Spinbox conf $(w,startrow) -textvariable ${_}(cur:startrow)
        TreeView column conf $wdb 0 -title "DB"
        TreeView column insert $wdb end Size -justify left
        set n 0
        foreach cn [TreeView column names $wdb] {
           styles item $wdb column $n
           incr n
       }
        set nics [list blt::tv::normalFile blt::tv::openFile]
        TreeView conf $wdb -leaficons $nics -autocreate 1
        bind $(w,qhtbl) <Double-1> [list $_ Query::GetHist %x %y]
        bind $(w,data) <<TreeViewEditEnd>> [list $_ Edited %W %x %y]
        TreeView conf $(w,data) -flat 1
        TreeView conf $(w,qrtbl) -flat 1
        bind $wdb <1> [list $_ File::OpenTable %x %y]
        bind $wdb <Alt-Shift-3> [list $_ File::Reload]
        after idle [list $_ File::Open [lindex $args 0]]
    }
    
    proc Cleanup {_ args} {
        # Handle dialog close.
        upvar $_ {}
        if {![winfo exists $(w,.)]} return
        set r [tk_messageBox -parent $(w,.) -type okcancel -message "Ok to abandon?"]
        if {$r != "ok"} { return -code continue }
    }
    
    # Setup gui environment and if required run [Main] app.
    Tk::gui create {
        style {
            Toplevel {
                *Button.padY 0
                *Tabset.slant right
                *Text.tile {}
                @deffonts {
                    main    {Verdana,Helvetica,Courier -12 bold}
                    rowid   {Verdana,Helvetica,Courier -12 bold}
                    body    {Verdana,Helvetica,Courier -12}
                }
                *TreeView.font ^body
                @guiattrsmap {
                    -img {
                        run      gear
                        explain  { help contexthelp }
                        clear    eraser
                        save     filesave
                        load     fileopen
                        delete   editremove
                        next     mvforward
                        previous mvback
                        add      editadd
                        tcl      run
                    }
                    -key {}
                }
                ##@@image {*tile chalktile.gif -gamma 2}
            }
            .qtab { -slant none }
            Button.run { -cursor hand2 }
            Button.tcl { -cursor hand2 @tip "Eval Tcl with access to $db"}
            Tabset { -font ^main -tiers 4 }
            TreeView.dblist { -font ^main }
            TreeView {
                -bg White -underline 1
                -selectbackground DarkBlue -selectforeground White
                -nofocusselectbackground SteelBlue -nofocusselectforeground White
                @eval {
                    TreeView style create textbox %W alt -bg LightBlue
                }
                -altstyle alt

            }
            TreeView::column {
                -relief raised -borderwidth 1 -pad 5
                -command {blt::tv::SortColumn %W %C}
            }
            TreeView::column::odd { }
            TreeView::column::style::1 {  -font ^rowid }
            TreeView::style::alt.qrtbl { -bg Aquamarine }

            .dblist* { @bind { <3> !dbmenu } }
            .dbuts { }
            .qtxt { -height 10 -undo 1 }
            .startrow { -width 12 @tip   "Starting row for next/previous" }

        }
        
        {Toplevel + -title "Gsqlite" -geom 800x600} {
            {Menu +} {
                {menu + -label File} {
                    x {Server}
                    x {Client}
                    sep {}
                    x Close
                }
                {menu + -label Help} {
                    x {Code}
                }
            }
            {Menu + -id dbmenu -ns File -pos ^} {
                x Attach
                x Refresh
                x New
                x Console
            }

            {Frame + -pos *} {
                {statusbar - -num 2 -ids {linestatus status}} {}
                {Panedwindow + -pos *} {
                    {pane +} {
                        {Tabset + -id listtab -pos *} {
                            {tab +} {
                                {TreeView - -id dblist -scroll * -conf {-separator /} -pos *} {}
                            }
                        }
                    }
                    {pane +} {
                        {Frame + -pos *} {
                            {Tabset + -id datatab -pos *} {
                                {tab + -label Data} { 
                                    {Frame + -id dbuts -subpos l  -pos _} {
                                        {Button - -id delete} Delete
                                        {Button - -id add} Add
                                        {Button - -id previous} Previous
                                        {Button - -id next} Next
                                        {Spinbox - -id startrow -type int} {}
                                    }
                                    {TreeView - -id data -scroll * -pos *} {}
                                }
                                {tab + -label Query -subns &Query} {
                                    {Tabset + -id qtab -pos *} {
                                        {tab + -label SQL -tip "Execute queries"} {
                                            {Frame + -subpos l  -pos _} {
                                                {Button - -id run} Run
                                                {Button - -id explain} Explain
                                                {Button - -id clear} Clear
                                                {Button - -id save} Save
                                                {Button - -id load} Load
                                                {Button - -id tcl} Tcl
                                            }
                                            {Text - -id qtxt -scroll * -pos *} {}
                                        }
                                        {tab + -label Results -tip "Display results of query"} {
                                            {##Frame + -subpos l  -pos _} {
                                                Button Export
                                            }
                                            {TreeView - -id qrtbl -scroll * -pos *} {}
                                        }
                                        {tab + -label History -tip "History of previous queries"} {
                                            {##Frame + -subpos l  -pos _} {
                                                Button ClearHistory
                                            }
                                            {TreeView - -id qhtbl -scroll * -pos *} {}
                                        }
                                    }
                                }
                                {tab + -label Views} { 
                                    {TreeView - -id views -scroll * -pos *} {}
                                }
                                {tab + -label Indexes} { 
                                    {TreeView - -id indexes -scroll * -pos *} {}
                                }
                                {tab + -label Triggers} { 
                                    {TreeView - -id triggers -scroll * -pos *} {}
                                }
                                {tab + -label Schema} {
                                    {Panedwindow + -pos * -vertical 1} {
                                        {pane +} {
                                            {TreeView - -id struct -scroll * -pos *} {}
                                        }
                                        {pane +} {
                                            {Text - -id schema -scroll * -pos *} {}
                                        }
                                    }
                                }
                                {##tab + -label Constraints} { 
                                    {TreeView - -id constraint -scroll * -pos *} {}
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
}

