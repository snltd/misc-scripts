#!/bin/ksh

#=============================================================================
#
# remote.sh
# ---------
#
# Open up konsoles or gnome-terminals on remote hosts.
#
# R Fisher 03/2007
#
# v1.0
# $1 is the host to connect to
#   -u : username to connect as
#   -m : method to use (currently only ssh or telnet)
#   -p : port to connect on
#   -c : caption for konsole window
#
# v1.1
# force X forwarding and compression. Use a different coloured konsole for
# telnet connections. RDF
#
# v1.2
# Add -h because I'm forgetting how to use it! Added -s to select a custom
# schema. 20/08/07 RDF
#
#=============================================================================


#-----------------------------------------------------------------------------
# VARIABLES

#-----------------------------------------------------------------------------
# FUNCTIONS

function die
{
	print "$1"
	exit ${2:-1}

}

function usage
{
	cat<<-EOUSAGE
	  usage: ${0##*/} [-p port] [-u user] [-m telnet|ssh] [-i keyfile] 
	         [-t desktop] [-s schema|profile] [-c caption] <host>... 
	EOUSAGE
	exit 1
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# Check for correct usage

[[ $# -eq 0 ]] && usage

# Get options

while getopts i:p:u:m:c:s:t:x: option 2>/dev/null
do
	case $option in
		
		p)	PORT=$OPTARG
			;;
	
		u)	USERNAME=$OPTARG
			;;

		m)	METHOD=$OPTARG
			;;

		c)	CAPTION=$OPTARG
			;;
	
		s)	CUST_SCHEMA=$OPTARG
			;;

		i)	ID_FILE="-i $OPTARG"
			;;

		t)	DESKTOP=$OPTARG
			;;

		x)	XTRAS=$OPTARG
			;;

		*)	usage
			;;

	esac
done

shift $(($OPTIND - 1))

USERNAME=${USERNAME:-$LOGNAME}
METHOD=${METHOD:-ssh}
CAPTION=${CAPTION:-remote session}

# If the user hasn't specified their DE, guess it

if [[ -z $DESKTOP ]]
then
	pgrep kdeinit >/dev/null && DESKTOP=kde || DESKTOP=gnome
else
	[[ $DESKTOP == "kde" || $DESKTOP == "gnome" ]] || die "unknown desktop"
fi

# Assemble the command, and run it for each given host. Launch terminals in
# the background, so we can open a bunch of them in one go if need be

for host in $*
do

	H_CAPTION="$host [$CAPTION]"

	if [[ $METHOD == "ssh" ]]
	then
		[[ -n $PORT ]] && PORT="-p$PORT"
		CMD="$METHOD $ID_FILE $XTRAS -X $PORT ${USERNAME}@$host"
	elif [[ $METHOD == "telnet" ]]
	then
		CMD="$METHOD $host $PORT"
	else
		die "unknown method [ $METHOD ]"
	fi

	if [[ $DESKTOP == "kde" ]]
	then
		term_cmd="konsole -T \"$H_CAPTION\" --caption \"$H_CAPTION\""
		[[ -n $SCHEMA ]] && term_cmd="${term_cmd} --schema \"$SCHEMA\""
	else
		term_cmd="gnome-terminal -t \"$H_CAPTION\" --hide-menubar"
		[[ -n $SCHEMA ]] && term_cmd="${term_cmd} --profile \"$SCHEMA\""
	fi

	$term_cmd -e "$CMD" &
done

