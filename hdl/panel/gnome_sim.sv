module gnome_sim
    import gnome_pkg::*;
(
    input   logic           osc, rst,
    input   logic   [9:0]   switches,
    input   logic           manual, prog, advance, deposit,
    output  wire    [9:0]   instruction,
    output  wire    [5:0]   pc,
    output  logic   [15:0]  expn_regs,
    output  wire    [31:0]  op_name, bank_name
);

    wire [3:0] bank_addr;
    wire expn_we, expn_rd;
    tri expn_D;

    gnome dut (.*);

    initial expn_regs = '0;
    assign expn_D = expn_rd ? expn_regs[bank_addr] : 1'bz;
    always @(posedge osc) if (expn_we) expn_regs[bank_addr] <= expn_D;

    

    function automatic logic [31:0] mnem (gnome_op_t op);
        case (op)
            GNOME_OP_NOP0: return "NOP0";
            GNOME_OP_LD:   return "LD  ";
            GNOME_OP_LDC:  return "LDC ";
            GNOME_OP_AND:  return "AND ";
            GNOME_OP_ANDC: return "ANDC";
            GNOME_OP_OR:   return "OR  ";
            GNOME_OP_ORC:  return "ORC ";
            GNOME_OP_XNOR: return "XNOR";
            GNOME_OP_STO:  return "STO ";
            GNOME_OP_STOC: return "STOC";
            GNOME_OP_IEN:  return "IEN ";
            GNOME_OP_OEN:  return "OEN ";
            GNOME_OP_JMP:  return "JMP ";
            GNOME_OP_RTN:  return "RTN ";
            GNOME_OP_SKZ:  return "SKZ ";
            GNOME_OP_NOPF: return "NOPF";
            default:       return "??? ";
        endcase
    endfunction

    function automatic logic [31:0] bname (bank_t b);
        case (b)
            BANK_CNST: return "CNST";
            BANK_SWCH: return "SWCH";
            BANK_EXPN: return "EXPN";
            BANK_SCRM: return "SCRM";
            default:   return "????";
        endcase
    endfunction

    assign op_name   = mnem(gnome_op_t'(instruction[9:6]));
    assign bank_name = bname(bank_t'(instruction[5:4]));
endmodule
