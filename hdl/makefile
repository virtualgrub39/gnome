PKGS := $(wildcard model/*_pkg.sv)
SRCS := $(filter-out $(PKGS), $(wildcard model/*.sv))
TBCS := $(wildcard testbench/*_tb.sv)

WARN := -Wall -Wno-PINCONNECTEMPTY -Wno-UNUSEDSIGNAL -Wno-TIMESCALEMOD -Wno-PROCASSINIT -Wno-SYNCASYNCNET

sim:
	verilator --binary --timing -j 0 --assert $(WARN) --top gnome_tb $(PKGS) $(SRCS) $(TBCS)

obj_panel/Vgnome_sim: $(PKGS) $(SRCS) panel/gnome_sim.sv panel/main.cpp
	verilator --cc --exe --build -j 0 $(WARN) --Mdir obj_panel --top-module gnome_sim \
	    $(PKGS) $(SRCS) panel/gnome_sim.sv panel/main.cpp \
	    -LDFLAGS -lncurses

panel: obj_panel/Vgnome_sim

all: sim panel

.PHONY: all
