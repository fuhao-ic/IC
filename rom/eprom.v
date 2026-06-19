module eprom(
    input wire [ADDR_WIDTH-1: 0] addr,
    input wire                   ce_n,
    input wire                   oe_n,
    output wire [DATA_WIDTH-1:0] data 
);

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 13; // 8K
    parameter DEPTH = 1 << ADDR_WIDTH;


    reg [DATA_WIDTH-1:0] rom [0:DEPTH-1];


    // 初始化rom内容
    integer i;
    initial begin
        for(i = 0; i < DEPTH; i = i + 1) begin
            rom[i] = i[7:0];
        end
    end


    assign data = (~ce_n && ~oe_n) ? rom[addr] : {DATA_WIDTH{1'bz}};


endmodule