#!/bin/ksh

#=============================================================================
#
# cs (casespace)
# --------------
#
# Remove non-alphanumerics from filenames and flatten case.
#
# R Fisher 2009
#
#=============================================================================

#-----------------------------------------------------------------------------
# FUNCTIONS

qualify_path()
{
    # Make a path fully qualified, if it isn't already. Can't go in the
    # functions file, because we need it to FIND the functions file!
    # $1 is the path to qualify

	typeset dir fnm

    if [[ "$1" != /* ]]
    then

		if [[ -d "$1" ]]
		then
			dir="$1"
		else

			[[ $1 == */* ]] \
				&& dir="${1%/*}"

			fnm="/${1##*/}"

		fi

        print "$(cd \"$(pwd)/$dir\"; pwd;)$fnm"
    else
        print $1
    fi

}

mk_name()
{
	# Do the case/space rename for a single file
	# $1 is the filename

	typeset -l outname=$1

	print $outname | sed 's/ \{1,\}/_/g;s/[^0-9a-z._]//g'
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

if [[ $# == 0 ]]
then
	print "usage: ${0##*/} file file ... file"
	exit 1
fi

for file in "$@"
do

	if [[ -f "$file" ]]
	then
		QUAL_PATH=$(qualify_path "$file")
		DIR_PART="${QUAL_PATH%/*}"
		FILE_PART="${QUAL_PATH##*/}"
		NEW_FILE=$(mk_name "$FILE_PART")

		if [[ "$NEW_FILE" != "$FILE_PART" ]]
		then
			print "${DIR_PART}/${FILE_PART}\n  -> $NEW_FILE"
			mv -i  "$QUAL_PATH" "${DIR_PART}/$NEW_FILE"
		fi
	else
		print "WARNING: '${file}' does not exist or is not a file."
	fi

done

