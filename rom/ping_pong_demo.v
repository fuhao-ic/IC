module ping_pong_demo(
    input wire clk,
    input wire rst_n,
    input wire wr_en,
    input wire [7:0] din,
    output wire rd_en,
    output wire dout
);
    /*
        该代码场景：
            高速ADC数据持续流入，后端处理模块速度较慢；
        
        当前的demo代码存在很多实际问题，需要fix：
            1、开始阶段pong buffer中的数据是无效的；
            2、当解决问题1后，rd_en是否可以拉高到将全部的data传输；
    */


    // 这个模块用于了解ping-pong原理
    /*
        一种经典的数据流控制技术;
        实现数据的无缝缓存与处理，是用硬件资源（面积）换取系统处理速度的典型设计思想;
        基本原理：
            初始状态：第一个数据周期，输入数据选择单元将数据流写入 Ping缓冲区。
            第一次切换：第二个数据周期，输入数据流切换到写入 Pong缓冲区。与此同时，之前存满数据的Ping缓冲区则切换为读出状态，将第一个周期的数据送往后续处理模块。
            循环往复：第三个数据周期，输入数据流再次切回Ping缓冲区进行写入，同时Pong缓冲区切换为读出，将第二个周期的数据送走。
    */


    localparam BUFFER_DEPTH = 4;
    localparam  ADDR_WIDTH = 2;

    reg [7:0] ping_ram [0:BUFFER_DEPTH-1];
    reg [7:0] pong_ram [0:BUFFER_DEPTH-1];

    reg [ADDR_WIDTH-1:0] wr_addr;
    reg [ADDR_WIDTH-1:0] rd_addr;
    reg wr_sel;   // 写选择: 0->Ping, 1->Pong
    reg rd_sel;  // 读选择: 0->Ping, 1->Pong


    reg [1:0] state;
    reg [1:0] next_state;

    reg [ADDR_WIDTH-1:0] wr_cnt;
    reg [ADDR_WIDTH-1:0] rd_cnt;

    // fsm
    localparam S_PING_WRITE = 2'b00;   // 写Ping，读Pong
    localparam S_PONG_WRITE = 2'b01;   // 写Pong，读Ping

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= S_PING_WRITE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            S_PING_WRITE: begin
                if(wr_cnt == BUFFER_DEPTH-1 && wr_en) begin  // 写满最后一笔数据时切换
                    next_state = S_PONG_WRITE;
                end
                else begin
                    next_state = S_PING_WRITE;
                end
            end 
            S_PONG_WRITE: begin
                if(wr_cnt == BUFFER_DEPTH-1 && wr_en) begin
                    next_state = S_PING_WRITE;
                end
                else begin
                    next_state = S_PONG_WRITE;
                end
            end
            default: next_state = S_PING_WRITE;
        endcase
    end


    // 写地址和写选择控制
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_cnt <= 0;
            wr_sel <= 1'b0;  // default: write-ping
        end
        else if(wr_en) begin
            // 地址递增
            if(wr_cnt == BUFFER_DEPTH-1) begin
                wr_cnt <= 0;
            end
            else begin
                wr_cnt <= wr_cnt + 1'b1;
            end

            case (state)
                S_PING_WRITE: wr_sel <= 1'b0;
                S_PONG_WRITE: wr_sel <= 1'b1; 
                default: wr_sel <= 1'b0;
            endcase
        end
        else begin
            wr_cnt <= wr_cnt;
            wr_sel <= wr_sel;
        end
    end


    // 读地址和读选择控制
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_cnt <= 0;
            rd_sel <= 1'b1;
        end
        else begin
            case (state)   //读选择：与写选择相反
                S_PING_WRITE: rd_sel <= 1'b1; 
                S_PONG_WRITE: rd_sel <= 1'b0;
                default:  rd_sel <= 1'b0;
            endcase

            if(rd_en) begin
                if(rd_cnt == BUFFER_DEPTH-1) begin
                    rd_cnt <= 0;
                end
                else begin
                    rd_cnt <= rd_cnt + 1'b1;
                end
            end
        end
    end


    // 写入逻辑
    always @(posedge clk) begin
        if(wr_en) begin
            case (wr_sel)
                1'b0: ping_ram[wr_cnt] <= din;
                1'b1: pong_ram[wr_cnt] <= din; 
                default: 
            endcase
        end
    end


    // 读出逻辑
    wire [7:0] ping_dout;
    wire [7:0] pong_dout;
    assign ping_dout = ping_ram[rd_cnt];
    assign pong_dout = pong_ram[rd_cnt];
    assign dout = (rd_sel == 1'b0) ? ping_dout : pong_dout;

    reg rd_en_r;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_en_r <= 1'b0;
        end
        else begin
            rd_en_r <= wr_en;
        end
    end

    assign rd_en = rd_en_r;

endmodule