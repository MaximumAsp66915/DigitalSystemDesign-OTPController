`timescale 1ns/1ps
`include "otp_map.vh"

module tb_otp_controller;
    // Clock: 131.072 kHz  ->  period ≈ 7629 ns
    localparam real CLK_PERIOD_NS = 7629.0;

    // Reset hold length (cycles)
    localparam integer RESET_CYCLES = 8;

    reg clk;
    reg rst_n;

    // OTP array interface (connects DUT ROM model)
    wire        otp_data_out;       // ROM → DUT
    wire  [7:0] otp_addr;           // DUT → ROM
    wire        otp_read_en;        // DUT → ROM

    // Status
    wire        busy;
    wire        done;

    // Output registers
    wire [14:0] ro_trim_code;
    wire [15:0] tc1_coeff;
    wire [15:0] tc2_coeff;
    wire [15:0] aging_base;
    wire  [1:0] sku_code;
    wire  [5:0] temp_ro_trim;
    wire  [5:0] rev_id;
    wire  [5:0] cfg_flags;
    wire [19:0] ratio_p0;
    wire [19:0] ratio_p1;
    wire [19:0] ratio_p2;
    wire [19:0] ratio_p3;
    wire [19:0] ratio_p4;
    wire        prog_disable_lock;
    wire        oe_mode;
    wire        oe_pol;
    wire        crc_error;

    // Full 256-bit OTP image loaded
    reg [255:0] otp_mem;

    // Expected output values
    reg [14:0] exp_ro_trim_code;
    reg [15:0] exp_tc1_coeff;
    reg [15:0] exp_tc2_coeff;
    reg [15:0] exp_aging_base;
    reg  [1:0] exp_sku_code;
    reg  [5:0] exp_temp_ro_trim;
    reg  [5:0] exp_rev_id;
    reg  [5:0] exp_cfg_flags;
    reg [19:0] exp_ratio_p0;
    reg [19:0] exp_ratio_p1;
    reg [19:0] exp_ratio_p2;
    reg [19:0] exp_ratio_p3;
    reg [19:0] exp_ratio_p4;
    reg        exp_prog_disable_lock;
    reg        exp_oe_mode;
    reg        exp_oe_pol;
    reg        exp_crc_error;

    // Instantiate DUT
    otp_controller u_dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .otp_data_out     (otp_data_out),
        .otp_addr         (otp_addr),
        .otp_read_en      (otp_read_en),
        .busy             (busy),
        .done             (done),
        .ro_trim_code     (ro_trim_code),
        .tc1_coeff        (tc1_coeff),
        .tc2_coeff        (tc2_coeff),
        .aging_base       (aging_base),
        .sku_code         (sku_code),
        .temp_ro_trim     (temp_ro_trim),
        .rev_id           (rev_id),
        .cfg_flags        (cfg_flags),
        .ratio_p0         (ratio_p0),
        .ratio_p1         (ratio_p1),
        .ratio_p2         (ratio_p2),
        .ratio_p3         (ratio_p3),
        .ratio_p4         (ratio_p4),
        .prog_disable_lock(prog_disable_lock),
        .oe_mode          (oe_mode),
        .oe_pol           (oe_pol),
        .crc_error        (crc_error)
    );

    otp_sim_rom u_rom (
        .clk          (clk),
        .rst_n        (rst_n),
        .otp_addr     (otp_addr),
        .otp_read_en  (otp_read_en),
        .otp_data_out (otp_data_out)
    );

    // Generate clock
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    // Load otp_mem from file
    initial begin
        $readmemb("otp_image.mem", u_rom.otp_rom);
    end

    // Drive otp_data_out via a small ROM model

    // Monitor outputs
    // initial begin
    //     $dumpfile("tb_otp_controller.vcd");
    //     $dumpvars(0, tb_otp_controller);
    // end

    // Compare with expected

    // Report pass/fail

endmodule
