#!/bin/bash
file=$1
shift

perl -i -ne 'if (m@^#!/bin/bash@) {
        print q@#!/bin/bash
#
### BEGIN INIT INFO
# Provides:       nv_peer_mem
# Required-Start: openibd
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Description:    Activates/Deactivates nv_peer_mem to \
#                 start at boot time.
### END INIT INFO
@;
                 } else {
                     print;
                 }' ${file}
