#!/bin/bash

create_workdir() {
  if [ -d "$1" ]
  then
    echo "Workdir \"$1\" already exist!" >&2
    return 1
  fi

  if ! mkdir "$1"
  then
    echo "Cannot create workdir \"$1\"" >&2
    return 1
  fi

  if ! test -f config/fc_auth.conf ; then
    echo "Database config file config/fc_auth.conf missing" >&2
    return 1
  fi

  if ! ln -s ../../config/fc_auth.conf "$1/"
  then
    echo "Cannot setup fc_auth.conf for \"$1\"" >&2
    return 1
  fi

  echo "Using Freeciv version \"$2\" with \"$3\" ruleset" > "$1/fcversion.txt"
}

MAINDIR=$(cd $(dirname $0) ; pwd)

cd $MAINDIR

if test "$1" = "-h" || test "$1" = "--help" || test "$1" = "" ; then
  echo "Usage: $(basename $0) <server version> [port] [metaserver info on/off=off] [ruleset] [extra config] [savegame]"
  exit 0
fi

if test -f config/setup ; then
  . config/setup
else
  echo "No local setup file config/setup found!"
  exit 1
fi

declare -i RAND_WAIT

if test "$FCTEST" != "" ; then
  WDH="testruns"
  RAND_WAIT=0
else
  WDH="workdirs"

  # Randomized wait so multiple servers do not lauch simultaneously
  # Set WAIT_RAND_MAX and CONST_WAIT in config/setup
  if test "$WAIT_RAND_MAX" = "" ; then
    WAIT_RAND_MAX=40
  fi
  RAND_WAIT=${RANDOM}%${WAIT_RAND_MAX}
  if test "$CONST_WAIT" != "" ; then
    RAND_WAIT=${RAND_WAIT}+${CONST_WAIT}
  fi
fi

if ! test -d "$WDH" || ! test -w "$WDH" ; then
  echo "There's no directory \"$WDH\" with write permissions" >&2
  exit 1
fi

RUNLOG="$WDH/runlog.log"

VERSION="$1"

if test "$5" != "-" ; then
  if test "$5" != "" ; then
    EXTRA_CONFIG="$5"
  else
    EXTRA_CONFIG="-d 3 -N"
  fi
fi

if test "$6" != "" ; then
  SAVEGAME="$6"
  SAVEGAME_PARAM="-f $6"
else
  SAVEGAME_PARAM=""
fi

if [ "$VERSION" = "" ] || ! [ -d "builds/$VERSION" ]
then
  NOSER=true
else
  SERDIR=$(cd "builds/$VERSION" ; pwd)
  if ! test -x "$SERDIR/fcser"
  then
    NOSER=true
  fi
fi

if [ "$NOSER" = "true" ]
then
  echo "No server $VERSION/fcser"
  exit 1
fi

if test "$4" = "rand" ; then
  if ! test -f rulesets/$VERSION/rand.conf ; then
    echo "Random ruleset requested, but there is no rand.conf" >&2
    exit 1
  fi
  declare -i TOTALRAND=0
  declare -i RANDOPTIONS=0
  RULESET=$(cat rulesets/$VERSION/rand.conf | (
    while read RS WEIGHT
    do
      RULESETS[$RANDOPTIONS]=$RS
      WEIGHTS[$RANDOPTIONS]=$WEIGHT
      TOTALRAND=$TOTALRAND+$WEIGHT
      RANDOPTIONS=$RANDOPTIONS+1
    done
    declare -i RANDRULESET=$RANDOM%$TOTALRAND
    RANDOPTIONS=0
    while test $RANDRULESET -ge ${WEIGHTS[$RANDOPTIONS]}
    do
      RANDRULESET=$RANDRULESET-${WEIGHTS[$RANDOPTIONS]}
      RANDOPTIONS=$RANDOPTIONS+1
    done
    echo ${RULESETS[$RANDOPTIONS]}
  ))
  echo RULESET: $RULESET
  if ! test -f rulesets/$VERSION/$RULESET.serv ; then
    echo "No ruleset $RULESET available"
    exit 1
  fi
elif test "$4" != "" && test "$4" != "default" ; then
  if ! test -f rulesets/$VERSION/$4.serv ; then
    echo "No ruleset $4 available"
    exit 1
  fi
  RULESET="$4"
else
  RULESET="default"
fi

if test "$2" = ""
then
  PORT_NAME="(default)"
  PORT_PARAM=""
else
  PORT_NAME="$2"
  PORT_PARAM="-p $2"
fi

if test "$3" != "" && test "$3" != "on" && test "$3" != "off" ; then
  echo "Illegal meta parameter \"$3\"" >&2
  exit 1
fi

if test "$IDENTITY" = "" ; then
  IDENT_PARAM=""
else
  IDENT_PARAM="-i $IDENTITY"
fi

sleep $RAND_WAIT

if ! test -f $WDH/id.txt ; then
  GAMEID=0
else
  GAMEID=$(cat $WDH/id.txt)
fi
((GAMEID=GAMEID+1))

echo -n "$GAMEID" > $WDH/id.txt

if test "$RULESET" != "" && test "$RULESET" != "default"
then
  TOPIC="$SERVERDESC / $RULESET (Game #$GAMEID)"
elif test "$SAVEGAME" != ""
then
  TOPIC="$SERVERDESC \"$(basename $SAVEGAME | sed 's/\.sav.*//')\" (Game #$GAMEID)"
else
  TOPIC="$SERVERDESC (Game #$GAMEID)"
fi

GAMEDIR="g${GAMEID}_p$$"
WORKDIR="$WDH/$GAMEDIR"

if ! create_workdir "$WORKDIR" "$VERSION" "$RULESET"
then
  exit 1
fi

if test "$3" = "on" ; then
  META_PARAM="-k"
else
  META_PARAM=""
fi

STARTSTAMP=$(date +"%d.%m.%y %H:%M:%S")
STARTMSG="$STARTSTAMP : Server $PORT_NAME ($VERSION:$RULESET) start: \"$WORKDIR\""
echo "$STARTMSG"
echo "$STARTMSG" >> $RUNLOG

if test -f $MAINDIR/rulesets/$VERSION/ranking ; then
  RANK_PARAM="-R ranking.log"
else
  RANK_PARAM=
fi

cd "$WORKDIR"

export FREECIV_DATA_PATH="$MAINDIR/rulesets/$VERSION"

SERCMDLINE="$SERDIR/fcser -e -q 300 -l fc.log -a -D fc_auth.conf -A none $SAVEGAME_PARAM $RANK_PARAM $META_PARAM $PORT_PARAM $IDENT_PARAM -S $GAMEID $EXTRA_CONFIG"

echo "$SERCMDLINE" > cmdline.txt

ulimit -c 50000
(
  echo "metamessage $TOPIC"
  if test "$HOMEPAGE" != "" ; then
     echo "metapatches See $HOMEPAGE"
  fi
  echo "set scorelog enabled"
  if test "$RULESET" != "default" ; then
    echo "read $MAINDIR/rulesets/$VERSION/$RULESET.serv"
  fi
  if test -e $MAINDIR/rulesets/$VERSION/$RULESET.msg ; then
    echo "connectmsg $(cat $MAINDIR/rulesets/$VERSION/$RULESET.msg)"
  fi
  echo -n
) | $SERCMDLINE 2>stderr.log >stdout.log

cd $MAINDIR

if test -x analyze_workdir.sh ; then
  ./analyze_workdir.sh "$WORKDIR" "$VERSION" "$RULESET" "$GAMEID"
fi

STOPSTAMP=$(date +"%d.%m.%y %H:%M:%S")
STOPMSG="$STOPSTAMP : Server $PORT_NAME ($VERSION:$RULESET) finished: \"$WORKDIR\""
echo "$STOPMSG"
echo "$STOPMSG" >> $RUNLOG
