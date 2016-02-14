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

if test "x$1" = "x-h" || test "x$1" = "x--help" || test "x$1" = "x" ; then
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

if test "x$FCTEST" != "x" ; then
  WDH="testruns"
  RAND_WAIT=0
else
  WDH="workdirs"

  # Randomized wait so multiple servers do not lauch simultaneously
  # Set WAIT_RAND_MAX and CONST_WAIT in config/setup
  if test "x$WAIT_RAND_MAX" = "x" ; then
    WAIT_RAND_MAX=40
  fi
  RAND_WAIT=${RANDOM}%${WAIT_RAND_MAX}
  if test "x$CONST_WAIT" != "x" ; then
    RAND_WAIT=${RAND_WAIT}+${CONST_WAIT}
  fi
fi

if ! test -d $WDH || ! test -w $WDH ; then
  echo "There's no directory \"$WDH\" with write permissions" >&2
  exit 1
fi

RUNLOG="$WDH/runlog.log"

VERSION="$1"

if test "x$5" != "x-" ; then
  if test "x$5" != "x" ; then
    EXTRA_CONFIG="$5"
  else
    EXTRA_CONFIG="-d 3 -N"
  fi
fi

if test "x$6" != "x" ; then
  SAVEGAME="$6"
  SAVEGAME_PARAM="-f $6"
else
  SAVEGAME_PARAM=""
fi

if [ "x$VERSION" = "x" ] || ! [ -d "builds/$VERSION" ]
then
  NOSER=true
else
  SERDIR=$(cd "builds/$VERSION" ; pwd)
  if ! test -x "$SERDIR/fcser"
  then
    NOSER=true
  fi
fi

if [ "x$NOSER" = "xtrue" ]
then
  echo "No server $VERSION/fcser"
  exit 1
fi

if test "x$4" = "xrand" ; then
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
elif test "x$4" != "x" && test "x$4" != "xdefault" ; then
  if ! test -f rulesets/$VERSION/$4.serv ; then
    echo "No ruleset $4 available"
    exit 1
  fi
  RULESET="$4"
else
  RULESET="default"
fi

if test "x$2" = "x"
then
  PORT_NAME="(default)"
  PORT_PARAM=""
else
  PORT_NAME="$2"
  PORT_PARAM="-p $2"
fi

if test "x$3" != "x" && test "x$3" != "xon" && test "x$3" != "xoff" ; then
  echo "Illegal meta parameter \"$3\"" >&2
  exit 1
fi

sleep $RAND_WAIT

if ! test -f $WDH/id.txt ; then
  GAMEID=0
else
  GAMEID=$(cat $WDH/id.txt)
fi
((GAMEID=GAMEID+1))

echo -n "$GAMEID" > $WDH/id.txt

if test "x$RULESET" != "x" && test "x$RULESET" != "xdefault"
then
  TOPIC="$SERVERDESC / $RULESET (Game #$GAMEID)"
elif test "x$SAVEGAME" != "x"
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

if test "x$3" = "xon" ; then
  META_PARAM="-m"
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

ulimit -c 50000
(
  echo "metamessage $TOPIC"
  if test "x$HOMEPAGE" != "x" ; then
     echo "metapatches See $HOMEPAGE"
  fi
  echo "set scorelog enabled"
  if test "x$RULESET" != "xdefault" ; then
    echo "read $MAINDIR/rulesets/$VERSION/$RULESET.serv"
  fi
  if test -e $MAINDIR/rulesets/$VERSION/$RULESET.msg ; then
    echo "connectmsg $(cat $MAINDIR/rulesets/$VERSION/$RULESET.msg)"
  fi
  echo -n
) | $SERDIR/fcser -e -q 300 -l fc.log -a -D fc_auth.conf -A none $SAVEGAME_PARAM $RANK_PARAM $META_PARAM $PORT_PARAM -S $GAMEID $EXTRA_CONFIG 2>stderr.log >stdout.log

cd $MAINDIR

if test -x analyze_workdir.sh ; then
  ./analyze_workdir.sh "$WORKDIR" "$VERSION" "$RULESET" "$GAMEID"
fi

STOPSTAMP=$(date +"%d.%m.%y %H:%M:%S")
STOPMSG="$STOPSTAMP : Server $PORT_NAME ($VERSION:$RULESET) finished: \"$WORKDIR\""
echo "$STOPMSG"
echo "$STOPMSG" >> $RUNLOG
