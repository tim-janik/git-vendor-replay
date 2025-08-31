# git-vendor-replay

Maintain vendored code kept under a directory in a Git repo.
This tool creates a *pristine import* commit from an external source tree and then prepares (and, with Jujutsu, performs) a replay of your local changes to that vendor directory on top of the new import.


## What it does

Running `git-vendor-replay` will carry out the following steps:

- Locates the last import by scanning the Git history for a commit message line with exactly `Vendor-dir: <vendor-dir>`.
- Extracts commits that touched `<vendor-dir>` since that last import (using `git filter-repo`) and flattens them in chronological order.
- Creates a new commit that replaces `<vendor-dir>` with the contents of `<import-src>`. The commit contains a new `Vendor-dir: <vendor-dir>` line.
- In a colocated `jj` repository it prints a ready-to-run `jj rebase …` command, or a `git rebase --onto …` command otherwise.
- Use `--rebase` to execute the rebase command directly, or `-i` to start an interactive rebase.
- Updates (or creates) a dedicated branch that tracks the linearized vendor history.

The current repository’s `HEAD` and working tree are **not** modified; all assembly happens in a separately fetched branch.

### Intent

The primary goal is to revisit every **downstream patch** after each new import, so you can drop fixes that upstream absorbed, rework temporary hacks, or rebase minimal deltas cleanly.
The replay step makes this review explicit on every update.

When (not) to use: `git-vendor-replay` deliberately creates **independent import commits**, it does **not** "connect" import ancestry,
i.e. it does not make the previous import the parent of the new import.
This keeps imports orthogonal and focuses the workflow on replaying and reevaluating downstream changes.

If you prefer connected upstream history and are happy to **merge** new imports (especially when vendoring an entire Git repository), `git subtree` may be a better fit,
because `git subtree` preserves upstream history under a prefix and supports merging upstream changes directly, instead of replaying local patches.


## Requirements

- Git
- [`git-filter-repo`](https://github.com/newren/git-filter-repo) in `PATH`
- Optional: Jujutsu (`jj`) for automatic replay in a colocated repository
- Must run from the repository root


## Usage

See `man git-vendor-replay` for detailed option documentation.

```bash
git-vendor-replay [OPTIONS] [--rebase | -i] <vendor-dir> <import-src>

# Example: Import upstream 2.4.1 into third_party/libfoo and prepare replay
git-vendor-replay third_party/libfoo ../libfoo-2.4.1 -t v2.4.1 -b libfoo
```


## Notes

* The vendor branch intentionally holds only the vendor-directory lineage and may be force-updated.
* Conflicts during the replay are resolved by you (via `git rebase`) or marked in `jj` as usual.
* If the new import is identical to the last one, the script aborts with a clear error to avoid making a no-op commit.


## Install

Run `make install`, optionally with `PREFIX=…`.
If a single script without the manual page is sufficient, download the self-extracting shell archive from the release assets.


## Related Projects

* [Vendor Branches explained](https://david.rothlis.net/vendor-branch/) - Background on the traditional "vendor branch" pattern in Git.
* [git-vendor (thejoshwolfe)](https://github.com/thejoshwolfe/git-vendor) - Vendor tool for integrating external content with file filtering and config versioning.
* [git-vendor (brettlangdon)](https://github.com/brettlangdon/git-vendor) - An opinionated approach to tracking vendored dependencies.
* [git-filter-repo](https://github.com/newren/git-filter-repo) - Fast, flexible history rewriting tool used internally by this script.

This comparison table about git-vendor-vs-other-options by [@thejoshwolfe](https://github.com/thejoshwolfe/) is particularly helpful:

https://github.com/thejoshwolfe/git-vendor?tab=readme-ov-file#git-vendor-vs-other-options

This tool `git-vendor-replay` aids the process described in the "manual copy" column:


| | `git subtree` | [git-vendor-replay (tim-janik)](https://github.com/tim-janik/git-vendor-replay) | manual copy |
| --------- | ------ | ------ | --- |
| just works for collaborators	 | ✔️  | ✔️  | ✔️  |
| version-controlled config file | ❌ | ❌ | ❌ |
| push as maintainer             | ✔️  | ❌ | ❌ |
| fully a git repo               | ❌ | ❌ | ❌ |
| file name based filtering      | ❌ | ✔️  | ✔️  |
| non-trivial patches            | ❌ | ✔️  | ✔️  |
| automatic downstream replay    | ❌ | ✔️  | ❌ |
| implementation                 | builtin | bash | manual |
| stars on github                | celebrity | aspiring | |
