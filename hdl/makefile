PKGS := $(wildcard model/*_pkg.sv)
SRCS := $(filter-out $(PKGS), $(wildcard model/*.sv))
TBCS := $(wildcard testbench/*_tb.sv)

sim:
	verilator --binary --timing --assert -Wall -Wno-PINCONNECTEMPTY -Wno-UNUSEDSIGNAL -Wno-TIMESCALEMOD -Wno-PROCASSINIT -Wno-SYNCASYNCNET --top gnome_tb $(PKGS) $(SRCS) $(TBCS)