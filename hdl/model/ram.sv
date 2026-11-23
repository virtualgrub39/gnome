module ram #(
    parameter WORD = 10,
    parameter SIZE = 64
)
(
    input logic clk,
    input logic we,
    input logic [$clog2(SIZE)-1:0] addr,
    input logic [WORD-1:0] iD,
    output logic [WORD-1:0] oD
);
    logic [WORD-1:0] mem [SIZE];

    always_ff @(posedge clk) begin
        if (we) begin mem[addr] <= iD; end
    end

    assign oD = mem[addr];
endmodule
