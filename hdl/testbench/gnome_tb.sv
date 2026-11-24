`timescale 100ns/100ps

module gnome_tb;
    import gnome_pkg::*;

    logic osc = 0, rst = 0;
    logic [9:0] switches = '0;
    logic manual = 0, prog = 0, advance = 0, deposit = 0;
    wire [9:0] instruction;
    wire [5:0] pc;
    wire [3:0] bank_addr;
    wire expn_we, expn_rd;
    tri expn_D;

    gnome dut (.*);

    // expansion "peripheral"
    logic [15:0] expn_regs = '0;
    assign expn_D = expn_rd ? expn_regs[bank_addr] : 1'bz;
    always @(posedge osc) if (expn_we) expn_regs[bank_addr] <= expn_D;

    int wr_cnt [16];
    always @(posedge osc) if (expn_we) wr_cnt[bank_addr] <= wr_cnt[bank_addr]+1;

    always #5 osc = ~osc; // 1 MHz

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

    task automatic load_program(logic [9:0] words[]);
        prog = 1; do_reset();
        for (int i = 0; i < 64; i++) begin
            switches = (i < words.size()) ? words[i] : 10'b0;
            push_deposit(); 
            push_advance();
        end
        prog = 0; rst = 0; tick(2);
    endtask

    function automatic logic [9:0] jmp(logic [5:0] target);
        return {GNOME_OP_JMP, target};
    endfunction

    function automatic logic [9:0] op0(gnome_op_t op);   // SKZ, RTN, NOP: operand unused
        return ins(op, BANK_CNST, 0);
    endfunction

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
        load_program('{ ins(GNOME_OP_IEN, BANK_CNST, 1),
                        ins(GNOME_OP_OEN, BANK_CNST, 1),
                        ins(GNOME_OP_LD,  BANK_SWCH, 3),
                        ins(GNOME_OP_STO, BANK_EXPN, 0) });
        for (int v = 0; v < 2; v++) begin
            rst = 0; tick(2);
            switches     = 10'b0;
            switches[3]  = v[0];
            expn_regs[0] = !v[0];
            rst = 1; tick(10);
            check(expn_regs[0] === v[0], $sformatf("switch 3=%0d not seen on expn[0]", v));
        end
    endtask

    task automatic test_switch_arithmetic();
        logic [3:0] sw;
        logic       expected;

        do_reset();
        // expn[0] = ~(SW[0] & SW[1] | SW[2] | SW[3])
        load_program('{ ins(GNOME_OP_IEN, BANK_CNST, 1),
                        ins(GNOME_OP_LD, BANK_SWCH, 0),
                        ins(GNOME_OP_AND, BANK_SWCH, 1),
                        ins(GNOME_OP_OR, BANK_SWCH, 2),
                        ins(GNOME_OP_OR, BANK_SWCH, 3),
                        ins(GNOME_OP_OEN, BANK_CNST, 1),
                        ins(GNOME_OP_STOC, BANK_EXPN, 0),
                        {GNOME_OP_JMP, 6'b0} 
                        });
        
        for (int v = 0; v < 16; v++) begin
            sw       = v[3:0];
            expected = ~((sw[0] & sw[1]) | sw[2] | sw[3]);   // reference model

            rst = 0; tick(2);                 // hold in reset: PC = 0, RR cleared
            switches     = {6'b0, sw};        // set inputs while the CPU is stopped
            expn_regs[0] = ~expected;         // poison: a stale value must not pass
            rst = 1; tick(10);                // run the program (7 instrs + margin)

            check(expn_regs[0] === expected,
                $sformatf("sw=%04b: expected %0b, got %0b", sw, expected, expn_regs[0]));
        end
    endtask

    task automatic test_jmp_forward();
        load_program('{ ins(GNOME_OP_IEN, BANK_CNST, 1),    // 0
                        ins(GNOME_OP_OEN, BANK_CNST, 1),    // 1
                        ins(GNOME_OP_LD,  BANK_CNST, 1),    // 2  RR=1
                        ins(GNOME_OP_STO, BANK_EXPN, 0),    // 3  runs
                        jmp(7),                             // 4
                        ins(GNOME_OP_STO, BANK_EXPN, 1),    // 5  must be skipped
                        ins(GNOME_OP_STO, BANK_EXPN, 2),    // 6  must be skipped
                        ins(GNOME_OP_STO, BANK_EXPN, 3) }); // 7  runs
        rst = 0; tick(2);
        expn_regs = '0;
        rst = 1; tick(20);                                  // < 64 cycles, so no PC wrap
        check(expn_regs[3:0] === 4'b1001,
            $sformatf("jmp_forward: expn=%04b, expected 1001", expn_regs[3:0]));
    endtask

    task automatic test_skz_conditional_jmp();
        load_program('{ ins(GNOME_OP_IEN, BANK_CNST, 1),    // 0
                        ins(GNOME_OP_OEN, BANK_CNST, 1),    // 1
                        ins(GNOME_OP_LD,  BANK_SWCH, 0),    // 2  RR = sw[0]
                        op0(GNOME_OP_SKZ),                  // 3  RR==0 -> skip next
                        jmp(7),                             // 4  taken only if sw[0]==1
                        ins(GNOME_OP_LD,  BANK_CNST, 1),    // 5  fall-through path
                        ins(GNOME_OP_STO, BANK_EXPN, 0),    // 6  marker "fell through"
                        ins(GNOME_OP_LD,  BANK_CNST, 1),    // 7
                        ins(GNOME_OP_STO, BANK_EXPN, 1) }); // 8  marker "reached end"
        for (int s = 0; s < 2; s++) begin
            rst = 0; tick(2);
            switches = 10'(s);
            expn_regs = '0;
            rst = 1; tick(20);
            check(expn_regs[1:0] === {1'b1, ~s[0]},
                $sformatf("skz/jmp sw0=%0d: expn=%02b", s, expn_regs[1:0]));
        end
    endtask

    initial begin
        do_reset();
        test_long_press_advance();
        test_switch_to_expansion();
        test_switch_arithmetic();
        test_jmp_forward();
        test_skz_conditional_jmp();

        if (errors != 0) $fatal(1, "FAILED: %0d errors", errors);
        $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin repeat (1_000_000) @(posedge osc); $fatal(1, "timeout"); end
endmodule
