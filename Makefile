#
# Copyright (C) 2011 Chris McClelland
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
ROOT    := $(realpath ../..)
DEPS    := fpgalink error argtable2
TYPE    := exe
SUBDIRS := tests vhdl m68k hackdump
PRE_BUILD := gen_mon
EXTRA_CC_SRCS := gen_mon/monitor.c
EXTRA_CLEAN := gen_mon
LINK_EXTRALIBS_REL := m68k.o
LINK_EXTRALIBS_DBG := $(LINK_EXTRALIBS_REL)

-include $(ROOT)/common/top.mk

MKMON := mkmon/$(PM)/rel/mkmon$(EXE)

gen_mon: FORCE
	make -C mkmon rel
	mkdir -p $@
	make -C m68k/monitor
	$(MKMON) m68k/monitor/monitor.bin monitor > $@/monitor.c
	make -C mkmon clean
