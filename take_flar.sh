#!/bin/ksh

# Take a flash archive of this server. Can be run from cron

FLAR_SRV="cs-build-01"
FLAR_DIR="/js/flar"
MPT="/flar"
HOST=$(uname -n)
umask 077

# Unmount the flar directory if it's mounted, so we know where we stand.
# Once the mount has gone, blow away the mountpoint and anything that might
# be under it. (For instance if a flar ran without the mount.)

if mount | egrep -s "^$MPT on ${FLAR_SRV}:$FLAR_DIR remote"
then
	print -n "unmounting ${MPT}: "
	
	if umount $MPT 2>/dev/null 
	then
		print "ok"
		rm -fr $MPT
	else
		print "failed"
		print -u2 "ERROR: can't unmount $MPT"
		exit 3
	fi

fi

# Can we get the archive directory?

print -n "checking flar directory is visible: "

if showmount -e $FLAR_SRV | egrep -s "^$FLAR_DIR "
then
	print "ok"
	mkdir -p $MPT
	print -n "mounting flar directory: "
	
	if mount ${FLAR_SRV}:${FLAR_DIR} $MPT
	then
		print "ok"
		mkdir -p ${MPT}/$HOST

		print -n "creating flar:"
		flar create -n "image created $(date)" \
		-x $MPT \
		-c \
		-a "${0##*/} script" \
		-S /flar/${HOST}/${HOST}-$(date "+%Y-%m-%d").flar

		print -n "unmounting flar directory: "

		if umount $MPT
		then
			print "ok" 
			rmdir $MPT
		else
			print -u2 "ERROR: couldn't unmount $MPT. Please tidy up by hand"
		fi

	fi

else
	print "failed"
	print -u2 "ERROR: can't see flar directory [ ${FLAR_SRV}/$FLAR_DIR ]"
	exit 1
fi

