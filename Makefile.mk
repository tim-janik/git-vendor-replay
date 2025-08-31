# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

all:
SHELL		:= /usr/bin/env bash -o pipefail
version_full	!= ./version.sh
version_bits    := $(subst _, , $(subst -, , $(subst ., , $(version_full))))
PREFIX		?= /usr/local
BINDIR		?= ${PREFIX}/bin
SHAREDIR	?= $(PREFIX)/share
MANDIR		?= $(SHAREDIR)/man
PKGVERSION      := $(word 1, $(version_bits)).$(word 2, $(version_bits))
LIBEXEC		?= libexec/git-vendor-replay-$(PKGVERSION)
PRJDIR		?= $(PREFIX)/$(LIBEXEC)
CLEANFILES	:= *.tmp
CLEANDIRS	:=
Q		:= $(if $(findstring 1, $(V)),, @)
QGEN		 = @echo '  GEN     ' $@
QSKIP		:= $(if $(findstring s,$(MAKEFLAGS)),: )
QECHO		 = @QECHO() { Q1="$$1"; shift; QR="$$*"; QOUT=$$(printf '  %-8s ' "$$Q1" ; echo "$$QR") && $(QSKIP) echo "$$QOUT"; }; QECHO

# == Compare Versions ==
# Shell command that is true if $1 <= $2 in version comparisons
VERSION_LE := python3 -c 'import sys, re; v1 = list (map (int, sys.argv[1].split ("."))); v2 = list (map (int, re.search (r"\b[0-9]+\.[0-9]+\.[0-9]+", sys.argv[2]).group().split ("."))); sys.exit (v1 > v2)'

# == Check presence of dependencies ==
check-deps: preflight.sh git-vendor-replay
	$(QGEN)
	$Q ./preflight.sh
	$Q ./git-vendor-replay --help >/dev/null || { echo "$@: ERROR: failed to start ./git-vendor-replay as \`bash\` script" >&2; false; }
	$Q ./git-vendor-replay --version >/dev/null || { echo "$@: ERROR: failed to start ./git-vendor-replay as \`bash\` script" >&2; false; }
.PHONY: check-deps
all check: check-deps

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

# == tests ==
tests-basics.sh:
	$Q tests/basics.sh
.PHONY: tests-basics.sh

# == shellcheck ==
shellcheck-warning: git-vendor-replay
	$(QGEN)
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S warning -e SC2178,SC2207,SC2128 git-vendor-replay
shellcheck-error:
	$(QGEN)
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S error git-vendor-replay
check-help:
	$(QGEN)
	$Q ./git-vendor-replay --help | grep -qF git-vendor-replay || { echo "$@: ERROR: failed to render \`./git-vendor-replay --help\`" >&2; false; }
check: check-deps check-help shellcheck-error tests-basics.sh

# == install & uninstall ==
install: all
	$(QGEN)
	mkdir -p $(DESTDIR)$(PRJDIR)/doc $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	install -c version.sh preflight.sh git-vendor-replay $(DESTDIR)$(PRJDIR)
	@ # Note, .gitattributes:export-subst + git archive + tar are used to hardcode version in $(PRJDIR)/version.sh
	test ! -e .gitattributes || git archive HEAD version.sh | tar xC $(DESTDIR)$(PRJDIR)
	install -c doc/git-vendor-replay.1 $(DESTDIR)$(PRJDIR)/doc
	ln -sf ../../../$(LIBEXEC)/doc/git-vendor-replay.1 $(DESTDIR)$(MANDIR)/man1/
	ln -sf ../$(LIBEXEC)/git-vendor-replay $(DESTDIR)$(BINDIR)/git-vendor-replay
installcheck:
	$(QGEN)
	$Q $(DESTDIR)$(BINDIR)/git-vendor-replay --version >/dev/null \
	|| { echo "$@: ERROR: failed to start $(DESTDIR)$(BINDIR)/git-vendor-replay" >&2; false; }
	$Q man $(DESTDIR)$(PRJDIR)/doc/git-vendor-replay.1 | grep -qF git-vendor-replay \
	|| { echo "$@: ERROR: failed to render $(DESTDIR)$(PRJDIR)/doc/git-vendor-replay.1" >&2; false; }
uninstall:
	$(QGEN)
	rm -r -f $(DESTDIR)$(PRJDIR) $(DESTDIR)$(BINDIR)/git-vendor-replay $(DESTDIR)$(MANDIR)/man1/git-vendor-replay.1

# == distcheck ==
distcheck:
	@$(eval distversion != git describe --match='v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//')
	@$(eval distname := git-vendor-replay-$(distversion))
	$(QECHO) MAKE $(distname).tar.zst
	$Q test -n "$(distversion)" || { echo -e "#\n# $@: ERROR: no dist version, is git working?\n#" >&2; false; }
	$Q git describe --dirty | grep -qve -dirty || echo -e "#\n# $@: WARNING: working tree is dirty\n#"
	$Q rm -r -f artifacts/ && mkdir -p artifacts/
	$Q # Generate ChangeLog with ^^-prefixed records. Tab-indent commit bodies, kill whitespaces and multi-newlines
	$Q git log --abbrev=13 --date=short --first-parent HEAD	\
		--pretty='^^%ad  %an 	# %h%n%n%B%n'		>  artifacts/ChangeLog \
	&& sed 's/^/	/; s/^	^^// ; s/[[:space:]]\+$$// '	-i artifacts/ChangeLog \
	&& sed '/^\s*$$/{ N; /^\s*\n\s*$$/D }'			-i artifacts/ChangeLog
	$Q # Generate and compress artifacts/git-vendor-replay-*.tar.zst
	$Q git archive --prefix=$(distname)/ --add-file artifacts/ChangeLog -o artifacts/$(distname).tar HEAD
	$Q rm -f artifacts/$(distname).tar.zst && zstd --ultra -22 --rm artifacts/$(distname).tar && ls -lh artifacts/$(distname).tar.zst
	$Q T=`mktemp -d` && cd $$T && tar xf $(abspath artifacts/$(distname).tar.zst) \
	&& cd git-vendor-replay-$(distversion) \
	&& nice make all -j`nproc` \
	&& make PREFIX=$$T/inst install \
	&& make PREFIX=$$T/inst installcheck -j`nproc` \
	&& (set -x && $$T/inst/bin/git-vendor-replay --version) \
	&& make PREFIX=$$T/inst uninstall \
	&& (set -x && $$PWD/git-vendor-replay --version) \
	&& cd / && rm -r "$$T"
	$Q echo "Archive ready: artifacts/$(distname).tar.zst" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'
CLEANDIRS += artifacts

# == artifacts/git-vendor-replay.sfx ==
artifacts/git-vendor-replay.sfx: all
	$(QGEN)
	$Q rm -rf xinst/
	$Q $(MAKE) install DESTDIR=xinst/
	$Q cd xinst/ && $(abspath sfx.sh) --sfxsh-pack /usr/local/bin/git-vendor-replay $(abspath $@) *
	$Q rm -rf xinst/
	$Q echo "SFX archive ready: $@" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'

# == clean ==
clean:
	rm -f $(CLEANFILES)
	rm -f -r $(CLEANDIRS)
.PHONY: clean

