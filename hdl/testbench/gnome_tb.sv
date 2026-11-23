`timescale 100ns/100ps

module gnome_tb;
    import gnome_pkg::*;

    logic osc = 0, rst = 0;
    logic [9:0] switches = '0;
    logic manual = 0, prog = 0, advance = 0, deposit = 0;
    wire [9:0] instruction;
    wire [3:0] bank_addr;
    wire expn_we, expn_rd;
    tri expn_D;

    gnome dut (.*);

    // expansion "peripheral"
    logic [15:0] expn_regs = '0;
    assign expn_D = expn_rd ? expn_regs[bank_addr] : 1'bz;
    always @(posedge osc) if (expn_we) expn_regs[bank_addr] <= expn_D;

    always #5 osc = ~osc; // 2 MHz

    task automatic tick (int n = 1); repeat(n) @(negedge osc); endtask

    task automatic do_reset ();
        rst = 0; tick(2); rst = 1; tick(2);
    endtask

    task automatic push_advance (int len = 3);
        advance = 1; tick(len); advance = 0; tick(4);
    endtask

    task automatic push_deposit (int len = 3);
        deposit = 1; tick(len); deposit = 0; tick(4);
    endtask

    function automatic logic [9:0] ins (gnome_op_t op, bank_t b, logic [3:0] a);
        return {op, b, a};
    endfunction

    task automatic load_program (logic [9:0] words[]);
        prog = 1;
        foreach (words[i]) begin
            switches = words[i];
            push_deposit();
            push_advance();
        end
        prog = 0;
        do_reset();
    endtask

    int errors = 0;
    task automatic check (bit cond, string msg);
        if (!cond) begin $error("GNOME ERROR: %s", msg); errors += 1; end
    endtask

    int cpu_cycles = 0;
    always @(posedge osc) if (dut.cpu_en) cpu_cycles <= cpu_cycles + 1;
    // always @(posedge osc) if (rst)
    // $display("%0t pc=%0d ins=%b cpu_en=%b write=%b D=%b ctlu_D=%b we=%b expn_D=%b regs0=%b",
    //         $time, dut.pc, instruction, dut.cpu_en, dut.flags.write,
    //         dut.D, dut.ctlu_D, expn_we, expn_D, expn_regs[0]);

    task automatic test_long_press_advance();
        do_reset();
        manual = 1;
        tick();
        cpu_cycles = 0;
        push_advance(20);
        check(cpu_cycles == 1, $sformatf("expected 1 step, got %0d", cpu_cycles));
        manual = 0;
    endtask

    task automatic test_switch_to_expansion();
        for (int v = 0; v < 2; v++) begin
            do_reset();
            load_program('{ ins(GNOME_OP_IEN, BANK_CNST, 1),
                            ins(GNOME_OP_OEN, BANK_CNST, 1),
                            ins(GNOME_OP_LD,  BANK_SWCH, 3),
                            ins(GNOME_OP_STO, BANK_EXPN, 0) });
            expn_regs[0] = !v[0];
            switches[3]  = v[0];
            tick(10);
            check(expn_regs[0] === v[0], $sformatf("switch 3=%0d not seen on expn[0]", v));
        end
    endtask

    initial begin
        do_reset();
        test_long_press_advance();
        test_switch_to_expansion();

        if (errors != 0) $fatal(1, "FAILED: %0d errors", errors);
        $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin #1ms; $fatal(1, "timeout"); end 
endmodule
