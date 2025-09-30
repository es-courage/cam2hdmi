// ==================== DDR3帧缓存模块 ====================
// 存储一帧完整数据，为畸变校正提供像素查找
module ddr3_frame_buffer #(
    parameter H_RES = 1280,
    parameter V_RES = 720,
    parameter ADDR_BITS = 20  // 1280*720 = 921600 < 2^20
)(
    input clk,
    input rst_n,
    
    // 写入接口（从摄像头数据）
    input wr_clk,
    input wr_en,
    input [15:0] wr_data,
    input [19:0] wr_addr,  // 写地址 (y*1280+x)
    
    // 读取接口（给畸变校正）
    input rd_en,
    input [19:0] rd_addr,  // 读地址 (y*1280+x)
    output reg [15:0] rd_data,
    
    input frame_buffer_ready
);

    // 内部帧缓存RAM - 存储一帧完整数据
    // 使用Gowin的Block RAM或分布式RAM
    reg [15:0] frame_buffer [0:H_RES*V_RES-1];
    
    // 写入逻辑
    always @(posedge wr_clk) begin
        if (wr_en && frame_buffer_ready && wr_addr < H_RES*V_RES) begin
            frame_buffer[wr_addr] <= wr_data;
        end
    end
    
    // 读取逻辑
    always @(posedge clk) begin
        if (!rst_n) begin
            rd_data <= 16'h0000;
        end else if (rd_en && frame_buffer_ready && rd_addr < H_RES*V_RES) begin
            rd_data <= frame_buffer[rd_addr];
        end else begin
            rd_data <= 16'h0000;  // 边界外返回黑色
        end
    end

endmodule