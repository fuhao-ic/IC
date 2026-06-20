module rom_sync_array(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  addr,  // 256个地址
    output reg  [31:0] data
);


    // 适合大容量、数据来自文件

    reg [31:0] rom_mem [0:255];

    initial begin
        $readmemh("rom_data.hex", rom_mem);
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n) begin
            data <= 8'h0;
        end
        else begin
            data <= rom_mem[addr];
        end
    end


endmodule