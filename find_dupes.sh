#!/bin/ksh93

#=============================================================================
#
# find_dupes.sh
# -------------
#
# Find duplicate files in any number of directories. Written as something to
# do at work. Pretty fast! Requires ksh93 because it uses the fancy builtin
# uniq
#
# R Fisher 04/09
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

TMPFILE="/tmp/$$.$RANDOM.1"

#-----------------------------------------------------------------------------
# FUNCTIONS

function die
{
	print -u2 "ERROR: $1"
	exit ${2:-1}
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

[[ $# == 0 ]] \
	&& die "usage: ${0##*/} directory..." 2

for dir
do

	[[ -d $dir ]] \
		|| die "'$dir' is not a directory."

done

# Get a list of all files and their sizes

find $* -type f -ls | sed 's/ \{1,\}/ /g;s/^ *//' | cut -d\  -f 7,11-  \
| sort -n >$TMPFILE

# For each unique filesize, get the MD5 sum of all files, and if any of them
# match, print them

cut -d" " -f1 $TMPFILE | uniq -d | while read size
do

	# Ignore zero size files

	[[ $size -eq 0 ]] && continue

	egrep "^$size " $TMPFILE | while read s path
	do
		print -n "$path "
		digest -a md5 "$path"
	done | guniq --all-repeated=prepend -f 1 | cut -d\  -f1 | uniq

done 

rm $TMPFILE 

exit
