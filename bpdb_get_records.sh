#!/bin/ksh

#=============================================================================
#
# bpdb_get_records.sh
# -------------------
#
# Produces a CSV file of information about the jobs performed by a
# NetBackup server. Must be run as root. Errors to stderr.
#
# The columns in the file are as follows. Numbers in (parentheses) are
# the original column numbers in the bpdbjobs output.
#
#   1 (1)  job id
#   2 (4)  exit status
#   3 (5)  policy
#   4 (6)  schedule
#   5 (7)  client
#   6 (9)  start time
#   7 (11) finish time
#   8 (34) parent id
#   9 (15) kbytes written
#   10 (16) files written
#   11 (12) storage unit
#   12 (2) job type
#
# Normally produced date for "today". That is, backups begun since the
# last midnight. Can also be run with -dn where n is the number of days
# to step back. e.g.
#
#   bpdb_get_records.sh -d4
#
# gets records from four days ago.
#
# If -d is supplied, and d > 1, output is written to stdout. Otherwise
# it goes to a log file. See VARIABLES section for the location of that
# file.
#
# R Fisher 01/08
#
# Please record changes below.
#
# v1.0 initial release
#
# v1.1 Now get all jobs which started on the day in question, regardless of
#      their finish time. RDF 13/02/08
#
# v1.1a Grab the job type so we can make sense of image cleanups (type 17) and
#      disk to tape image relocations (type  . NWP 05/06/08
#
# v1.2 Copies its files to a destination server rather than simply leaving
#      them in place. I'd rather the files be fetched, but the way our
#      various subnets interact with each other means this is no longer
#      possible. RDF
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

BPDBJOBS="/usr/openv/netbackup/bin/admincmd/bpdbjobs"
    # Path to bpdbjobs. The script will fail if it can't find this

OUTDIR="/var/tmp/bpdbout"
    # Where to put the file we create, if we create one

PATH=/usr/bin
    # set the path for safety and security

DAYS_BACK=0
	# by default we do "so far today"

TMPFILE=/var/tmp/${0##*/}.$$

REMOTE="audit@s-audit.localnet:/var/snltd/nb_data"
	# User@server:/directory to scp output file to

#-----------------------------------------------------------------------------
# FUNCTIONS

die()
{
	print -u2 "ERROR: $1"
	exit ${2:-1}
}

#-----------------------------------------------------------------------------
# EXECUTION STARTS HERE

[[ -x $BPDBJOBS ]] || die "can't execute bpdbjobs [ $BPDBJOBS ]"

mkdir -p $OUTDIR || die "can't create drop directory [ $DROPDIR ]"

while getopts "d:" option 2>/dev/null
do

	case $option in

		d)  DAYS_BACK=$OPTARG
			;;

		*)	cat<<-EOHELP
			usage: ${0##*/} [ -d <days> ]
			EOHELP
	esac

done

# Are we writing a file? If so, what and where? The /dev/fd/1 isn't really
# necessary with the way the awk command redirects, but it's in for
# completeness. I only use the TZ trick for one day. It breaks fairly
# quickly, hence the stdout thing/copout.

if [[ $DAYS_BACK -eq 0 ]]
then
	OUTFILE=${OUTDIR}/bpdbjobs-$(date +"%Y%m%d").csv
elif [[ $DAYS_BACK -eq 1 ]]
then
	OUTFILE=${OUTDIR}/bpdbjobs-$(TZ=GMT+24 date +"%Y%m%d").csv
else
	OUTFILE=/dev/fd/1
fi

# Get current hours, minutes, seconds as H M and S respectively

date | tr : " " | read d1 m d2 H M S junk

# now work out seconds since midnight, and export it for nawk. export
# DAYS_BACK while we're at it

export SSM=$(($H * 3600 + $M * 60 + $S + 1)) DAYS_BACK

# now we can ask for records before midnight on the day in question (usually
# today) but after midnight the day before.  nawk srand() function returns
# seconds since the epoch on first invocation.

$BPDBJOBS -most_columns | nawk -F, \
    'BEGIN {
        srand();
		MIDNIGHT = srand() - ENVIRON["SSM"];
		EARLIEST = MIDNIGHT - (ENVIRON["DAYS_BACK"] * 86400);
        LATEST = EARLIEST + 86399;
        OFS = ",";
    }

    ($9 >= EARLIEST && $9 < LATEST) {
        print $1, $4, $5, $6, $7, "X"$9"X", $11, $34, $15, $16, $12, $2

    }' \
> ${TMPFILE}.1

# Getting the proper start time is kind of hard. We have to use
# -all_columns, which awk chokes on. Field 32 is the filelist count.
# Once you have that, you can find the trycount, field 33 + filelist =
# trycount.  If this is 1, field (33 + file list count + 4) is the time
# the first try started.

# If there were two tries, you need to get the number of entries in the
# status field, which is (33 + file list count + 9), then use that
# number to get the second start time -- (33 + file list count + 9 +
# status count + 6)

# As I said, awk can't handle this. Perl can, but I'm not very good at
# perl, and I'm pretty sure cut can take really long lines. So....

$BPDBJOBS -report -all_columns > ${TMPFILE}.2

# For each line in the file we generated earlier,

cut -d, -f1 ${TMPFILE}.1 | while read jobid
do
	line="$(egrep ^$jobid, ${TMPFILE}.2)"
	filelist=$(print "$line" | cut -d, -f32)
	time=$(print "$line" | cut -d, -f$((33 + $filelist + 4)))
	[[ -z $time ]] && time='\\1'
	sed -n "/^$jobid,/s/X\([0-9]*\)X/$time/p" ${TMPFILE}.1
done > $OUTFILE

rm -f ${TMPFILE}.1 ${TMPFILE}.2

# Copy all the audit files we have, just in case one got missed somewhere

print -n "Copying file to remote server: "

scp -qCp ${OUTDIR}/* $REMOTE \
    && print "ok" || print "failed"

# done
