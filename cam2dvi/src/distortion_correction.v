// ==================== 完整的畸变校正模块 ====================
module distortion_correction #(
    parameter DATA_WIDTH = 16,
    parameter H_RES = 1280,
    parameter V_RES = 720
)(
    input clk,
    input rst_n,
    
    // 完整相机参数
    input [15:0] fx, fy,      // 焦距参数
    input [15:0] cx, cy,      // 图像中心点
    input [15:0] k1, k2, k3,  // 畸变系数
    input valid_params,
    
    // 视频输入流
    input [DATA_WIDTH-1:0] vin_data,
    input vin_de, vin_vs, vin_hs,
    input [9:0] pixel_x, pixel_y,
    
    // 视频输出流
    output reg [DATA_WIDTH-1:0] vout_data,
    output reg vout_de, vout_vs, vout_hs,
    
    // 帧缓存接口
    input [15:0] ram_rd_data,
    output reg [19:0] ram_rd_addr,
    output reg ram_rd_en
);

    // 状态机定义
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam WAIT = 2'b10;
    localparam OUT  = 2'b11;
    
    reg [1:0] state, next_state;
    
    // 计算寄存器
    reg signed [15:0] x_norm, y_norm;      // 归一化坐标
    reg signed [31:0] x2, y2, r2;          // 平方项
    reg signed [31:0] r4, r6;              // 高次项
    reg signed [31:0] distortion_factor;   // 畸变因子
    reg signed [15:0] x_distorted, y_distorted;  // 畸变后坐标
    reg [9:0] corrected_x, corrected_y;    // 最终校正坐标
    
    // 延迟寄存器
    reg [9:0] px_d1, py_d1, px_d2, py_d2;
    reg de_d1, vs_d1, hs_d1;
    reg de_d2, vs_d2, hs_d2;
    reg de_d3, vs_d3, hs_d3;
    
    // 计数器
    reg [2:0] calc_cnt;
    
    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: next_state = (vin_de && valid_params) ? CALC : IDLE;
            CALC: next_state = (calc_cnt == 3'd4) ? WAIT : CALC;
            WAIT: next_state = OUT;
            OUT:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // 畸变校正计算流水线
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc_cnt <= 0;
            x_norm <= 0; y_norm <= 0;
            x2 <= 0; y2 <= 0; r2 <= 0;
            r4 <= 0; r6 <= 0;
            distortion_factor <= 0;
            x_distorted <= 0; y_distorted <= 0;
            corrected_x <= 0; corrected_y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    calc_cnt <= 0;
                    if (vin_de && valid_params) begin
                        // 归一化坐标 (相对于光学中心)
                        x_norm <= (pixel_x - cx);
                        y_norm <= (pixel_y - cy);
                    end
                end
                
                CALC: begin
                    calc_cnt <= calc_cnt + 1;
                    case (calc_cnt)
                        3'd0: begin
                            // 计算平方项
                            x2 <= x_norm * x_norm;
                            y2 <= y_norm * y_norm;
                        end
                        3'd1: begin
                            // 计算径向距离平方
                            r2 <= x2 + y2;
                        end
                        3'd2: begin
                            // 计算高次项
                            r4 <= (r2 * r2) >> 16;  // 防止溢出
                            r6 <= (r2 * r2 * r2) >> 24;
                        end
                        3'd3: begin
                            // 计算畸变因子: (1 + k1*r^2 + k2*r^4 + k3*r^6)
                            distortion_factor <= 32'h10000 + 
                                               ((k1 * r2) >> 8) + 
                                               ((k2 * r4) >> 8) + 
                                               ((k3 * r6) >> 8);
                        end
                        3'd4: begin
                            // 应用畸变校正
                            x_distorted <= (x_norm * distortion_factor) >> 16;
                            y_distorted <= (y_norm * distortion_factor) >> 16;
                        end
                    endcase
                end
                
                WAIT: begin
                    // 转换回像素坐标
                    corrected_x <= cx + x_distorted;
                    corrected_y <= cy + y_distorted;
                end
                
                default: begin
                    calc_cnt <= 0;
                end
            endcase
        end
    end
    
    // 边界检查
    wire in_bounds = (corrected_x < H_RES) && (corrected_y < V_RES) && 
                    (corrected_x >= 0) && (corrected_y >= 0);
    
    // 数据流水线和输出控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_d1 <= 0; py_d1 <= 0; px_d2 <= 0; py_d2 <= 0;
            de_d1 <= 0; vs_d1 <= 0; hs_d1 <= 0;
            de_d2 <= 0; vs_d2 <= 0; hs_d2 <= 0;
            de_d3 <= 0; vs_d3 <= 0; hs_d3 <= 0;
            ram_rd_addr <= 0;
            ram_rd_en <= 0;
            vout_data <= 0;
            vout_de <= 0; vout_vs <= 0; vout_hs <= 0;
        end else begin
            // 延迟链：匹配计算时间
            px_d1 <= pixel_x; py_d1 <= pixel_y;
            px_d2 <= px_d1;   py_d2 <= py_d1;
            
            de_d1 <= vin_de; vs_d1 <= vin_vs; hs_d1 <= vin_hs;
            de_d2 <= de_d1;  vs_d2 <= vs_d1;  hs_d2 <= hs_d1;
            de_d3 <= de_d2;  vs_d3 <= vs_d2;  hs_d3 <= hs_d2;
            
            // RAM访问控制
            if (state == OUT) begin
                if (valid_params && de_d3 && in_bounds) begin
                    ram_rd_addr <= corrected_y * H_RES + corrected_x;
                    ram_rd_en <= 1'b1;
                end else begin
                    // 无畸变校正时直接映射
                    ram_rd_addr <= py_d2 * H_RES + px_d2;
                    ram_rd_en <= de_d3;
                end
            end else begin
                ram_rd_en <= 1'b0;
            end
            
            // 输出数据
            vout_data <= ram_rd_data;
            vout_de <= de_d3;
            vout_vs <= vs_d3;
            vout_hs <= hs_d3;
        end
    end

endmodule