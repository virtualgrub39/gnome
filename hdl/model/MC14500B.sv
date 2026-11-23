module MC14500B
    import gnome_pkg::*;
#()
(
    input logic clk,
    input logic rst,
    input logic en,

    input logic iD,
    output logic oD,

    input gnome_op_t op,

    output gnome_flags_t flags,
    output logic rr
);
    logic skip;
    logic ien;
    logic oen;
    logic eD;

    assign eD = iD & ien;

    assign flags.write = ~skip && (op inside {GNOME_OP_STO, GNOME_OP_STOC}) && oen;
    assign flags.jmp   = ~skip && (op == GNOME_OP_JMP);
    assign flags.rtn   = ~skip && (op == GNOME_OP_RTN);
    assign flags.flg0  = ~skip && (op == GNOME_OP_NOP0);
    assign flags.flgf  = ~skip && (op == GNOME_OP_NOPF);

    assign oD = (op == GNOME_OP_STO) ? rr : ~rr;

    logic next_rr, next_ien, next_oen, next_skip;

    always_comb begin
        next_ien = ien;
        next_oen = oen;
        next_rr = rr;
        next_skip = '0;

        if (!skip) begin
            unique case (op)
            GNOME_OP_LD   : next_rr = eD;
            GNOME_OP_LDC  : next_rr = ~eD;
            GNOME_OP_AND  : next_rr = rr & eD;
            GNOME_OP_ANDC : next_rr = rr & ~eD;
            GNOME_OP_OR   : next_rr = rr | eD;
            GNOME_OP_ORC  : next_rr = rr | ~eD;
            GNOME_OP_XNOR : next_rr = ~(rr ^ eD);
            GNOME_OP_IEN  : next_ien = iD;
            GNOME_OP_OEN  : next_oen = iD;
            GNOME_OP_RTN  : next_skip = '1;
            GNOME_OP_SKZ  : next_skip = ~rr;
            GNOME_OP_STO,
                GNOME_OP_STOC,
                GNOME_OP_JMP,
                GNOME_OP_NOP0,
                GNOME_OP_NOPF :;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            skip <= 0;
            ien <= 0;
            oen <= 0;
            rr <= 0;
        end else if (en) begin
            skip <= next_skip;
            ien <= next_ien;
            oen <= next_oen;
            rr <= next_rr;
        end
    end
endmodule
