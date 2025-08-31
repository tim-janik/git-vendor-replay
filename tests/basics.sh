#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
ABSPATHSCRIPT=`readlink -f "$0"` && function die { echo "${ABSPATHSCRIPT##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
TESTDIR=$(dirname "$ABSPATHSCRIPT")

# == Setup ==
[[ " $* " =~ " -s " ]] && ISHELL=true || ISHELL=false
[[ " $* " =~ " --force " ]] && FORCE=true || FORCE=false
export TZ=UTC
export GIT_AUTHOR_DATE='@1700220000' GIT_AUTHOR_EMAIL="john@example.com" GIT_AUTHOR_NAME="John E. Xample"
export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export TEMPD=$(mktemp -d -t gvrtst.XXXXXX) &&
  trap "rm -rf $TEMPD" EXIT ||
    die "failed to create temp dir"
LOGFILE="$TEMPD/out.log"
[[ " $* " =~ " -x " ]] && {
  LOGFILE=/dev/stderr
  set -x
}

# == Helpers ==
repo_add()
{
  local MSG="$1" FILE="$2" TXT && shift 2
  cd "$REPO"
  for TXT in "$@"; do
    echo "$TXT" >> "$FILE"
  done
  git add -- "$FILE" >> "$LOGFILE" 2>&1
  git commit -m "$MSG" -- "$FILE" >> "$LOGFILE" 2>&1
  cd - >> "$LOGFILE" 2>&1
  GIT_AUTHOR_DATE="@$((${GIT_AUTHOR_DATE#@} + 8*86400))" && export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
}
repo_rm()
{
  local MSG="$1" FILE="$2" && shift 2
  cd "$REPO"
  git rm -f -- "$FILE" >> "$LOGFILE" 2>&1
  git commit -m "$MSG" -- "$FILE" >> "$LOGFILE" 2>&1
  cd - >> "$LOGFILE" 2>&1
  GIT_AUTHOR_DATE="@$((${GIT_AUTHOR_DATE#@} + 8*86400))" && export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
}
repo_init()
{
  test -z "${REPO-}" || die "Repo already initialized: $REPO"
  export REPO="$TEMPD/$1"
  mkdir -p "$REPO"
  ( cd "$REPO" && git init ) >> "$LOGFILE" 2>&1
  repo_add "README: first commit" README "# ${REPO##*/}" "" "Test repo"
}
vendor_add()
{
  FILE="$1"; shift
  cd "$VENDOR"
  for TXT in "$@"; do
    echo "$TXT" >> "$FILE"
  done
}
vendor_init()
{
  test -z "${VENDOR-}" ||
    die "Vendor dir already initialized: $VENDOR"
  export VENDOR="$TEMPD/$1"
  mkdir -p "$VENDOR"
  vendor_add "README.txt" "# Simple vendor directory" "" "VERSION: 1"
}

# == snapshots ==
assert_snapshot() # <var_refname> <reference_file> [script_with_var]
(
  local -n REFERENCE="$1" # refname
  DATA=$(< "$2") && DATA=${DATA#$'\n'} && DATA=${DATA%$'\n'}
  # compare
  test "$REFERENCE" == "$DATA" && return 0
  # Show diff
  cat <<< "$DATA" > "$TEMPD/$1.current"
  cat <<< "$REFERENCE" > "$TEMPD/$1.reference"
  echo && git -P diff --no-index "$TEMPD/$1.reference" "$TEMPD/$1.current" || echo
  rm -f "$TEMPD/$1.reference" "$TEMPD/$1.current"
  $FORCE && test -n "${3-}" && {
      echo ">> **FORCE** update of $3" > /dev/stderr
      $TESTDIR/update_snapshot.sh "$3" "$1" "$2"
      return 0
    }
  die "assert_snapshot failed to verify: $1"
  return 1
)

# == Tests ==
test_import1()
(
  echo && echo "== TEST: Test first import"

  vendor_init "VendorA"  # sets $VENDOR
  vendor_add "vendor.info" "Provided by Vendor Inc."
  vendor_add "v-junk.txt" "Left over junk..."

  repo_init "import1"     # sets $REPO
  repo_add "README: updates" README "Some text."
  GIT="git -C $REPO"
  git_log() { $GIT log --graph --pretty='%h %ae %as%d %s' "$@" | sed '/^[| ]*$/d'; }
  Head1=$($GIT rev-parse HEAD)

  ( cd "$REPO" && $TESTDIR/../git-vendor-replay "third_party/vendor-a" "$VENDOR" -b wip/VendorA -t VendorA-1 )
  ( $GIT merge --no-ff -m"Merge wip/VendorA v1" HEAD wip/VendorA ) >> "$LOGFILE" 2>&1

  git_log --all --stat > $TEMPD/snapshot.log
  SNAP1=$(cat << '__SNAPSHOT_EOF__'
*   15f339e john@example.com 2023-12-03 (HEAD -> master) Merge wip/VendorA v1
|\  
| * cbbf43d john@example.com 2023-12-03 (wip/VendorA) third_party/vendor-a: Vendor-dir import of VendorA-1
|/  
|    third_party/vendor-a/README.txt  | 3 +++
|    third_party/vendor-a/v-junk.txt  | 1 +
|    third_party/vendor-a/vendor.info | 1 +
|    3 files changed, 5 insertions(+)
* 153d5fd john@example.com 2023-11-25 README: updates
|  README | 1 +
|  1 file changed, 1 insertion(+)
* 79ce687 john@example.com 2023-11-17 README: first commit
   README | 3 +++
   1 file changed, 3 insertions(+)
__SNAPSHOT_EOF__
	 )
  assert_snapshot SNAP1 "$TEMPD/snapshot.log" "$ABSPATHSCRIPT"

  $ISHELL && (cd $REPO/ && bash -i )

  true
)

# == Run ==
test_import1
echo "  OK       All tests passed"
