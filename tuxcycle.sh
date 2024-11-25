#!/bin/ksh
#tuxcycle.sh - script to stop and restart all PSAPPSRV processes in a PeopleSoft Application Server domain
#(c)Go-Faster Consultancy 2002-2008
#https://blog.psftdba.com/2008/08/how-to-clear-application-server-cache.html

#list value of named environment variable
envit() (
for i in $*
  do
    set | grep "${i}="
done
)

tuxcmd() (

(
$TUXDIR/bin/tmadmin -r <<! 2>/dev/null 
psr
!
) | egrep "PSAPPSRV" | egrep "APPQ" | sort  |\
awk '
{
    printf("stop -g %s -i %s\n",$3,$4);
    printf("boot -g %s -i %s\n",$3,$4); 
}'

)

recycleit() (

uname -a
date
if [ $VERBOSE -eq 0 ]
  then
    $TUXDIR/bin/tmadmin <<! 2>&1 | egrep -i "$TUXDOMAIN|process|succeed|CMDTUX_CAT|TMADMIN_CAT|Error"
`tuxcmd`
!

else
    $TUXDIR/bin/tmadmin <<!
`tuxcmd`
!
fi
date

)

###########################################################################
#set -x
TIMENOW=`date +"%Y%m%d.%H%M%S"`
NOW=`date +"%H%M"`
CMDLINE="$0 $*"
SCRIPT=`basename $0 .sh`
NODENAME=`uname -n`
OSNAME=`uname -s`

if [ $# -lt 1 -o $# -gt 2 ]
  then
    echo "Recycle the PSAPPSRV processes in a given domain"
    echo "Usage: $0 <domain name> [-v] [-x]"
    echo "-v verbose mode"
    echo "-x set debug mode"
    exit 1
fi

TUXDOMAIN=$1
shift
VERBOSE=0

while [ $# -gt 0 ]
  do
    if [ "$1" = "-v" ]
      then 
	VERBOSE=1
	shift
    elif [ "$1" = "-x" ]
      then
        set -x
        shift
    else
        break
    fi
done

export TUXCONFIG=$PS_HOME/appserv/${TUXDOMAIN}/PSTUXCFG
export PS_SERVDIR=$PS_HOME/appserv/$TUXDOMAIN
export PS_SERVER_CFG=$PS_SERVDIR/psappsrv.cfg
#export TUXDIR=/cipp/people/product/8.1.5/tux6512 # location of tuxedo directory

if [ ! -n "${TUXDIR}" ]
  then
    echo "Error: TUXDIR environmental variable not set"
    exit 1
fi
if [ ! -d ${TUXDIR} ]
  then
    echo "Error: TUXDIR variable set to '$TUXDIR', not a directory"
    exit 1
fi

if [ ! -f $TUXCONFIG ]
  then
    echo "Error: cannot find Tuxedo configuration file $TUXCONFIG"
    exit 1
fi

if [ ! -d ${PS_HOME} ]
  then
    echo "Error: PS_HOME environmental variable not set"
    exit 1
fi

if [ ! -d ${PS_HOME} ]
  then
    echo "Error: PS_HOME variable set to '${PS_HOME}', not a directory"
    exit 1
fi

if [ ! -f ${PS_HOME}/psconfig.sh ]
  then
    echo "Error: psconfig.sh script not in PS_HOME (${PS_HOME})"
    exit 1
fi

#if [ ! -x ${PS_HOME}/psconfig.sh ]
#  then
#    echo "Error: ${PS_HOME}/psconfig.sh is not executable"
#    exit 1
#else
#    . ${PS_HOME}/psconfig.sh
#fi

if [ ! -d $PS_SERVDIR ]
  then
    echo "Error: Cannot find PS_SERVDIR directory '$PS_SERVDIR'"
    exit 1
fi

if [ ! -f $PS_SERVER_CFG ]
  then
    echo "Error: Cannot find PeopleSoft Application server configuration file $PS_SERVER_CFG"
    exit 1
elif [ ! -r $PS_SERVER_CFG ]
  then
    echo "Error: Cannot read PeopleSoft Application server configuration file $PS_SERVER_CFG"
    exit 1
fi

if [ ! -d $TUXDIR ]
  then
    echo "Error: Cannot find Tuxedo directory $TUXDIR"
    exit 1
fi

recycleit
#tuxcmd

