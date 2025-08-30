#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
die() { echo "$0: **ERROR**: ${*:-aborting}" >&2 ; exit 127 ; }

# == Usage ==
[ $# -eq 3 ] ||
  die "Need 3 arguments; Usage: ${0##*/} <input_file> <marker> <reffile>"
INPUT="$1"
MARKER="$2"
REFFILE="$3"

# == Copy ==
# Copy orig to new to preserve attributes
cp -p "$INPUT" "$INPUT.tmp.new"

# == Replace Marker Text ==
# Keep this POSIX awk compatible
awk -v marker="$MARKER" -v reffile="$REFFILE" -f - "$INPUT" > "$INPUT.tmp.new" << '__END_AWK__'

# Do an in-place update of a heredoc-based "snapshot" variable within a shell script.
# - marker: The name of the shell variable holding the snapshot, e.g. `__LOGOUTPUT`
# - reffile: The path to a file containing the new snapshot content
BEGIN {
  # Construct the regex for the start of the heredoc assignment.
  # It looks for a line like: `  VAR=$(cat << '__SNAPSHOT_EOF__')`
  start_pat = "^[[:space:]]*" marker "=\\$\\(cat.*<<.*__SNAPSHOT_EOF__"
  # Regex for the end of the heredoc, which is simply a line containing `__SNAPSHOT_EOF__`
  end_pat = "^__SNAPSHOT_EOF__"
  # State variable: 1 if we are inside the heredoc to be replaced, 0 otherwise
  in_heredoc = 0
  # State variable: 1 if we have found the start of the target heredoc
  marker_found = 0
}

# This block runs for each line that matches the `start_pat` regex
$0 ~ start_pat {
  if (marker_found > 0) {
    print FILENAME ":" NR ": ERROR: Duplicate marker '" marker "' found (first at line " marker_found ")" > "/dev/stderr"
    exit 1
  }
  # Set state variables to indicate we've found the marker and are inside the heredoc
  in_heredoc = 1
  marker_found = NR
  # Print the matched line (the start of the heredoc assignment)
  print
  # Read the new content from the reference file (`reffile`) and print it
  while ((getline line < reffile) > 0) {
    print line
  }
  close(reffile)
  # Skip to the next line of the input file to avoid the default `{ print }` block.
  next
}

# This block runs for each line if `in_heredoc` is true.
in_heredoc {
  # If the current line is the end marker for the heredoc...
  if ($0 ~ end_pat) {
    # ...we are no longer inside the heredoc. The default action will print this line.
    in_heredoc = 0
  } else {
    # ...otherwise, it's old content that we want to discard. Skip to the next line.
    next
  }
}

# Default action: print the current line. This handles:
# - All lines before the target heredoc.
# - The `__SNAPSHOT_EOF__` line of the target heredoc (when `in_heredoc` becomes 0).
# - All lines after the target heredoc.
{ print }

# END block: This runs once after all input lines have been processed.
END {
  # If we went through the whole file and never found the marker, it's an error.
  if (marker_found == 0) {
    print FILENAME ":" NR ": ERROR: Marker not found: " marker > "/dev/stderr"
    exit 1
  }
}

__END_AWK__

# == Verify ==
! cmp -s "$INPUT.tmp.new" "$INPUT" &&
  die "${INPUT##*/}: Marker replacement failed for: $MARKER"

# == Replace ==
mv -v "$INPUT.tmp.new" "$INPUT"
