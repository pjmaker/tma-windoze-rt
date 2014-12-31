#
package ifneeded snack 2.2 [format {
  set dir {%s}
  load $dir/libsnack[info sharedlibextension]
  catch {load $dir/libsnackmpg[info sharedlibextension]}
  load $dir/libsnackogg[info sharedlibextension]
  source $dir/snack.tcl
} $dir]

package ifneeded sound 2.2 [list load $dir/libsound[info sharedlibextension]]

package ifneeded snackogg 2.2 {package require snack 2.2}


