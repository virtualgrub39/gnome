package gnome_pkg;
    typedef enum logic [3:0] {
        GNOME_OP_NOP0 = 4'b0000,
        GNOME_OP_LD   = 4'b0001,
        GNOME_OP_LDC  = 4'b0010,
        GNOME_OP_AND  = 4'b0011,
        GNOME_OP_ANDC = 4'b0100,
        GNOME_OP_OR   = 4'b0101,
        GNOME_OP_ORC  = 4'b0110,
        GNOME_OP_XNOR = 4'b0111,
        GNOME_OP_STO  = 4'b1000,
        GNOME_OP_STOC = 4'b1001,
        GNOME_OP_IEN  = 4'b1010,
        GNOME_OP_OEN  = 4'b1011,
        GNOME_OP_JMP  = 4'b1100,
        GNOME_OP_RTN  = 4'b1101,
        GNOME_OP_SKZ  = 4'b1110,
        GNOME_OP_NOPF = 4'b1111
    } gnome_op_t;

    typedef struct packed {
        logic flgf;
        logic flg0;
        logic rtn;
        logic jmp;
        logic write;
    } gnome_flags_t;

    typedef enum logic [1:0] {
        BANK_SWCH = 2'b00,
        BANK_SCRM = 2'b01,
        BANK_CNST = 2'b10,
        BANK_EXPN = 2'b11
    } bank_t;
endpackage
