/*
spc:    
    输入时钟：100MHz，数据连续到达
    输出时钟：50MHz，后端处理较慢
    缓冲区深度：4（便于演示）
    数据位宽：8-bit
    核心机制：写满一个缓冲区后，通过握手信号通知读侧切换
*/


// bug：读数据时，数据已经被破坏了

module ping_pong_dual_clk(
    // 输入端（fast-speed）
    input wire clk_in,
    input wire rst_n,
    input wire wr_en,
    input wire [7:0] din,
    output wire full,

    // 输出端（low-speed）
    input wire clk_out,
    input wire rd_en,
    output wire [7:0] dout,
    output wire valid
);


    // ==================== 参数定义 ====================
    localparam  BUFFER_DEPTH = 4;
    localparam  ADDR_WIDTH   = 2;
    localparam  NUM_BUFFERS  = 2;   // Ping/Pong

    // ==================== 写侧信号 ====================
    reg [7:0]   ping_ram [0:BUFFER_DEPTH-1];
    reg [7:0]   pong_ram [0:BUFFER_DEPTH-1];

    reg [ADDR_WIDTH-1:0]   wr_addr;
    reg                    wr_sel;        // 0: Ping, 1: Pong
    reg                    wr_buf_full;   // 当前写入缓冲区已满

    // 状态机：写侧状态
    reg [3:0]   wr_state;
    localparam  WR_IDLE       = 2'b00,
                WR_FILL_PING  = 2'b01,
                WR_FILL_PONG  = 2'b10,
                WR_RUN_PING   = 2'b11,
                WR_RUN_PONG   = 3'b100;

    // ==================== 读侧信号 ====================
    reg [ADDR_WIDTH-1:0]   rd_addr;
    reg                    rd_sel;        // 0: Ping, 1: Pong
    reg                    rd_valid;      // 内部有效信号

    // 读侧状态机
    reg [1:0]   rd_state;
    localparam  RD_IDLE     = 2'b00,
                RD_READ_PING= 2'b01,
                RD_READ_PONG= 2'b10;


    // ==================== 跨时钟域同步信号 ====================
    reg         wr_sel_sync;      // 写选择同步到读时钟域
    reg         wr_sel_sync_ff1;
    reg         wr_buf_full_sync;
    reg         wr_buf_full_sync_ff1;
    
    reg         rd_done;          // 读完成标志（读侧到写侧）
    reg         rd_done_sync;
    reg         rd_done_sync_ff1;         


    // 一段式状态机
    always @(posedge clk_in or negedge rst_n) begin
        if(!rst_n) begin
            wr_state <= WR_FILL_PING;
            wr_sel <= 1'b0;
            wr_addr <= 0;
            wr_buf_full <= 1'b0;
        end
        else begin
            case (wr_state)
                WR_FILL_PING: begin
                    if(wr_en) begin
                        wr_addr <= wr_addr + 1'b1;
                        if(wr_addr == BUFFER_DEPTH-1) begin
                            wr_state <= WR_FILL_PONG;
                            wr_sel <= 1'b1;
                            wr_addr <= 0;
                            wr_buf_full <= 1'b1;
                        end
                    end
                end

                WR_FILL_PONG: begin
                    wr_addr <= wr_addr + 1'b1;
                    if(wr_addr == BUFFER_DEPTH-1) begin
                        wr_state <= WR_RUN_PING;
                        wr_sel <= 1'b0;
                        wr_addr <= 1'b0;
                    end
                end

                WR_RUN_PING: begin
                    if(wr_en) begin
                        wr_addr <= wr_addr + 1'b1;
                        if(wr_addr == BUFFER_DEPTH-1) begin
                            if(rd_done_sync) begin
                                wr_state <= WR_RUN_PONG;
                                wr_sel <= 1'b1;
                                wr_addr <= 0;
                                wr_buf_full <= 1'b1;
                            end
                            else begin
                                wr_buf_full <= 1'b1;
                            end
                        end
                        else begin
                            wr_buf_full <= 1'b0;
                        end
                    end
                end

                WR_RUN_PONG: begin
                    if(wr_en) begin
                        wr_addr <= wr_addr + 1'b1;
                        if(wr_addr == BUFFER_DEPTH-1) begin
                            if(rd_done_sync) begin
                                wr_state <= WR_RUN_PING;
                                wr_sel <= 1'b0;
                                wr_addr <= 0;
                                wr_buf_full <= 1'b1;
                            end
                            else begin
                                wr_buf_full <= 1'b1;
                            end
                        end
                        else begin
                            wr_buf_full <= 1'b0;
                        end
                    end
                end

                default: wr_state <= WR_FILL_PING;
            endcase
        end
    end           


    // 写数据逻辑
    always @(posedge clk_in) begin
        if(wr_en && !full) begin
            case (wr_sel)
                1'b0: ping_ram[wr_addr] <= din; 
                1'b1: pong_ram[wr_addr] <= din;
            endcase
        end
    end

    // full flag;
    assign full = (wr_state == WR_FILL_PING && wr_buf_full) || 
                  (wr_state == WR_FILL_PONG) ||
                  (wr_state == WR_RUN_PING && wr_buf_full) ||
                  (wr_state == WR_RUN_PONG && wr_buf_full);

    



    // ============================================================
    // 读侧逻辑 (clk_out 域)
    // ============================================================
    always @(posedge clk_out or negedge rst_n) begin
        if(!rst_n) begin
            rd_state <= RD_DILE;
            rd_sel <= 1'b0;
            rd_addr <= 0;
            rd_valid <= 1'b0;
        end
        else begin
            case (rd_state)
                RD_IDLE: begin
                    if(wr_sel_sync == 1'b0 && wr_buf_full_sync) begin
                        rd_state <= RD_READ_PING;
                        rd_sel <= 1'b0;
                        rd_addr <= 0;
                        rd_valid <= 1'b1;
                    end
                end 

                RD_READ_PING: begin
                    if(rd_en) begin
                        rd_addr <= rd_addr + 1'b1;
                        if(rd_addr == BUFFER_DEPTH-1) begin
                            if(wr_sel_sync == 1'b1 && wr_buf_full_sync) begin
                                rd_state <= RD_READ_PONG;
                                rd_sel <= 1'b1;
                                rd_addr <= 0;
                                rd_done <= 1'b1;
                            end
                            else begin
                                rd_state <= RD_IDLE;
                                rd_valid <= 1'b0;
                                rd_done <= 1'b1;
                            end
                        end
                    end
                end

                RD_READ_PONG: begin
                    if(rd_en) begin
                        rd_addr <= rd_addr + 1'b1;
                        if(rd_addr == BUFFER_DEPTH-1) begin
                            if(wr_sel_sync == 1'b0 && wr_buf_full_sync) begin
                                rd_state <= RD_READ_PING;
                                rd_sel <= 1'b0;
                                rd_addr <= 0;
                                rd_done <= 1'b1;
                            end 
                            else begin
                                rd_state <= RD_IDLE;
                                rd_valid = 1'b0;
                                rd_done <= 1'b1;
                            end
                        end
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end


    // read output
    wire [7:0] ping_dout = ping_ram[rd_addr];
    wire [7:0] pong_dout = pong_ram[rd_addr];
    assign dout = rd_sel ? pong_dout : ping_dout;
    assign valid = rd_valid;



    // 跨时钟域
    // 处理方式：打两拍

    // wr_sel
    always @(posedge clk_out or negedge rst_n) begin
        if(!rst_n) begin
            wr_sel_sync_ff1 <= 1'b0;
            wr_sel_sync <= 1'b0;
        end
        else begin
            wr_sel_sync_ff1 <= wr_sel;
            wr_sel_sync <= wr_sel_sync_ff1;
        end
    end

    // wr_buf_full 
    always @(posedge clk_out or negedge rst_n) begin
        if(!rst_n) begin
            wr_buf_full_sync_ff1 <= 1'b0;
            wr_buf_full_sync_ff1 <= 1'b0;
        end
        else begin
            wr_buf_full_sync_ff1 <= wr_buf_full;
            wr_buf_full_sync_ff1 <= wr_buf_full_sync_ff1;
        end
    end

    // rd_done 同步到写时钟域
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            rd_done_sync_ff1 <= 1'b0;
            rd_done_sync <= 1'b0;
        end else begin
            rd_done_sync_ff1 <= rd_done;
            rd_done_sync <= rd_done_sync_ff1;
        end
    end


endmodule