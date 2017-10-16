#!/bin/sh
#
# erlang.mk generator script.
#
#-----------------------------------------------------------------------------

errecho() {
  echo "$*" >&2
}

usage() {
  echo "Usage: ${0##*/} [options]"
  echo
  echo "Options:"
  echo "  --output=<file>, -o <file>"
  echo '      output file (default is ./erlang.mk, "-" prints to STDOUT)'
  echo "  --config=<file>, -c <file>"
  echo "      erlang.mk generation config (default is ./build.config if it exists,"
  echo "      version's original otherwise)"
  echo "  --list, -l"
  echo "      list available erlang.mk versions"
  echo "  --version=<version>, -v <version>"
  echo "      use <version> (default is $DEFAULT_VERSION)"
  echo "  --git-dir=<directory>, -d <directory>"
  echo "      instead of available versions, use <directory> git repository"
}

#-----------------------------------------------------------------------------

SEARCH_PATH="/usr/local/share/erlang.mk /usr/share/erlang.mk"

DEFAULT_VERSION=@@ERLANG_MK_VERSION@@
VERSION=
ERLANG_MK_DIR=
OUTPUT=
BUILD_CONFIG_FILE=
LIST_VERSIONS=false
MAKE_OPTIONS=

while [ $# != 0 ]; do
  case $1 in
    --help|-h) usage; exit ;;
    --output=*)   OUTPUT=${1#*=} ;;
    --output|-o)  OUTPUT=$2; shift ;;
    --config=*)   BUILD_CONFIG_FILE=${1#*=} ;;
    --config|-c)  BUILD_CONFIG_FILE=$2; shift ;;
    --list|-l)    LIST_VERSIONS=true ;;
    --version=*)  VERSION=${1#*=} ;;
    --version|-v) VERSION=$2; shift ;;
    --git-dir=*)  ERLANG_MK_DIR=${1#*=} ;;
    --git-dir|-d) ERLANG_MK_DIR=$2; shift ;;
    -*) errecho "unknown option: $1";   errecho; usage >&2; exit 1 ;;
    *)  errecho "unknown argument: $1"; errecho; usage >&2; exit 1 ;;
  esac
  shift
done

#-----------------------------------------------------------------------------

if [ "$LIST_VERSIONS" = true ]; then
  for dir in $SEARCH_PATH; do
    for cfg in "$dir"/*/build.config; do
      [ -f "$cfg" ] || continue
      ver=${cfg%/build.config}
      ver=${ver##*/}
      echo "$ver"
    done
  done
  exit
fi

#-----------------------------------------------------------------------------

if [ -n "$ERLANG_MK_DIR" ]; then
  # read git version of specified directory
  if ! which git > /dev/null 2>&1; then
    errecho "git is required for --git-dir option"
    exit 1
  fi
  VERSION=`cd "$ERLANG_MK_DIR" && git describe --tags --dirty` || exit 1
else
  for dir in $SEARCH_PATH; do
    dir="$dir/${VERSION:-$DEFAULT_VERSION}"
    if [ -e "$dir/build.config" ]; then
      ERLANG_MK_DIR=$dir
      break
    fi
  done
fi

if [ -z "$ERLANG_MK_DIR" ]; then
  if [ -n "$VERSION" ]; then
    errecho "Unknown erlang.mk version: $VERSION"
  else
    errecho "Default erlang.mk version $DEFAULT_VERSION not found."
  fi
  exit 1
fi

case $OUTPUT in
  "") OUTPUT=`pwd`/erlang.mk ;;
  -) OUTPUT=/dev/stdout; MAKE_OPTIONS="-s $MAKE_OPTIONS" ;;
  /*) : nothing ;;
  *) OUTPUT=`pwd`/$OUTPUT ;;
esac

case $BUILD_CONFIG_FILE in
  "")
    # config not specified, try ./build.config and default to erlang.mk's
    if [ -f build.config ]; then
      BUILD_CONFIG_FILE=`pwd`/build.config
    else
      BUILD_CONFIG_FILE=$ERLANG_MK_DIR/build.config
    fi
  ;;
  /*)
    : nothing
  ;;
  *)
    # relative path; make it absolute for `make -C'
    BUILD_CONFIG_FILE=`pwd`/$BUILD_CONFIG_FILE
  ;;
esac

# don't let any of the above variables leak down to the erlang.mk bootstrap
# script, but allow to use `make' different than /usr/bin/make
env -i PATH="$PATH" \
  make -C "$ERLANG_MK_DIR" $MAKE_OPTIONS \
          ERLANG_MK_VERSION="${VERSION:-$DEFAULT_VERSION}" \
          BUILD_CONFIG_FILE="$BUILD_CONFIG_FILE" \
          ERLANG_MK="$OUTPUT"

#-----------------------------------------------------------------------------
# vim:ft=sh
