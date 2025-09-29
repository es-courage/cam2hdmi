module lens_distortion_correction(
    input clk,
    input rst_n,
    
    // 输入接口：来自VGA时序生成器
    input [9:0] in_x,           // 显示像素X坐标 (0~1279)
    input [9:0] in_y,           // 显示像素Y坐标 (0~719)  
    input in_de,                // 显示数据使能
    input in_hs,                // 行同步信号
    input in_vs,                // 场同步信号
    
    // 输出接口：送给帧缓存读取控制
    output reg [15:0] out_src_x,    // 源图像坐标X (定点数16.8格式)
    output reg [15:0] out_src_y,    // 源图像坐标Y (定点数16.8格式)
    output reg out_de,              // 校正后数据使能
    output reg out_hs,              // 延迟对齐后行同步
    output reg out_vs,              // 延迟对齐后场同步
    output reg out_valid,           // 输出坐标有效标志
    
    // 配置接口：相机标定参数
    input [31:0] camera_fx,         // 相机内参fx
    input [31:0] camera_fy,         // 相机内参fy
    input [31:0] camera_cx,         // 相机内参cx
    input [31:0] camera_cy,         // 相机内参cy
    input [31:0] dist_k1,           // 畸变系数k1
    input [31:0] dist_k2,           // 畸变系数k2
    input [31:0] dist_p1,           // 畸变系数p1
    input [31:0] dist_p2            // 畸变系数p2
);

// 坐标映射LUT（预计算好的查找表）
reg [31:0] coord_map_lut [0:1280*720-1];
wire [19:0] lut_addr = in_y * 1280 + in_x;

// 流水线处理
reg [1:0] de_delay;
reg [1:0] hs_delay;
reg [1:0] vs_delay;

always@(posedge clk) begin
    if(!rst_n) begin
        de_delay <= 2'b00;
        hs_delay <= 2'b00;
        vs_delay <= 2'b00;
        out_valid <= 1'b0;
    end else begin
        // 2级流水线延迟，与坐标计算对齐
        de_delay <= {de_delay[0], in_de};
        hs_delay <= {hs_delay[0], in_hs};
        vs_delay <= {vs_delay[0], in_vs};
        
        // Stage 1: LUT查找
        if(in_de) begin
            {out_src_x, out_src_y} <= coord_map_lut[lut_addr];
        end
        
        // Stage 2: 输出对齐
        out_de <= de_delay[1];
        out_hs <= hs_delay[1];
        out_vs <= vs_delay[1];
        out_valid <= de_delay[1];
    end
end

// 初始化LUT（从Python标定结果生成）
initial begin
    $readmemh("undistortion_map.mem", coord_map_lut);
end

endmodule