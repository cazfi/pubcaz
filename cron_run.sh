#!/bin/dash

cd $(dirname $0)

if test "$1" = "-h" || test "$1" = "--help" || test "$1" = "" ; then
  echo "Usage: $0 <server version> [port] [ruleset] [extra config] [scenario]"
  exit 0
fi

LANG="en_US.UTF-8"
export LANG
FREECIV_LOCAL_ENCODING="UTF-8"
export FREECIV_LOCAL_ENCODING

if test "$2" = "" ; then
  PORT=5556
else
  PORT="$2"
fi

umask 0002

if test -f servers.stop || test -f portflags/server.$PORT || test -f cron.disabled ; then
  exit 0
fi

touch portflags/server.$PORT

if ! ./run_server.sh "$1" "$PORT" on "$3" "$4" "$5" >/dev/null; then
  echo "Freeciv server run failed (\"$1\" \"$PORT\")" >&2
fi

rm portflags/server.$PORT
