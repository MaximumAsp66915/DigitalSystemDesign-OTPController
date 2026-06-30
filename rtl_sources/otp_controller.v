`default_nettype none
`include "otp_map.vh"
`include "settings.h"

module otp_controller (
    input  wire        clk,
    input  wire        rst_n,          // async reset, active-low

    input  wire        otp_data_out,
    output reg  [7:0]  otp_addr,
    output reg         otp_read_en,

    output reg         busy,           // high during load sequence
    output reg         done,           // single-cycle pulse at end

    // Output configuration fields
    output reg  [14:0] ro_trim_code,
    output reg  [15:0] tc1_coeff,
    output reg  [15:0] tc2_coeff,
    output reg  [15:0] aging_base,
    output reg  [1:0]  sku_code,
    output reg  [5:0]  temp_ro_trim,
    output reg  [5:0]  rev_id,
    output reg  [5:0]  cfg_flags,
    output reg  [19:0] ratio_p0,
    output reg  [19:0] ratio_p1,
    output reg  [19:0] ratio_p2,
    output reg  [19:0] ratio_p3,
    output reg  [19:0] ratio_p4,
    output reg         prog_disable_lock,
    output reg         oe_mode,
    output reg         oe_pol,

    output reg         crc_error
);

    // FSM State Definitions
    localparam [2:0]
        STATE_IDLE       = 3'd0,
        STATE_READ_BANK0 = 3'd1,
        STATE_READ_PATCH = 3'd2,
        STATE_APPLY      = 3'd3,
        STATE_DONE       = 3'd4;

    reg [2:0] state, next_state;

    // Datapath & Control Registers
    reg [7:0] addr;

    // Temporary field accumulation registers
    reg [14:0] tmp_ro_trim;
    reg [15:0] tmp_tc1;
    reg [15:0] tmp_tc2;
    reg [15:0] tmp_aging;
    reg [1:0]  tmp_sku;
    reg [5:0]  tmp_temp_trim;
    reg [5:0]  tmp_rev;
    reg [5:0]  tmp_cfg;
    reg [19:0] tmp_ratio_p0;
    reg [19:0] tmp_ratio_p1;
    reg [19:0] tmp_ratio_p2;
    reg [19:0] tmp_ratio_p3;
    reg [19:0] tmp_ratio_p4;
    reg [15:0] tmp_crc_stored;

    // Patch shift registers
    reg [1:0]  patch0_tag;
    reg [1:0]  patch1_tag;
    reg [19:0] patch0_data;
    reg [19:0] patch1_data;
    reg [4:0]  patch0_id;
    reg [4:0]  patch1_id;
    reg        patch0_valid_bit;
    reg        patch1_valid_bit;

    wire patch0_valid = patch0_valid_bit && (patch0_tag == `PATCH_TAG_VAL);
    wire patch1_valid = patch1_valid_bit && (patch1_tag == `PATCH_TAG_VAL);

    // CRC-16/CCITT Instance
    reg  [15:0] crc_reg;
    wire [15:0] crc_next_w;

    crc16_ccitt u_crc (
        .crc_in  (crc_reg),
        .data_in (otp_data_out),
        .crc_out (crc_next_w)
    );

    // Block 1: Sequential State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= STATE_READ_BANK0; // FSM automatically starts the read sequence
        else
            state <= next_state;
    end

    // Block 2: Combinational Next State Logic
    always @(*) begin
        case (state)
            STATE_IDLE:       next_state = STATE_IDLE;
            STATE_READ_BANK0: next_state = (addr == 8'd255)? STATE_READ_PATCH : STATE_READ_BANK0;
            STATE_READ_PATCH: next_state = (addr == `PATCH1_HI)? STATE_APPLY : STATE_READ_PATCH;
            STATE_APPLY:      next_state = STATE_DONE;
            STATE_DONE:       next_state = STATE_IDLE;
            default:          next_state = STATE_IDLE;
        endcase
    end

    // Block 3: Combinational Output/Control Logic
    always @(*) begin
        // Default assignments
        busy        = 1'b1;
        done        = 1'b0;
        otp_read_en = 1'b0;
        otp_addr    = addr;

        case (state)
            STATE_IDLE:       begin busy = 1'b0; end
            STATE_READ_BANK0: begin otp_read_en = 1'b1; end
            STATE_READ_PATCH: begin otp_read_en = 1'b1; end
            STATE_APPLY:      begin busy = 1'b1; end
            STATE_DONE:       begin busy = 1'b0; done = 1'b1; end
            default:          begin busy = 1'b0; end
        endcase
    end

    // Block 4: Sequential Data Path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset datapath and control flags
            addr           <= 8'd0;
            crc_error      <= 1'b0;
            crc_reg        <= 16'hFFFF;

            // Clear internal temporary registers
            tmp_ro_trim    <= 15'd0;
            tmp_tc1        <= 16'd0;
            tmp_tc2        <= 16'd0;
            tmp_aging      <= 16'd0;
            tmp_sku        <= 2'd0;
            tmp_temp_trim  <= 6'd0;
            tmp_rev        <= 6'd0;
            tmp_cfg        <= 6'd0;
            tmp_ratio_p0   <= 20'd0;
            tmp_ratio_p1   <= 20'd0;
            tmp_ratio_p2   <= 20'd0;
            tmp_ratio_p3   <= 20'd0;
            tmp_ratio_p4   <= 20'd0;
            tmp_crc_stored <= 16'd0;

            patch0_tag       <= 2'd0;
            patch0_data      <= 20'd0;
            patch0_id        <= 5'd0;
            patch0_valid_bit <= 1'b0;

            patch1_tag       <= 2'd0;
            patch1_data      <= 20'd0;
            patch1_id        <= 5'd0;
            patch1_valid_bit <= 1'b0;

            // Clear output registers
            ro_trim_code      <= 15'd0;
            tc1_coeff         <= 16'd0;
            tc2_coeff         <= 16'd0;
            aging_base        <= 16'd0;
            sku_code          <= 2'd0;
            temp_ro_trim      <= 6'd0;
            rev_id            <= 6'd0;
            cfg_flags         <= 6'd0;
            ratio_p0          <= 20'd0;
            ratio_p1          <= 20'd0;
            ratio_p2          <= 20'd0;
            ratio_p3          <= 20'd0;
            ratio_p4          <= 20'd0;
            prog_disable_lock <= 1'b0;
            oe_mode           <= 1'b0;
            oe_pol            <= 1'b0;

        end else begin

            // Address Counter Control
            if (state == STATE_IDLE) begin
                addr <= 8'd0;
            end
            else if (state == STATE_READ_BANK0) begin
                if (addr == 8'd255)
                    addr <= `PATCH0_LO; // Jump to 196
                else
                    addr <= addr + 1'b1;
            end
            else if (state == STATE_READ_PATCH) begin
                if (addr < `PATCH1_HI) // Max patch address 251
                    addr <= addr + 1'b1;
            end

            // Data Accumulation
            if (otp_read_en) begin
                // Bank 0 Field Accumulation
                if (addr >= `OTP_RO_TRIM_LO && addr <= `OTP_RO_TRIM_HI)
                    tmp_ro_trim[addr - `OTP_RO_TRIM_LO] <= otp_data_out;

                if (addr >= `OTP_TC1_LO && addr <= `OTP_TC1_HI)
                    tmp_tc1[addr - `OTP_TC1_LO] <= otp_data_out;

                if (addr >= `OTP_TC2_LO && addr <= `OTP_TC2_HI)
                    tmp_tc2[addr - `OTP_TC2_LO] <= otp_data_out;

                if (addr >= `OTP_AGING_LO && addr <= `OTP_AGING_HI)
                    tmp_aging[addr - `OTP_AGING_LO] <= otp_data_out;

                if (addr >= `OTP_SKU_LO && addr <= `OTP_SKU_HI)
                    tmp_sku[addr - `OTP_SKU_LO] <= otp_data_out;

                if (addr >= `OTP_TEMP_TRIM_LO && addr <= `OTP_TEMP_TRIM_HI)
                    tmp_temp_trim[addr - `OTP_TEMP_TRIM_LO] <= otp_data_out;

                if (addr >= `OTP_REV_LO && addr <= `OTP_REV_HI)
                    tmp_rev[addr - `OTP_REV_LO] <= otp_data_out;

                if (addr >= `OTP_CFG_LO && addr <= `OTP_CFG_HI)
                    tmp_cfg[addr - `OTP_CFG_LO] <= otp_data_out;

                if (addr >= `OTP_RP0_LO && addr <= `OTP_RP0_HI)
                    tmp_ratio_p0[addr - `OTP_RP0_LO] <= otp_data_out;

                if (addr >= `OTP_RP1_LO && addr <= `OTP_RP1_HI)
                    tmp_ratio_p1[addr - `OTP_RP1_LO] <= otp_data_out;

                if (addr >= `OTP_RP2_LO && addr <= `OTP_RP2_HI)
                    tmp_ratio_p2[addr - `OTP_RP2_LO] <= otp_data_out;

                if (addr >= `OTP_RP3_LO && addr <= `OTP_RP3_HI)
                    tmp_ratio_p3[addr - `OTP_RP3_LO] <= otp_data_out;

                if (addr >= `OTP_RP4_LO && addr <= `OTP_RP4_HI)
                    tmp_ratio_p4[addr - `OTP_RP4_LO] <= otp_data_out;

                if (addr >= `OTP_CRC_LO && addr <= `OTP_CRC_HI)
                    tmp_crc_stored[addr - `OTP_CRC_LO] <= otp_data_out;

                // CRC-16 Calculation: Accumulate over bits 0 to 182
                if (addr <= `OTP_CRC_DATA_HI)
                    crc_reg <= crc_next_w;

                // Patch 0 Accumulation
                if (addr >= `PATCH0_LO && addr <= `PATCH0_HI) begin
                    if ((addr - `PATCH0_LO) <= `PATCH_TAG_HI)
                        patch0_tag[addr - `PATCH0_LO] <= otp_data_out;
                    else if ((addr - `PATCH0_LO) <= `PATCH_DATA_HI)
                        patch0_data[(addr - `PATCH0_LO) - `PATCH_DATA_LO] <= otp_data_out;
                    else if ((addr - `PATCH0_LO) <= `PATCH_ID_HI)
                        patch0_id[(addr - `PATCH0_LO) - `PATCH_ID_LO] <= otp_data_out;
                    else if ((addr - `PATCH0_LO) == `PATCH_VALID_BIT)
                        patch0_valid_bit <= otp_data_out;
                end

                // Patch 1 Accumulation
                if (addr >= `PATCH1_LO && addr <= `PATCH1_HI) begin
                    if ((addr - `PATCH1_LO) <= `PATCH_TAG_HI)
                        patch1_tag[addr - `PATCH1_LO] <= otp_data_out;
                    else if ((addr - `PATCH1_LO) <= `PATCH_DATA_HI)
                        patch1_data[(addr - `PATCH1_LO) - `PATCH_DATA_LO] <= otp_data_out;
                    else if ((addr - `PATCH1_LO) <= `PATCH_ID_HI)
                        patch1_id[(addr - `PATCH1_LO) - `PATCH_ID_LO] <= otp_data_out;
                    else if ((addr - `PATCH1_LO) == `PATCH_VALID_BIT)
                        patch1_valid_bit <= otp_data_out;
                end
            end

            // Apply Patches and Map Outputs
            if (state == STATE_APPLY) begin
                if (crc_reg != tmp_crc_stored)
                    crc_error <= 1'b1;

                // Map temporary baseline registers to outputs
                ro_trim_code      <= tmp_ro_trim;
                tc1_coeff         <= tmp_tc1;
                tc2_coeff         <= tmp_tc2;
                aging_base        <= tmp_aging;
                sku_code          <= tmp_sku;
                temp_ro_trim      <= tmp_temp_trim;
                rev_id            <= tmp_rev;
                cfg_flags         <= tmp_cfg;
                oe_mode           <= tmp_cfg[`CFG_OE_MODE_BIT];
                oe_pol            <= tmp_cfg[`CFG_OE_POL_BIT];
                prog_disable_lock <= tmp_cfg[`CFG_PDL_BIT];
                ratio_p0          <= tmp_ratio_p0;
                ratio_p1          <= tmp_ratio_p1;
                ratio_p2          <= tmp_ratio_p2;
                ratio_p3          <= tmp_ratio_p3;
                ratio_p4          <= tmp_ratio_p4;

                // Process Patch 0
                if (patch0_valid) begin
                    case (patch0_id)
                        `PID_RO_TRIM:    ro_trim_code <= patch0_data[14:0];
                        `PID_TC1:        tc1_coeff    <= patch0_data[15:0];
                        `PID_TC2:        tc2_coeff    <= patch0_data[15:0];
                        `PID_AGING_BASE: aging_base   <= patch0_data[15:0];
                        `PID_TEMP_TRIM:  temp_ro_trim <= patch0_data[5:0];
                        `PID_CFG_FLAGS: begin
                            cfg_flags         <= patch0_data[5:0];
                            oe_mode           <= patch0_data[`CFG_OE_MODE_BIT];
                            oe_pol            <= patch0_data[`CFG_OE_POL_BIT];
                            prog_disable_lock <= patch0_data[`CFG_PDL_BIT];
                        end
                        `PID_RATIO_P0:   ratio_p0     <= patch0_data[19:0];
                        `PID_RATIO_P1:   ratio_p1     <= patch0_data[19:0];
                        `PID_RATIO_P2:   ratio_p2     <= patch0_data[19:0];
                        `PID_RATIO_P3:   ratio_p3     <= patch0_data[19:0];
                        `PID_RATIO_P4:   ratio_p4     <= patch0_data[19:0];
                        default: ;
                    endcase
                end

                // Process Patch 1 (Conditionally overrides Patch 0 logic)
                if (patch1_valid) begin
                    case (patch1_id)
                        `PID_RO_TRIM:    ro_trim_code <= patch1_data[14:0];
                        `PID_TC1:        tc1_coeff    <= patch1_data[15:0];
                        `PID_TC2:        tc2_coeff    <= patch1_data[15:0];
                        `PID_AGING_BASE: aging_base   <= patch1_data[15:0];
                        `PID_TEMP_TRIM:  temp_ro_trim <= patch1_data[5:0];
                        `PID_CFG_FLAGS: begin
                            cfg_flags         <= patch1_data[5:0];
                            oe_mode           <= patch1_data[`CFG_OE_MODE_BIT];
                            oe_pol            <= patch1_data[`CFG_OE_POL_BIT];
                            prog_disable_lock <= patch1_data[`CFG_PDL_BIT];
                        end
                        `PID_RATIO_P0:   ratio_p0     <= patch1_data[19:0];
                        `PID_RATIO_P1:   ratio_p1     <= patch1_data[19:0];
                        `PID_RATIO_P2:   ratio_p2     <= patch1_data[19:0];
                        `PID_RATIO_P3:   ratio_p3     <= patch1_data[19:0];
                        `PID_RATIO_P4:   ratio_p4     <= patch1_data[19:0];
                        default: ;
                    endcase
                end
            end

        end
    end

endmodule