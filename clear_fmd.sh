#!/bin/ksh

# Clears the FMD logs on Solaris 11

PATH=/bin:/usr/sbin

svcadm disable -s svc:/system/fmd:default
find /var/fm/fmd -type f | xargs rm
svcadm enable svc:/system/fmd:default


