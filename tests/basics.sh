#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
ABSPATHSCRIPT=`readlink -f "$0"` && function die { echo "${ABSPATHSCRIPT##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }

echo OK
