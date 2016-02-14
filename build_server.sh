#!/bin/bash

if test "x$1" = "x-h" || test "x$1" = "x--help" ; then
  echo "Usage: $(basename $0) <srcver> [tgtver] [configure options]"
  exit
fi

SRCVERSION="$1"
TGTVERSION="$2"

if test "x$MAKE" = "x" ; then
    if which gmake > /dev/null ; then
        MAKE=gmake
    else
        MAKE=make
    fi
fi

if test "x$TGTVERSION" = "x" ; then
  TGTVERSION="$SRCVERSION"
fi

if [ "x$SRCVERSION" = "x" ] || ! [ -d "patched/$SRCVERSION" ]
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
CONFOPTIONS="--enable-fcdb=sqlite3 --without-readline --disable-nls --disable-client --without-ggz-dir --disable-fcmp --disable-freeciv-manual --disable-ruledit $3"

(
  cd "$BUILDDIR"

  export LDFLAGS="-rdynamic"

  if ! $SRCDIR/autogen.sh --sysconfdir=$(pwd)/etc --disable-client $CONFOPTIONS ||
     ! ( cd $SRCDIR/common && ./generate_packets.py ) ||
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
