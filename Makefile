# makefile for lite2do, a lightweight text-based todo manager
# Copyright (C) 2008, 2009 Jaromir Hradilek

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
# 
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
# 
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

# General settings; feel free to modify according to your situation:
SHELL   = /bin/sh
INSTALL = /usr/bin/install -c
POD2MAN = /usr/bin/pod2man
SRCS   := $(wildcard *.pl)
MAN1   := $(patsubst %.pl, %.1, $(SRCS))

# Installation directories; feel free to modify according to your taste and
# current situation:
prefix  = /usr/local
bindir	= $(prefix)/bin
mandir  = $(prefix)/share/man
man1dir = $(mandir)/man1

# Make rules;  please do not edit these unless you really know what you are
# doing:
.PHONY: all clean install uninstall

all: $(MAN1)

clean:
	-rm -f $(MAN1)

install: $(MAN1)
	@echo "Copying scripts..."
	$(INSTALL) -d $(bindir)
	$(INSTALL) -m 755 lite2do.pl $(bindir)/lite2do
	@echo "Copying manual pages..."
	$(INSTALL) -d $(man1dir)
	$(INSTALL) -m 644 lite2do.1 $(man1dir)

uninstall:
	@echo "Removing scripts..."
	rm -f $(bindir)/lite2do
	@echo "Removing manual pages..."
	rm -f $(man1dir)/lite2do.1
	@echo "Removing empty directories..."
	-rmdir $(bindir) $(man1dir) $(mandir)

%.1: %.pl
	$(POD2MAN) --section=1 $^ $@

