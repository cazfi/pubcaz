#!/bin/bash

if test "$1" = "" || test "$1" = "-h" || test "$1" = "--help" ; then
  echo "Usage: $(basename "$0") <freeciv group>"
  exit 0
fi

if ! groups | grep "$1" >/dev/null ; then
  echo "You are not member of group \"$1\"" >&2
  exit 1
fi

if ! mkdir -p workdirs ||
   ! mkdir -p portflags ||
   ! mkdir -p src ||
   ! mkdir -p patches ||
   ! mkdir -p rulesets ||
   ! mkdir -p patched ||
   ! mkdir -p builds  ||
   ! mkdir -p config
then
  echo "Failure in directory creation" >&2
  exit 1
fi

if ! chown ":$1" workdirs ||
   ! chown ":$1" portflags ||
   ! chown ":$1" builds ||
   ! chown ":$1" rulesets ||
   ! chown ":$1" config
then
  echo "Failure in setting owner group for directories" >&2
  exit 1
fi

if ! chmod g+wx workdirs ||
   ! chmod g+wx portflags ||
   ! chmod g+rx builds ||
   ! chmod g+rx rulesets ||
   ! chmod g+rx config
then
  echo "Failure in setting group permissions for directories" >&2
  exit 1
fi

if test -f config/fc_auth.conf ; then
  echo "config/fc_auth.conf already exist. Not overwriting"
else
  echo "[fcdb]" > config/fc_auth.conf
  echo "backend=\"sqlite\"" >> config/fc_auth.conf
  echo "; Remember also to create and initialize the actual" >> config/fc_auth.conf
  echo "; database file auth.sqlite. See freeciv's README.fcdb." >> config/fc_auth.conf
  echo "database=\"$(pwd)/workdirs/auth.sqlite\"" >> config/fc_auth.conf

  if ! chown ":$1" config/fc_auth.conf ||
     ! chmod g+r config/fc_auth.conf
  then
    echo "Failed to set owner group setup for config/fc_auth.conf" >&2
    exit 1
  fi
fi

if test -f config/setup ; then
  echo "config/fc_auth.conf already exist. Not overwriting"
else
  echo "# Template setup, please edit to suit you installation" > config/setup
  echo "" >> config/setup
  echo "SERVERDESC=\"\"" >> config/setup
  echo "#HOMEPAGE=\"\"" >> config/setup
  echo "#WAIT_RAND_MAX=10" >> config/setup
  echo "#CONST_WAIT=5" >> config/setup
  echo "#IDENTITY=\"\"" >> config/setup

  if ! chown ":$1" config/setup ||
     ! chmod g+r config/setup
  then
    echo "Failed to set owner group setup for config/setup" >&2
    exit 1
  fi
fi

echo "Initial setup complete."
echo "Edit config/setup and config/fc_auth.conf to suit your needs next"
