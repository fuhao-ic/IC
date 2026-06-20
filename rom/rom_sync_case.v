module rom_sync_case(
    input wire clk,
    input wire rst_n,
    input wire [3:0] addr,
    output reg [7:0] data
);


    // 使用 case 语句（适合小容量、控制逻辑型ROM）
    always @(posedge clk or negedge rst_n) begin
        if(~reset_n) begin
            data <=8'h0;
        end
        else begin
            case (addr)
                4'h0: data = 8'h0A;
                4'h1: data = 8'h1B;
                4'h2: data = 8'h2C;
                4'h3: data = 8'h3D;
                4'h4: data = 8'h4E;
                4'h5: data = 8'h5F;
                4'h6: data = 8'h6A;
                4'h7: data = 8'h7B;
                4'h8: data = 8'h8C;
                4'h9: data = 8'h9D;
                4'hA: data = 8'hAE;
                4'hB: data = 8'hBF;
                4'hC: data = 8'hC0;
                4'hD: data = 8'hD1;
                4'hE: data = 8'hE2;
                4'hF: data = 8'hF3;
                default: data <= 8'h00; 
            endcase
        end
    end

endmodule