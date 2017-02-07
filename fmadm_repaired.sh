#!/bin/ksh

# I keep getting false errors on some lousy old disks. This script
# tells Solaris that all the errors visible to the fault management
# daemon have been repaired. Then we can all get on with our lives.

PATH=/usr/bin:/usr/sbin

fmadm faulty | awk '/FMRI/ {
    x = $NF; print substr(x, 2, length(x) - 2)
}'  | while read fault
do
    fmadm repaired $fault
done
