#!/bin/bash

if test "$3" = "" ; then
  echo "Usage: <src> <base version> <label>"
  exit 1
fi

export FREECIV_LABEL_FORCE="$3"

if ! ./patch_sources.sh "$1" "$2$3" ||
   ! ./build_server.sh "$2$3"
then
  echo "Build failed!" >&2
  exit 1
fi
