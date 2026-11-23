module gnome
    import gnome_pkg::*;
#()
(
    input logic osc,
    input logic rst,

    // front panel
    input logic [9:0] switches, // toggle
    input logic manual,         // toggle
    input logic prog,           // toggle
    input logic advance,        // push
    input logic deposit,        // push

    output logic [9:0] instruction,

    // expansion
    output logic [3:0] bank_addr,
    output logic expn_we,
    output logic expn_rd,
    inout tri expn_D
);
    // edge detection
    logic adv_sync, adv_prev, adv_pulse;
    logic dep_sync, dep_prev, dep_pulse;

    always_ff @(posedge osc or negedge rst) begin
        if (!rst) begin
            adv_sync <= 1'b0;
            adv_prev <= 1'b0;
            dep_sync <= 1'b0;
            dep_prev <= 1'b0;
        end else begin
            adv_sync <= advance;
            adv_prev <= adv_sync;

            dep_sync <= deposit;
            dep_prev <= dep_sync;
        end
    end

    assign adv_pulse = adv_sync && !adv_prev;
    assign dep_pulse = dep_sync && !dep_prev;

    logic cpu_en;
    logic pc_en;
    logic pc_ld;
    logic prog_we;

    // mode control
    always_comb begin
        if (prog) begin
            cpu_en  = 1'b0;
            pc_en   = adv_pulse;
            pc_ld   = 1'b0;
            prog_we = dep_pulse;
        end else if (manual) begin
            cpu_en  = adv_pulse;
            pc_en   = adv_pulse;
            pc_ld   = flags.jmp;
            prog_we = 1'b0;
        end else begin
            cpu_en  = 1'b1;
            pc_en   = 1'b1;
            pc_ld   = flags.jmp;
            prog_we = 1'b0;
        end
    end

    // instruction decoding & data bus multiplexing
    logic [5:0] pc;
    logic [5:0] operand;
    gnome_op_t opcode;
    gnome_flags_t flags;
    bank_t addrbank;

    assign opcode    = gnome_op_t'(instruction[9:6]);
    assign operand   = instruction[5:0];
    assign addrbank  = bank_t'(operand[5:4]);
    assign bank_addr = operand[3:0];

    logic swch_D; // control unit
    logic ctlu_D; // switches
    logic scrm_D; // scratch memory
    logic cnst_D; // constants: TODO: a constants module
    // logic expn_D; // expansion slot
    logic peripheral_D;

    logic D;

    assign swch_D = (bank_addr < 4'd10) ? switches[bank_addr] : 1'b0;
    assign cnst_D = 1'b0; // Placeholder for constants bank

    always_comb begin
        unique case (addrbank)
            BANK_SWCH: peripheral_D = swch_D;
            BANK_CNST: peripheral_D = cnst_D;
            BANK_EXPN: peripheral_D = expn_D;
            BANK_SCRM: peripheral_D = scrm_D;
        endcase
    end

    assign D = flags.write ? ctlu_D : peripheral_D;
    
    logic scrm_we;
    assign scrm_we = cpu_en && flags.write && (addrbank == BANK_SCRM);
    assign expn_we = cpu_en && flags.write && (addrbank == BANK_EXPN);
    assign expn_rd = !flags.write && (addrbank == BANK_EXPN);

    assign expn_D  = expn_we ? ctlu_D : 'z;

    counter #( .BITS(6) ) progcounter (
        .ld     (pc_ld),
        .iD     (operand),
        .oD     (pc),
        .clk    (osc),
        .rst    (rst),
        .en     (pc_en)
    );

    ram #(.WORD(10), .SIZE(64)) progmem (
        .iD     (switches),
        .oD     (instruction),
        .addr   (pc),
        .we     (prog_we),
        .clk    (osc)
    );

    ram #(.WORD(1), .SIZE(16)) scratch (
        .iD     (D),
        .oD     (scrm_D),
        .addr   (bank_addr),
        .we     (scrm_we),
        .clk    (osc)
    );

    MC14500B control_unit (
        .clk    (osc),
        .rst    (rst),
        .en     (cpu_en),
        .iD     (D),
        .oD     (ctlu_D),
        .op     (opcode),
        .flags  (flags),
        .rr     ()
    );

endmodule
