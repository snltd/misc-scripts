#!/bin/ksh

#=============================================================================
#
# patch_system.sh
# ---------------
#
# Simple script to call PCA and fully patch a system.  We keep a patch
# repository on a central server so patches only need to be downloaded once.
# You can use one machine as a "template" for another, so they can be
# brought to identical patch levels.
#
# It was originally written for a site which uses automounter, so the best
# way to run it is with something like
#
#  $ /net/server/export/patches/bin/patch_system.sh
#
# But if you don't have automounter, you can mount manually
#
#  $ mount server:/export/patches /mnt
#  $ /mnt/bin/patch_system.sh
#  $ umount /mnt
#
# Uses this directory structure, starting at $PATCH_DIR
#
#  |-- /bin            wget.i386, wget.sparc and pca binaries. Also, this
#  |                   script should be here
#  |-- /i386
#  |    |----- 5.9     patches for x86 Solaris 9
#  |    |----- 5.10    patches for x86 Solaris 10
#  |
#  |-- /sparc          like i386, but patches for SPARC
#  |
#  |--/patchdiag       each machine has its own directory in here. We store 
#                      the patchdiag.xref used to patch each box, which
#                      makes it easy to bring two machines to the same
#                      patch-level.
# 
# Requirements: PCA and an https-capable wget for each architecture you wish
# to patch. These should be named wget.i386 and wget.sparc. 
#
#   pca           http://www.par.univie.ac.at/solaris/pca/
#   wget source   ftp://ftp.gnu.org/gnu/wget
# 
# The wget binaries are compatible with all Solarises from 8 up, and have no
# dependencies.
#
# R Fisher 03/10
#
# Please log changes below.
#
# v2.0  Rewrite from scratch. Cleaner code, better annotated. RDF 12/03/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

USER="your_username"
PASS="your_password"
	# SunSolve account username and password. Visible through ps when the
	# script is run, but I figured that didn't really matter

#-----------------------------------------------------------------------------
# FUNCTIONS

die()
{
	# Print an error message and exit
	# $1 is the message
	# $2 is the exit code. Exits 1 if this is not supplied

	print -u2 "ERROR: $1"
	exit ${2:-1}
}

usage()
{
	# Print usage and exit

	cat<<-EOUSAGE
	usage:

	  ${0##*/} [-S server] [PCA options]

	where:
	  -S, --sync   : server to use as "template" for patching. PCA will be
	                 told to use the patchdiag.xref file that was used when
	                 the named server was last patched.
	
	  PCA options  : any options you wish to pass to PCA. Most useful is
	                 "-l", which lists uninstalled patches

	EOUSAGE
	exit 2
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Any options? I had to put the shift in the case to preserve options we
# *want* to pass through to PCA.

SHIFT=0

while getopts "S:(sync)h(help)" option 2>/dev/null
do

    case $option in

		S)	SYNC_TO=$OPTARG
			SHIFT=$(($SHIFT + 2))
			;;

		h)	usage
	esac

done

shift $SHIFT

# Get the hostname, Solaris version and architecture of this machine

uname -nrp | read HOST OSVER ARCH

# We need to work out where everything is relative to this script. Easy if
# we were run with a fully qualified path, harder if not

BN=${0##*/}

[[ $0 == /* ]] \
	&& BASE=${0%/bin/$BN} \
	|| BASE=$(pwd)/${0%/bin/$BN}

# Now we can work out some general paths

PCA="${BASE}/bin/pca"
WGET="${BASE}/bin/wget.$ARCH"
PATCH_BASE="${BASE}/$ARCH"
DIAG_BASE="${BASE}/patchdiag"

# and do some checks

[[ -d $PATCH_BASE ]] || die "No patch directory. [${PATCH_BASE}]"

[[ -d $DIAG_BASE ]] || die "No patchdiag directory. [${DIAG_BASE}]"

[[ -x $PCA ]] || die "No PCA executable. [${PCA}]"

[[ -x $WGET ]] || die "No suitable wget. [${WGET}]"

# Now work out directory paths specific to this machine and make sure they
# exist

PD="${PATCH_BASE}/$OSVER"
DD="${DIAG_BASE}/$HOST"

mkdir -p $PD $DD

[[ -d $PD ]] || die "Can't create patch directory. [${DD}]"

[[ -d $DD ]] || die "Can't create patchdiag directory. [${DD}]"

# If we've been given a server to sync to, see if there's a patchdiag.xref
# and if so, copy it to this machine's patchdiag directory so we can sync to
# this server if we want to

if [[ -n $SYNC_TO ]]
then
	SRCDIAG="${DIAG_BASE}/${SYNC_TO}/patchdiag.xref"

	[[ -f $SRCDIAG ]] || die "No patchdiag.xref for ${SYNC_TO}. [$SRCDIAG]"

	print -n "Copying patchdiag from ${SYNC_TO}: "

	if cp $SRCDIAG $DD
	then
		print "ok"
		DIAG_OPT="-y"
	else
		print "FAILED"
		die "Could not copy patchdiag.xref."
	fi

else
	DIAG_OPT="-x"
fi

# Now we are almost ready to run PCA. If the user supplied options (other
# than -S) we pass those through to PCA. If not, we pass -i -d (to install
# and keep downloaded patches)

[[ "x$*" == x ]] \
	&& OPTS='-i -d' \
	|| OPTS="$*"

print "\nRunning: pca $DIAG_OPT -X $DD ${OPTS}\n"

# Here's the PCA call. Note that we automatically update PCA whenever we
# can. Remove the --update=auto line to stop this.

$PCA \
	-P $PD \
	$DIAG_OPT -X $DD \
	$OPTS \
	--update=auto \
	--wget=$WGET \
	--user=$USER \
	--passwd=$PASS \
	--dltries=3

# And exit with PCA's exit code

