// ==================== 相机参数存储模块 ====================
module camera_parameters(
    input clk,
    input rst_n,
    input [2:0] param_addr,
    input [31:0] param_data,
    input wr_en,
    output reg [31:0] param0,
    output reg [31:0] param1,
    output reg [31:0] param2,
    output reg [31:0] param3,
    output reg [31:0] param4,
    output reg [31:0] param5,
    output reg [31:0] param6,
    output reg [31:0] param7
);

    reg [31:0] parameters[0:7];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parameters[0] <= 32'h00000578;
            parameters[1] <= 32'h00000578;
            parameters[2] <= 32'h00000280;
            parameters[3] <= 32'h000001C2;
            parameters[4] <= 32'hFFFFFC18;
            parameters[5] <= 32'h00000064;
            parameters[6] <= 32'h00000000;
            parameters[7] <= 32'h00000000;
            
            param0 <= 32'h00000578;
            param1 <= 32'h00000578;
            param2 <= 32'h00000280;
            param3 <= 32'h000001C2;
            param4 <= 32'hFFFFFC18;
            param5 <= 32'h00000064;
            param6 <= 32'h00000000;
            param7 <= 32'h00000000;
        end else if (wr_en) begin
            parameters[param_addr] <= param_data;
            
            // 更新所有输出
            param0 <= parameters[0];
            param1 <= parameters[1];
            param2 <= parameters[2];
            param3 <= parameters[3];
            param4 <= parameters[4];
            param5 <= parameters[5];
            param6 <= parameters[6];
            param7 <= parameters[7];
        end
    end

endmodule