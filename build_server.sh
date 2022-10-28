#!/bin/bash

if test "$1" = "-h" || test "$1" = "--help" ; then
  echo "Usage: $(basename $0) <srcver> [tgtver] [configure options]"
  exit
fi

SRCVERSION="$1"
TGTVERSION="$2"

if test "$MAKE" = "" ; then
  if which gmake > /dev/null ; then
    MAKE=gmake
  else
    MAKE=make
  fi
fi

if test "$TGTVERSION" = "" ; then
  TGTVERSION="$SRCVERSION"
fi

if [ "$SRCVERSION" = "" ] || ! [ -d "patched/$SRCVERSION" ]
then
  echo "No patched sources for \"$SRCVERSION\" available" >&2
  exit 1
fi

rm -Rf "builds/$TGTVERSION"

if ! mkdir -p "builds/$TGTVERSION"
then
  echo "Can't create build directory for \"$TGTVERSION\"" >&2
  exit 1
fi

SRCDIR=$(cd "patched/$SRCVERSION"; pwd)
BUILDDIR=$(cd "builds/$TGTVERSION" ; pwd)


export CFLAGS="-DNDEBUG $CFLAGS"
CONFOPTIONS="--enable-fcdb=sqlite3 --without-readline --disable-nls --disable-client --disable-fcmp --disable-freeciv-manual --disable-ruledit $3"

(
  cd "$BUILDDIR"

  export LDFLAGS="-rdynamic"

  export MAIN_VERSION=$(. $SRCDIR/fc_version && echo "$MAIN_VERSION")

  if "$MAIN_VERSION" = "" ; then
    # MAIN_VERSION added in freeciv-3.1, so this seems like freeciv-3.0 or earlier
    # And those did not pass parameters to generate_packets.py
    GEN_PACKETS_PARAMS=""
  else
    GEN_PACKETS_PARAMS="packets_gen.h packets_gen.c ../client/packhand_gen.h ../client/packhand_gen.c ../server/hand_gen.h ../server/hand_gen.c"
  fi

  if ! $SRCDIR/autogen.sh --sysconfdir=$(pwd)/etc --disable-client $CONFOPTIONS ||
     ! $MAKE -C gen_headers  ||
     ! ( cd $SRCDIR/common && ./generate_packets.py $GEN_PACKETS_PARAMS ) ||
     ! ( ! test -d dependencies || $MAKE -C dependencies ) ||
     ! $MAKE -C utility      ||
     ! $MAKE -C common       ||
     ! $MAKE -C ai           ||
     ! $MAKE -C server
  then
    echo "Server $TGTVERSION build failed" >&2
    exit 1
  fi

  if ! mkdir -p etc/freeciv ||
     ! cp $SRCDIR/lua/database.lua etc/freeciv/
  then
    echo "Setting up database.lua failed" >&2
    exit 1
  fi

  SERVERBIN=server/freeciv-server

  objcopy --only-keep-debug $SERVERBIN $SERVERBIN.dbg
  objcopy --strip-debug $SERVERBIN
  objcopy --add-gnu-debuglink=$SERVERBIN.dbg $SERVERBIN
)
