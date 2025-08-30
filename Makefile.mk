# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

all:

# == doc/git-vendor-replay.1 ==
doc/git-vendor-replay.1: doc/git-vendor-replay.1.md git-vendor-replay Makefile.mk
	$(QGEN)
	$Q pandoc $(man/markdown-flavour) -s -p \
		-M date="$(word 2, $(version_full))" \
		-M footer="git-vendor-replay-$(word 1, $(version_full))" \
		-t man $< -o $@.tmp
	$Q rm -f doc/git-vendor-replay.1.tmp.md && mv $@.tmp $@
man/markdown-flavour	:= -f markdown+hard_line_breaks+autolink_bare_uris+emoji+lists_without_preceding_blankline-smart
CLEANFILES += doc/git-vendor-replay.1 doc/*.tmp*
all: doc/git-vendor-replay.1
