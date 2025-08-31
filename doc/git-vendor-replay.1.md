% GIT-VENDOR-REPLAY(1)    git-vendor-replay-0 | Git-Vendor-Replay Manual

# NAME

git-vendor-replay — create a pristine vendor import commit and prepare replay of local changes to a vendor directory


# SYNOPSIS

**git-vendor-replay** [**OPTIONS**] [**--rebase** | **-i**] *<vendor-dir>* *<import-src>*


# DESCRIPTION

**git-vendor-replay** helps maintain code that is vendored into a Git repository under a dedicated directory.
It creates a new commit that replaces *vendor-dir* with the contents of *import-src* (a pristine import).
If local commits have modified files under *vendor-dir* since the last import, the command extracts those changes and prepares to replay them on top of the new import commit.
In repositories colocated with Jujutsu (jj), the replay is printed or executed via `jj rebase …`.
In plain Git repositories, a ready-to-run `git rebase --onto …` command is printed, or executed directly if **--rebase** or **-i** is given.

The command does not move `HEAD` and does not modify the working tree of the current repository.
It operates through a temporary shared clone to assemble history, then fetches the new import commit (and, when necessary, a temporary branch containing the extracted changes) back into the current repository.
The branch named by **-b** will be created or force‐updated to point at either the new import commit or the tip of the replayed changes, depending on whether local vendor changes exist.

The last import is detected by scanning history for the most recent commit whose message contains an exact line of the form `Vendor-dir: <vendor-dir>`. Each import created by this tool includes that marker so that subsequent runs can locate it.

## OPTIONS

**-b** *vendor-branch*
: Name of the branch used to hold the linearized history of changes to *vendor-dir*. If omitted, it defaults to the value of *vendor-dir*. The name is sanitized to yield a valid git branch name. If a branch of that name already exists, it will be force‐updated.

**-h**, **--help**
: Print usage and exit.

**-i**
: Run `jj rebase` or `git rebase --interactive` in interactive mode.

**--rebase**
: Run `jj rebase` or `git rebase` non-interactively.

**-t** *version-tag*
: Text inserted into the new import commit subject as `Vendor-dir import of <version-tag>`. If omitted, the default is the literal value of *import-src*. The value is sanitized to yield a valid git tag name.

**--version**
: Print version and exit.

**--no-jj**
: Disable use of Jujutsu (`jj`) for replaying changes, even if it is available.

**-x**
: Enable shell tracing (`set -x`) and direct the script’s internal log to standard error.

### Arguments

*vendor-dir*
Path within the current Git repository where the vendored code resides. It may be nested (e.g., `third_party/libfoo`). The path is removed from the index and working tree for the new import commit and then re-added from *import-src*.

*import-src*
Filesystem path to the external source tree that should be imported into *vendor-dir*. It is copied recursively with `cp -a`. File modes are preserved by the copy; Git records content and mode changes as usual.


## NOTES

The import commit messages include a `Vendor-dir:` marker to enable future runs to locate the last import.
The commit history since the last import is flattened when extracting vendor-directory changes by cherry-picking non-merge commits in chronological order.
An existing *vendor-branch* will be force-updated; this intentionally discards any unrelated history on that branch in favor of the vendor-only lineage.
Conflicts during the subsequent rebase must be resolved by the user.
When using Jujutsu, the rebase will always succeed and conflicting commits can be resolved as usual.

### Requirements

Git must be installed and the command must run from the repository root. `git-filter-repo` must be available in `PATH`.
Jujutsu (`jj`) is optional; if present in a colocated configuration, the tool will issue `jj` commands to perform the replay and prints an operation-restore hint.


# EXIT STATUS

Zero indicates success. Failures triggered by explicit checks exit with status 127 and print an **ERROR** message.
Other nonzero statuses may result from underlying Git, `git-filter-repo`, `cp`, or Jujutsu commands under `set -e`.


# EXAMPLES

Create or update a vendored library under `third_party/libfoo`, using a checked-out upstream at `../libfoo-2.4.1`, record the version tag, and prepare to replay local patches on a dedicated branch:

```
git-vendor-replay third_party/libfoo ../libfoo-2.4.1 -t v2.4.1 -b libfoo
```

In a Git-only repository with local vendor changes, run the printed `git rebase --interactive --onto …` command next to complete the replay.


# SEE ALSO

git-filter-repo(1), git-rebase(1), jj(1), [jj-fzf(1)](https://github.com/tim-janik/jj-fzf/blob/trunk/README.md) [Jujutsu](https://jj-vcs.github.io/jj/latest/)
