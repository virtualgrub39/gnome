module counter
#(
    parameter int BITS = 6
)
(
    input logic clk,
    input logic rst,
    input logic ld,
    input logic en,
    input logic [BITS-1:0] iD,
    output logic [BITS-1:0] oD
);
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) oD <= 0;
        else if (en) begin
            if (ld) oD <= iD;
            else    oD <= oD + BITS'(1);
        end
    end
endmodule
