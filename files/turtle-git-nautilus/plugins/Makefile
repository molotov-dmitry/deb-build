TARGET			:= turtle_nautilus.py turtle_nautilus_compare.py
INSTALL_DIR 	:= $(PREFIX)/usr/share/nautilus-python/extensions

#### Automatically generated variables -----------------------------------------

INSTALL_TARGET	:= $(patsubst %,$(INSTALL_DIR)/%,$(TARGET))

#### Makefile configuration ====================================================

.SUFFIXES:

.PHONY: all clean FORCE install uninstall

#### ===========================================================================

all:

#### Installation --------------------------------------------------------------

$(INSTALL_DIR):
	mkdir -p $@

$(INSTALL_DIR)/%: % | $(INSTALL_DIR)
	install $< $@

install: $(INSTALL_TARGET)

uninstall:
	rm -f $(INSTALL_TARGET)
	rmdir $(INSTALL_DIR) || true

