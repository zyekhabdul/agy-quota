PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: all install uninstall test

all:
	@echo "agy-quota is a Python CLI utility. Run 'make install' to install to $(BINDIR)."

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 bin/agy-quota $(DESTDIR)$(BINDIR)/agy-quota
	ln -sf $(DESTDIR)$(BINDIR)/agy-quota $(DESTDIR)$(BINDIR)/agy-tokens
	@echo "Installed agy-quota and agy-tokens to $(DESTDIR)$(BINDIR)/"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/agy-quota $(DESTDIR)$(BINDIR)/agy-tokens
	@echo "Removed agy-quota from $(DESTDIR)$(BINDIR)/"

test:
	python3 -m py_compile bin/agy-quota
	./bin/agy-quota --help
