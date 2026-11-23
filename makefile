PKGS := $(wildcard hdl/*_pkg.sv)
SRCS := $(filter-out $(PKGS), $(wildcard hdl/*.sv))

sim:
	verilator --binary -Wall -Wno-PINCONNECTEMPTY -Wno-UNUSEDSIGNAL $(PKGS) $(SRCS)