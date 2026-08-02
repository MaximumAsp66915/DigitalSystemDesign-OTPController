`timescale 1ns/1ps
`default_nettype none
`include "otp_map.vh"
`include "settings.h"

module otp_sim_rom #(
    // --- FIX: file is now a parameter so a testbench can override it
    // (e.g. per-test-case images) without editing this file.
    parameter ROM_FILE = "otp_image.mem"
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] otp_addr,
    input  wire       otp_read_en,
    output reg        otp_data_out
);

    reg [255:0] otp_rom;

    // --- FIX: $readmemh cannot load a plain 256-bit vector directly (it
    // targets memory arrays). otp_image.mem holds the whole 256-bit image
    // as one hex line, so we load it into a single-word array and copy it
    // into otp_rom once at time 0. otp_rom then behaves like real OTP:
    // written once, read-only for the rest of the simulation.
    reg [255:0] otp_rom_ld [0:0];

    initial begin
        $readmemh(ROM_FILE, otp_rom_ld);
        otp_rom = otp_rom_ld[0];
    end

    // --- FIX: explicit reset branch (was previously an unconditional
    // "otp_data_out <= 0" every cycle with read as an afterthought override;
    // functionally similar, but this makes the reset behaviour explicit and
    // matches the controller's own reset-branch style).
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            otp_data_out <= 1'b0;
        else if (otp_read_en)
            otp_data_out <= otp_rom[otp_addr];
    end

endmodule
