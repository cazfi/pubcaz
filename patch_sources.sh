#!/bin/bash

export FILTEREDTYPES=".png .svg .ogg .ttf .spec .tilespec .jpg .po .git ChangeLog setup_auth_server.sh .gitignore"
export FILTEREDDIRS="client themes doc graphics .git windows"

# $1 - Version
# $2 - Patch
apply_patch() {
   echo "Applying $2"

   if ! patch -Nurd -p1 -d "patched/$TGTVERSION" < "$2"
   then
      echo "Failed to patch $TGTVERSION with \"$2\""
      return 1
   fi
}

copy_file() {
  TGTDIR=$(dirname "$2")

  if ! mkdir -p "$TGTDIR"
  then
    echo "Failed to create directory $TGTDIR" >&2
    return 1
  fi

  if ! cp "$1" "$2" ; then
    echo "Failed to copy file $1" >&2
    return 1
  fi
}

pass_filter() {

  case "$(basename $1)" in

    # Every Makefile.am must pass
    Makefile.am)
      return 0 ;;

    # Files that configure uses as input must pass
    *.in)
      return 0 ;;

  esac

  # Filter by directory hierarchy (client data not needed)
  for FILTERENTRY in $FILTEREDDIRS
  do
    if echo $1 | grep "/$FILTERENTRY/" >/dev/null
    then
      return 1
    fi
  done

  # Filter by file type (client data not needed)
  for FILTERENTRY in $FILTEREDTYPES
  do
    if echo $1 | grep "$FILTERENTRY\$" >/dev/null
    then
      return 1
    fi
  done

  return 0
}

if test "$1" = "-h" || test "$1" = "--help" || test "$1" = "" ; then
  echo "$(basename $0) <source version> [target version number]"
  exit 1
fi

export SRCVERSION="$1"
export TGTVERSION="$2"

if test "$TGTVERSION" = "" ; then
  TGTVERSION="$SRCVERSION"
fi

if ! [ -d "src/$SRCVERSION" ] || [ "$SRCVERSION" = "" ]
then
  echo "No version \"$SRCVERSION\" sources available as \"src/$SRCVERSION\"" >&2
  exit 1
fi

if ! [ -d "patches/$TGTVERSION" ] || [ "$TGTVERSION" = "" ]
then
  echo "No version \"$TGTVERSION\" patches available in \"patches/$TGTVERSION\"" >&2
  exit 1
fi

rm -Rf "patched/$TGTVERSION"

( cd src/$SRCVERSION && find . -type f ) | grep -v "/\.svn" |
 (
   while read FILE
   do
     if pass_filter $FILE ; then
       echo "Copying $FILE"
       if ! copy_file src/$SRCVERSION/$FILE patched/$TGTVERSION/$FILE
       then
         exit 1
       fi
     fi
   done

   # Build requires ChangeLog, create dummy file.
   touch patched/$TGTVERSION/ChangeLog
 )

for patch in $(ls -1 patches/$TGTVERSION/*.patch 2>/dev/null | sort )
do
  if ! apply_patch "$TGTVERSION" "$patch"
  then
     exit 1
  fi
done
